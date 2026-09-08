import http from "node:http";
import { randomUUID } from "node:crypto";
import PDFDocument from "pdfkit";
import pg from "pg";

const { Pool } = pg;
const PORT = Number(process.env.PORT || 3000);
const DATABASE_URL = process.env.DATABASE_URL || "postgres://postgres:postgres@localhost:5432/attendance_payroll";

const pool = new Pool({ connectionString: DATABASE_URL });

const ROLE = Object.freeze({ EMPLOYEE: "employee", ADMIN: "admin" });
const ATTENDANCE = Object.freeze({ RUNNING: "running", COMPLETED: "completed", CORRECTED: "corrected", REJECTED: "rejected" });
const OVERTIME = Object.freeze({ RUNNING: "running", COMPLETED: "completed", APPROVED: "approved", CORRECTED: "corrected", REJECTED: "rejected" });
const PAYROLL = Object.freeze({ DRAFT: "draft", REVIEWED: "reviewed", PUBLISHED: "published", PAID: "paid" });

const jakartaDateFormatter = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Jakarta", year: "numeric", month: "2-digit", day: "2-digit" });
const jakartaTimeFormatter = new Intl.DateTimeFormat("en-GB", { timeZone: "Asia/Jakarta", hour: "2-digit", minute: "2-digit", hour12: false });
const today = () => jakartaDateFormatter.format(new Date());
const nowIso = () => new Date().toISOString();
const moneyRound = (value) => Math.round(Number(value || 0));
const isPositiveNumber = (value) => Number.isFinite(Number(value)) && Number(value) > 0;
const minutesBetween = (start, end) => Math.max(0, Math.round((new Date(end) - new Date(start)) / 60000));
const publicUser = (user) => ({ id: user.id, name: user.name, username: user.username, role: user.role, employee_id: user.employee_id ?? null });

function send(res, status, body = {}) {
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Allow-Methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS"
  });
  res.end(JSON.stringify(body));
}

function sendPdf(res, buffer, fileName) {
  res.writeHead(200, {
    "Content-Type": "application/pdf",
    "Content-Length": buffer.length,
    "Content-Disposition": `inline; filename="${fileName}"`,
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Allow-Methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS"
  });
  res.end(buffer);
}

function error(res, status, message, details = undefined) {
  send(res, status, { error: { message, details } });
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (chunks.length === 0) return {};
  const text = Buffer.concat(chunks).toString("utf8");
  if (!text.trim()) return {};
  try {
    return JSON.parse(text);
  } catch {
    const err = new Error("Body harus JSON valid.");
    err.status = 400;
    throw err;
  }
}

async function q(text, params = [], client = pool) {
  return client.query(text, params);
}

async function one(text, params = [], client = pool) {
  const result = await q(text, params, client);
  return result.rows[0] || null;
}

async function many(text, params = [], client = pool) {
  const result = await q(text, params, client);
  return result.rows;
}

async function tx(callback) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await callback(client);
    await client.query("COMMIT");
    return result;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

async function getUser(req) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) return null;
  return one(
    `SELECT u.id, u.name, u.username, u.role, u.employee_id, u.status
     FROM sessions s
     JOIN app_users u ON u.id = s.user_id
     WHERE s.token = $1 AND u.status = 'active'`,
    [token]
  );
}

async function requireAuth(req, res) {
  const user = await getUser(req);
  if (!user) {
    error(res, 401, "Login diperlukan.");
    return null;
  }
  return user;
}

async function requireAdmin(req, res) {
  const user = await requireAuth(req, res);
  if (!user) return null;
  if (user.role !== ROLE.ADMIN) {
    error(res, 403, "Akses hanya untuk Admin/Owner.");
    return null;
  }
  return user;
}

function canAccessEmployee(user, employeeId) {
  return user.role === ROLE.ADMIN || user.employee_id === employeeId;
}

async function audit(user, module, recordId, action, oldValue = null, newValue = null, client = pool) {
  await q(
    `INSERT INTO audit_logs (id, user_id, module, record_id, action, old_value, new_value, timestamp)
     VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
    [randomUUID(), user?.id || null, module, recordId, action, oldValue ? JSON.stringify(oldValue) : null, newValue ? JSON.stringify(newValue) : null],
    client
  );
}

function attendanceDto(row, includePrivate = false) {
  if (!row) return null;
  const result = { ...row, duration_minutes: row.duration_minutes == null ? 0 : Number(row.duration_minutes) };
  if (!includePrivate) {
    delete result.check_in_photo;
    delete result.check_in_latitude;
    delete result.check_in_longitude;
  }
  return result;
}

function payrollDto(row, user) {
  if (!row) return null;
  const result = {
    ...row,
    working_days: Number(row.working_days),
    daily_rate_snapshot: Number(row.daily_rate_snapshot),
    overtime_rate_snapshot: Number(row.overtime_rate_snapshot),
    overtime_minutes: Number(row.overtime_minutes),
    normal_salary: Number(row.normal_salary),
    overtime_amount: Number(row.overtime_amount),
    cashbon_balance: Number(row.cashbon_balance),
    cashbon_deduction: Number(row.cashbon_deduction),
    net_salary: Number(row.net_salary)
  };
  if (user.role !== ROLE.ADMIN) {
    delete result.daily_rate_snapshot;
    delete result.overtime_rate_snapshot;
  }
  return result;
}

function dateText(value) {
  if (!value) return "-";
  if (typeof value === "string") return value.slice(0, 10);
  return jakartaDateFormatter.format(new Date(value));
}

function timeText(value) {
  if (!value) return "-";
  return jakartaTimeFormatter.format(new Date(value));
}

function durationText(minutes) {
  const value = Number(minutes || 0);
  if (value <= 0) return "-";
  return `${Math.floor(value / 60)}j ${String(value % 60).padStart(2, "0")}m`;
}

function rupiahText(value) {
  return `Rp${String(Math.round(Number(value || 0))).replace(/\B(?=(\d{3})+(?!\d))/g, ".")}`;
}

function buildPayrollDocument(payroll, workDays, user) {
  const safePayroll = payrollDto(payroll, user);
  const lines = [
    "DOKUMEN RINCIAN WAKTU KERJA",
    `Karyawan: ${payroll.employee_name}`,
    `Periode: ${dateText(payroll.period_start)} sampai ${dateText(payroll.period_end)}`,
    `Jumlah hari kerja: ${workDays.length} hari`,
    `Total gaji normal: ${rupiahText(payroll.normal_salary)}`,
    `Total lembur: ${rupiahText(payroll.overtime_amount)} (${durationText(payroll.overtime_minutes)})`,
    `Total diterima: ${rupiahText(payroll.net_salary)}`,
    "",
    "Rincian harian:",
    "No | Tanggal | Proyek | Masuk | Pulang | Jam kerja | Lembur"
  ];
  workDays.forEach((item, index) => {
    const overtime = Number(item.overtime_minutes || 0) > 0 ? `${durationText(item.overtime_minutes)} / ${rupiahText(item.overtime_amount)}` : "-";
    lines.push(`${index + 1} | ${dateText(item.date)} | ${item.project_name} | ${timeText(item.check_in_time)} | ${timeText(item.check_out_time)} | ${durationText(item.work_minutes)} | ${overtime}`);
  });
  return {
    id: `doc-${payroll.id}`,
    type: "payroll_work_detail",
    generated_at: nowIso(),
    payroll: safePayroll,
    work_days: workDays.map((item) => ({
      ...item,
      date: dateText(item.date),
      work_minutes: Number(item.work_minutes || 0),
      overtime_minutes: Number(item.overtime_minutes || 0),
      overtime_amount: Number(item.overtime_amount || 0)
    })),
    text: lines.join("\n")
  };
}

function payrollDocumentFileName(payroll) {
  const name = String(payroll.employee_name || "karyawan").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
  return `rincian-waktu-kerja-${name || "karyawan"}-${dateText(payroll.period_start)}-${dateText(payroll.period_end)}.pdf`;
}

function pdfBuffer(doc) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    doc.on("data", (chunk) => chunks.push(chunk));
    doc.on("end", () => resolve(Buffer.concat(chunks)));
    doc.on("error", reject);
    doc.end();
  });
}

async function buildPayrollPdf(payroll, workDays) {
  const doc = new PDFDocument({ size: "A4", margin: 42, info: { Title: "Rincian Waktu Kerja", Author: "Geo Absen" } });
  const width = doc.page.width - doc.page.margins.left - doc.page.margins.right;
  const left = doc.page.margins.left;
  const right = doc.page.width - doc.page.margins.right;

  doc.rect(0, 0, doc.page.width, 104).fill("#2F39A9");
  doc.fillColor("#FFFFFF").font("Helvetica-Bold").fontSize(20).text("Rincian Waktu Kerja", left, 34);
  doc.font("Helvetica").fontSize(10).text("Dokumen payroll berdasarkan data absensi aktual", left, 61);
  doc.font("Helvetica-Bold").fontSize(12).text(payroll.employee_name, left, 78);
  doc.font("Helvetica").fontSize(9).text(`Generated ${timeText(nowIso())}`, right - 120, 36, { width: 120, align: "right" });

  let y = 130;
  doc.fillColor("#101828").font("Helvetica-Bold").fontSize(11).text("Periode", left, y);
  doc.font("Helvetica").text(`${dateText(payroll.period_start)} sampai ${dateText(payroll.period_end)}`, left + 86, y);
  y += 22;
  const summary = [
    ["Hari kerja", `${workDays.length} hari`],
    ["Total kerja", durationText(workDays.reduce((sum, item) => sum + Number(item.work_minutes || 0), 0))],
    ["Lembur", `${durationText(payroll.overtime_minutes)} / ${rupiahText(payroll.overtime_amount)}`],
    ["Total diterima", rupiahText(payroll.net_salary)]
  ];
  const boxGap = 10;
  const boxWidth = (width - boxGap * 3) / 4;
  summary.forEach(([label, value], index) => {
    const x = left + index * (boxWidth + boxGap);
    doc.roundedRect(x, y, boxWidth, 58, 12).fillAndStroke(index === 3 ? "#E9FBF7" : "#EFF6FB", index === 3 ? "#15D8B3" : "#D9DEE7");
    doc.fillColor("#667085").font("Helvetica-Bold").fontSize(8).text(label.toUpperCase(), x + 10, y + 11, { width: boxWidth - 20 });
    doc.fillColor(index === 3 ? "#0E987F" : "#2F39A9").font("Helvetica-Bold").fontSize(index === 3 ? 12 : 11).text(value, x + 10, y + 30, { width: boxWidth - 20 });
  });
  y += 86;

  doc.fillColor("#101828").font("Helvetica-Bold").fontSize(13).text("Detail Absensi", left, y);
  y += 22;
  const columns = [
    { label: "Tanggal", x: left, width: 66 },
    { label: "Proyek", x: left + 70, width: 140 },
    { label: "Masuk", x: left + 214, width: 42 },
    { label: "Pulang", x: left + 260, width: 42 },
    { label: "Kerja", x: left + 306, width: 54 },
    { label: "Lembur", x: left + 364, width: 74 },
    { label: "Nominal", x: left + 442, width: 70 }
  ];
  const drawHeader = () => {
    doc.roundedRect(left, y, width, 24, 6).fill("#2E6FA0");
    doc.fillColor("#FFFFFF").font("Helvetica-Bold").fontSize(8);
    columns.forEach((col) => doc.text(col.label, col.x + 3, y + 8, { width: col.width }));
    y += 28;
  };
  drawHeader();
  doc.font("Helvetica").fontSize(8);
  workDays.forEach((item, index) => {
    if (y > 744) {
      doc.addPage();
      y = 42;
      drawHeader();
    }
    const rowHeight = 34;
    doc.rect(left, y - 3, width, rowHeight).fill(index % 2 === 0 ? "#FFFFFF" : "#F8FAFC");
    doc.fillColor("#101828").font("Helvetica").fontSize(8);
    doc.text(dateText(item.date), columns[0].x + 3, y + 5, { width: columns[0].width });
    doc.text(String(item.project_name || "-"), columns[1].x + 3, y + 5, { width: columns[1].width, height: 22, ellipsis: true });
    doc.text(timeText(item.check_in_time), columns[2].x + 3, y + 5, { width: columns[2].width });
    doc.text(timeText(item.check_out_time), columns[3].x + 3, y + 5, { width: columns[3].width });
    doc.text(durationText(item.work_minutes), columns[4].x + 3, y + 5, { width: columns[4].width });
    doc.text(durationText(item.overtime_minutes), columns[5].x + 3, y + 5, { width: columns[5].width });
    doc.text(rupiahText(item.overtime_amount), columns[6].x + 3, y + 5, { width: columns[6].width });
    y += rowHeight;
  });

  y += 16;
  if (y > 714) {
    doc.addPage();
    y = 42;
  }
  doc.roundedRect(left, y, width, 74, 12).fillAndStroke("#FFFFFF", "#D9DEE7");
  doc.fillColor("#101828").font("Helvetica-Bold").fontSize(11).text("Ringkasan Payroll", left + 14, y + 13);
  doc.font("Helvetica").fontSize(9);
  doc.text(`Gaji normal: ${rupiahText(payroll.normal_salary)}`, left + 14, y + 34);
  doc.text(`Potongan cashbon: -${rupiahText(payroll.cashbon_deduction)}`, left + 190, y + 34);
  doc.fillColor("#0E987F").font("Helvetica-Bold").fontSize(13).text(`Total diterima: ${rupiahText(payroll.net_salary)}`, left + 360, y + 31, { width: 150, align: "right" });
  doc.fillColor("#667085").font("Helvetica").fontSize(8).text("Dokumen ini dibuat otomatis dari data absen yang sudah check-out/corrected pada periode payroll.", left + 14, y + 56, { width: width - 28 });

  return pdfBuffer(doc);
}

async function payrollWorkDays(payroll, client = pool) {
  return many(
    `SELECT a.id, a.date::text AS date, a.project_name, a.check_in_time, a.check_out_time, a.status,
            GREATEST(0, ROUND(EXTRACT(EPOCH FROM (COALESCE(a.check_out_time, a.check_in_time) - a.check_in_time)) / 60))::int AS work_minutes,
            COALESCE(ot.overtime_minutes, 0)::int AS overtime_minutes,
            COALESCE(ot.overtime_amount, 0)::int AS overtime_amount,
            ot.overtime_start_time,
            ot.overtime_end_time,
            ot.overtime_project_name
     FROM attendance a
     LEFT JOIN (
       SELECT employee_id, date, SUM(duration_minutes)::int AS overtime_minutes, SUM(amount)::int AS overtime_amount,
              MIN(start_time) AS overtime_start_time, MAX(end_time) AS overtime_end_time, STRING_AGG(DISTINCT project_name, ', ') AS overtime_project_name
       FROM overtime
       WHERE status IN ('approved', 'corrected')
       GROUP BY employee_id, date
     ) ot ON ot.employee_id = a.employee_id AND ot.date = a.date
     WHERE a.employee_id = $1
       AND a.date BETWEEN $2::date AND $3::date
       AND a.status IN ('completed', 'corrected')
     ORDER BY a.date`,
    [payroll.employee_id, payroll.period_start, payroll.period_end],
    client
  );
}

async function latestSalaryRate(employeeId, atDate = today(), client = pool) {
  return one(
    `SELECT * FROM salary_rates
     WHERE employee_id = $1
       AND effective_date <= $2::date
       AND (effective_until IS NULL OR effective_until >= $2::date)
     ORDER BY effective_date DESC
     LIMIT 1`,
    [employeeId, atDate],
    client
  );
}

async function cashbonBalance(employeeId, client = pool) {
  const row = await one(
    `SELECT
       COALESCE((SELECT SUM(amount) FROM cashbon_transactions WHERE employee_id = $1 AND status = 'approved'), 0) AS total_cashbon,
       COALESCE((SELECT SUM(amount) FROM cashbon_deductions WHERE employee_id = $1), 0) AS total_deduction`,
    [employeeId],
    client
  );
  return Number(row.total_cashbon) - Number(row.total_deduction);
}

async function cashbonLedger(employeeId) {
  return many(
    `SELECT 'cashbon' AS type, id, transaction_date AS date, amount, description, status, NULL AS payroll_id
     FROM cashbon_transactions
     WHERE employee_id = $1
     UNION ALL
     SELECT 'deduction' AS type, id, created_at::date AS date, -amount AS amount, 'Potongan Payroll' AS description, 'applied' AS status, payroll_id
     FROM cashbon_deductions
     WHERE employee_id = $1
     ORDER BY date DESC`,
    [employeeId]
  );
}

async function allocateCashbonDeduction(employeeId, payrollId, amount, adminUser, client) {
  let remaining = amount;
  const rows = await many(
    `SELECT c.id, c.amount, COALESCE(SUM(d.amount), 0) AS deducted
     FROM cashbon_transactions c
     LEFT JOIN cashbon_deductions d ON d.cashbon_id = c.id
     WHERE c.employee_id = $1 AND c.status = 'approved'
     GROUP BY c.id, c.amount, c.transaction_date
     ORDER BY c.transaction_date ASC`,
    [employeeId],
    client
  );
  for (const row of rows) {
    if (remaining <= 0) break;
    const available = Number(row.amount) - Number(row.deducted);
    if (available <= 0) continue;
    const deductionAmount = Math.min(available, remaining);
    await q(
      `INSERT INTO cashbon_deductions (id, cashbon_id, employee_id, payroll_id, amount, created_by, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
      [randomUUID(), row.id, employeeId, payrollId, deductionAmount, adminUser.id],
      client
    );
    remaining -= deductionAmount;
  }
}

async function payrollCalculation(employee, periodStart, periodEnd, deductionAmount = 0, client = pool) {
  const rate = await latestSalaryRate(employee.id, periodEnd, client);
  if (!rate) return { error: `Rate gaji belum tersedia untuk ${employee.name}.` };
  const attendance = await one(
    `SELECT COUNT(*)::int AS working_days
     FROM attendance
     WHERE employee_id = $1
       AND date BETWEEN $2::date AND $3::date
       AND status IN ('completed', 'corrected')`,
    [employee.id, periodStart, periodEnd],
    client
  );
  const overtime = await one(
    `SELECT COALESCE(SUM(duration_minutes), 0)::int AS overtime_minutes, COALESCE(SUM(amount), 0)::int AS overtime_amount
     FROM overtime
     WHERE employee_id = $1
       AND date BETWEEN $2::date AND $3::date
       AND status IN ('approved', 'corrected')`,
    [employee.id, periodStart, periodEnd],
    client
  );

  const workingDays = Number(attendance.working_days);
  const dailyRate = Number(rate.daily_rate);
  const overtimeRate = Number(rate.overtime_rate);
  const normalSalary = workingDays * dailyRate;
  const overtimeAmount = Number(overtime.overtime_amount);
  const cashbonDeduction = moneyRound(deductionAmount);
  const balance = await cashbonBalance(employee.id, client);
  return {
    employee_id: employee.id,
    employee_name: employee.name,
    period_start: periodStart,
    period_end: periodEnd,
    working_days: workingDays,
    daily_rate_snapshot: dailyRate,
    overtime_rate_snapshot: overtimeRate,
    overtime_minutes: Number(overtime.overtime_minutes),
    normal_salary: normalSalary,
    overtime_amount: overtimeAmount,
    cashbon_balance: balance,
    cashbon_deduction: cashbonDeduction,
    net_salary: normalSalary + overtimeAmount - cashbonDeduction
  };
}

const routes = [];
function route(method, pattern, handler) {
  const keys = [];
  const regex = new RegExp("^" + pattern.replace(/:([A-Za-z0-9_]+)/g, (_, key) => {
    keys.push(key);
    return "([^/]+)";
  }) + "$", "i");
  routes.push({ method, regex, keys, handler });
}

function matchRoute(method, pathname) {
  for (const item of routes) {
    if (item.method !== method) continue;
    const match = pathname.match(item.regex);
    if (!match) continue;
    return { handler: item.handler, params: Object.fromEntries(item.keys.map((key, index) => [key, decodeURIComponent(match[index + 1])])) };
  }
  return null;
}

route("GET", "/api/health", async (_req, res) => {
  await q("SELECT 1");
  send(res, 200, { status: "ok", database: "postgres", time: nowIso() });
});

route("POST", "/api/auth/login", async (req, res) => {
  const body = await readBody(req);
  const user = await one(
    `SELECT id, name, username, role, employee_id, status FROM app_users
     WHERE username = $1 AND password = $2 AND status = 'active'`,
    [body.username, body.password]
  );
  if (!user) return error(res, 401, "Username atau password salah.");
  const token = randomUUID();
  await q("INSERT INTO sessions (token, user_id) VALUES ($1, $2)", [token, user.id]);
  send(res, 200, { token, user: publicUser(user) });
});

route("POST", "/api/auth/register", async (req, res) => {
  const body = await readBody(req);
  const name = String(body.name || "").trim();
  const username = String(body.username || "").trim().toLowerCase();
  const password = String(body.password || "");
  if (name.length < 3 || username.length < 3 || password.length < 6) {
    return error(res, 422, "Nama, username, dan password wajib valid.");
  }

  const result = await tx(async (client) => {
    const exists = await one("SELECT id FROM app_users WHERE LOWER(username) = $1", [username], client);
    if (exists) {
      const err = new Error("Username sudah digunakan.");
      err.status = 409;
      throw err;
    }
    const userId = randomUUID();
    const employeeId = randomUUID();
    const employeeCode = `EMP-${randomUUID().slice(0, 8).toUpperCase()}`;
    const user = await one(
      `INSERT INTO app_users (id, name, username, password, role, employee_id, status)
       VALUES ($1, $2, $3, $4, 'employee', $5, 'active')
       RETURNING id, name, username, role, employee_id, status`,
      [userId, name, username, password, employeeId],
      client
    );
    await q(
      `INSERT INTO employees (id, user_id, employee_code, name, status)
       VALUES ($1, $2, $3, $4, 'active')`,
      [employeeId, userId, employeeCode, name],
      client
    );
    await q(
      `INSERT INTO salary_rates (id, employee_id, daily_rate, overtime_rate, effective_date)
       VALUES ($1, $2, 150000, 30000, $3::date)`,
      [randomUUID(), employeeId, today()],
      client
    );
    const token = randomUUID();
    await q("INSERT INTO sessions (token, user_id) VALUES ($1, $2)", [token, userId], client);
    await audit(user, "auth", userId, "register", null, publicUser(user), client);
    return { token, user: publicUser(user) };
  });

  send(res, 201, result);
});

route("POST", "/api/auth/register-admin", async (req, res) => {
  const body = await readBody(req);
  const name = String(body.name || "").trim();
  const username = String(body.username || "").trim().toLowerCase();
  const password = String(body.password || "");
  if (name.length < 3 || username.length < 3 || password.length < 6) {
    return error(res, 422, "Nama, username, dan password wajib valid.");
  }

  const result = await tx(async (client) => {
    const adminExists = await one("SELECT id FROM app_users WHERE role = 'admin' AND status = 'active' LIMIT 1", [], client);
    if (adminExists) {
      const err = new Error("Admin pertama sudah dibuat.");
      err.status = 409;
      throw err;
    }
    const usernameExists = await one("SELECT id FROM app_users WHERE LOWER(username) = $1", [username], client);
    if (usernameExists) {
      const err = new Error("Username sudah digunakan.");
      err.status = 409;
      throw err;
    }
    const user = await one(
      `INSERT INTO app_users (id, name, username, password, role, employee_id, status)
       VALUES ($1, $2, $3, $4, 'admin', NULL, 'active')
       RETURNING id, name, username, role, employee_id, status`,
      [randomUUID(), name, username, password],
      client
    );
    const token = randomUUID();
    await q("INSERT INTO sessions (token, user_id) VALUES ($1, $2)", [token, user.id], client);
    await audit(user, "auth", user.id, "register_admin", null, publicUser(user), client);
    return { token, user: publicUser(user) };
  });

  send(res, 201, result);
});

route("GET", "/api/auth/me", async (req, res) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  send(res, 200, { user: publicUser(user) });
});

route("GET", "/api/employees", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const employees = await many("SELECT * FROM employees ORDER BY employee_code");
  send(res, 200, { employees });
});

route("GET", "/api/employees/:id", async (req, res, params) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  if (!canAccessEmployee(user, params.id)) return error(res, 403, "Tidak boleh melihat data karyawan ini.");
  const employee = await one("SELECT * FROM employees WHERE id = $1", [params.id]);
  if (!employee) return error(res, 404, "Karyawan tidak ditemukan.");
  send(res, 200, { employee });
});

route("GET", "/api/employees/:id/salary-rate", async (req, res, params) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const salaryRate = await latestSalaryRate(params.id);
  if (!salaryRate) return error(res, 404, "Rate gaji belum tersedia.");
  send(res, 200, { salary_rate: salaryRate });
});

route("PUT", "/api/employees/:id/salary-rate", async (req, res, params) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const body = await readBody(req);
  if (!isPositiveNumber(body.daily_rate) || !isPositiveNumber(body.overtime_rate)) return error(res, 422, "Daily rate dan overtime rate wajib angka positif.");
  const oldRate = await latestSalaryRate(params.id);
  const salaryRate = await one(
    `INSERT INTO salary_rates (id, employee_id, daily_rate, overtime_rate, effective_date, updated_by, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, NOW()) RETURNING *`,
    [randomUUID(), params.id, moneyRound(body.daily_rate), moneyRound(body.overtime_rate), body.effective_date || today(), user.id]
  );
  await audit(user, "salary_rate", salaryRate.id, "update", oldRate, salaryRate);
  send(res, 200, { salary_rate: salaryRate });
});

route("GET", "/api/attendance/today", async (req, res) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  const url = new URL(req.url, `http://${req.headers.host}`);
  const employeeId = user.role === ROLE.ADMIN ? url.searchParams.get("employee_id") : user.employee_id;
  if (!employeeId) return error(res, 422, "employee_id wajib untuk Admin.");
  if (!canAccessEmployee(user, employeeId)) return error(res, 403, "Tidak boleh melihat attendance ini.");
  const attendance = await one(
    `SELECT a.*, e.name AS employee_name,
       CASE WHEN a.check_out_time IS NULL THEN 0 ELSE FLOOR(EXTRACT(EPOCH FROM (a.check_out_time - a.check_in_time)) / 60)::int END AS duration_minutes
     FROM attendance a JOIN employees e ON e.id = a.employee_id
     WHERE a.employee_id = $1 AND a.date = $2::date`,
    [employeeId, today()]
  );
  send(res, 200, { attendance: attendanceDto(attendance, user.role === ROLE.ADMIN || user.employee_id === employeeId) });
});

route("POST", "/api/attendance/check-in", async (req, res) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  if (user.role !== ROLE.EMPLOYEE) return error(res, 403, "Check-in hanya untuk karyawan.");
  const body = await readBody(req);
  if (!body.project_name || String(body.project_name).trim().length < 3) return error(res, 422, "Proyek/lokasi kerja wajib diisi.");
  if (!body.photo) return error(res, 422, "Foto bukti wajib tersedia sebelum Check-in.");
  if (!Number.isFinite(Number(body.latitude)) || !Number.isFinite(Number(body.longitude))) return error(res, 422, "Latitude dan longitude wajib valid.");
  const exists = await one("SELECT id FROM attendance WHERE employee_id = $1 AND date = $2::date", [user.employee_id, today()]);
  if (exists) return error(res, 409, "Karyawan sudah memiliki attendance hari ini.");
  const attendance = await one(
    `INSERT INTO attendance (id, employee_id, date, project_name, check_in_time, check_in_latitude, check_in_longitude, check_in_photo, notes, status, created_at, updated_at)
     VALUES ($1, $2, $3::date, $4, NOW(), $5, $6, $7, $8, 'running', NOW(), NOW()) RETURNING *`,
    [randomUUID(), user.employee_id, today(), String(body.project_name).trim(), Number(body.latitude), Number(body.longitude), body.photo, body.notes || ""]
  );
  await audit(user, "attendance", attendance.id, "check_in", null, attendance);
  send(res, 201, { attendance });
});

route("POST", "/api/attendance/check-out", async (req, res) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  if (user.role !== ROLE.EMPLOYEE) return error(res, 403, "Check-out hanya untuk karyawan.");
  const before = await one("SELECT * FROM attendance WHERE employee_id = $1 AND status = 'running' ORDER BY check_in_time DESC LIMIT 1", [user.employee_id]);
  if (!before) return error(res, 409, "Tidak ada attendance aktif untuk Check-out.");
  const attendance = await one(
    `UPDATE attendance SET check_out_time = NOW(), status = 'completed', updated_at = NOW()
     WHERE id = $1 RETURNING *`,
    [before.id]
  );
  await audit(user, "attendance", attendance.id, "check_out", before, attendance);
  send(res, 200, { attendance, duration_minutes: minutesBetween(attendance.check_in_time, attendance.check_out_time) });
});

route("GET", "/api/attendance/history", async (req, res) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  const url = new URL(req.url, `http://${req.headers.host}`);
  const employeeId = user.role === ROLE.ADMIN ? url.searchParams.get("employee_id") : user.employee_id;
  if (employeeId && !canAccessEmployee(user, employeeId)) return error(res, 403, "Tidak boleh melihat history ini.");
  const rows = await many(
    `SELECT a.*, e.name AS employee_name,
       CASE WHEN a.check_out_time IS NULL THEN 0 ELSE FLOOR(EXTRACT(EPOCH FROM (a.check_out_time - a.check_in_time)) / 60)::int END AS duration_minutes
     FROM attendance a JOIN employees e ON e.id = a.employee_id
     WHERE ($1::text IS NULL OR a.employee_id = $1)
     ORDER BY a.date DESC, a.check_in_time DESC`,
    [employeeId || null]
  );
  send(res, 200, { attendance: rows.map((row) => attendanceDto(row, user.role === ROLE.ADMIN || user.employee_id === row.employee_id)) });
});

route("GET", "/api/attendance", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const url = new URL(req.url, `http://${req.headers.host}`);
  const status = url.searchParams.get("status");
  const date = url.searchParams.get("date");
  const rows = await many(
    `SELECT a.*, e.name AS employee_name,
       CASE WHEN a.check_out_time IS NULL THEN 0 ELSE FLOOR(EXTRACT(EPOCH FROM (a.check_out_time - a.check_in_time)) / 60)::int END AS duration_minutes
     FROM attendance a JOIN employees e ON e.id = a.employee_id
     WHERE ($1::text IS NULL OR a.status = $1)
       AND ($2::date IS NULL OR a.date = $2::date)
     ORDER BY a.date DESC, a.check_in_time DESC`,
    [status || null, date || null]
  );
  send(res, 200, { attendance: rows.map((row) => attendanceDto(row, true)) });
});

route("GET", "/api/attendance/:id", async (req, res, params) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  const row = await one(
    `SELECT a.*, e.name AS employee_name,
       CASE WHEN a.check_out_time IS NULL THEN 0 ELSE FLOOR(EXTRACT(EPOCH FROM (a.check_out_time - a.check_in_time)) / 60)::int END AS duration_minutes
     FROM attendance a JOIN employees e ON e.id = a.employee_id WHERE a.id = $1`,
    [params.id]
  );
  if (!row) return error(res, 404, "Attendance tidak ditemukan.");
  if (!canAccessEmployee(user, row.employee_id)) return error(res, 403, "Tidak boleh melihat attendance ini.");
  send(res, 200, { attendance: attendanceDto(row, user.role === ROLE.ADMIN || user.employee_id === row.employee_id) });
});

route("PATCH", "/api/attendance/:id/adjust", async (req, res, params) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const body = await readBody(req);
  if (!body.reason || String(body.reason).trim().length < 3) return error(res, 422, "Alasan koreksi wajib diisi.");
  const before = await one("SELECT * FROM attendance WHERE id = $1", [params.id]);
  if (!before) return error(res, 404, "Attendance tidak ditemukan.");
  const locked = await one(
    `SELECT id FROM payrolls WHERE employee_id = $1 AND $2::date BETWEEN period_start AND period_end AND status IN ('published', 'paid') LIMIT 1`,
    [before.employee_id, before.date]
  );
  if (locked) return error(res, 409, "Payroll sudah published/paid. Koreksi butuh mekanisme reopen.");
  const next = {
    project_name: body.project_name ?? before.project_name,
    check_in_time: body.check_in_time ?? before.check_in_time,
    check_out_time: body.check_out_time ?? before.check_out_time,
    notes: body.notes ?? before.notes,
    status: body.status ?? (before.status === ATTENDANCE.REJECTED ? ATTENDANCE.REJECTED : ATTENDANCE.CORRECTED)
  };
  const attendance = await one(
    `UPDATE attendance SET project_name = $2, check_in_time = $3, check_out_time = $4, notes = $5, status = $6, updated_at = NOW()
     WHERE id = $1 RETURNING *`,
    [params.id, next.project_name, next.check_in_time, next.check_out_time, next.notes, next.status]
  );
  await audit(user, "attendance", attendance.id, "adjust", before, { ...attendance, reason: body.reason });
  send(res, 200, { attendance });
});

route("GET", "/api/activity", async (req, res) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  const url = new URL(req.url, `http://${req.headers.host}`);
  const date = url.searchParams.get("date") || today();
  const activity = await many(
    `SELECT e.id AS employee_id, e.name AS employee_name,
       CASE
         WHEN ot.id IS NOT NULL THEN 'lembur_berjalan'
         WHEN a.status = 'running' THEN 'masuk'
         WHEN a.check_out_time IS NOT NULL THEN 'pulang'
         ELSE 'belum_masuk'
       END AS status,
       COALESCE(ot.start_time, a.check_out_time, a.check_in_time) AS time,
       COALESCE(ot.project_name, a.project_name) AS project_name,
       $1::date AS date
     FROM employees e
     LEFT JOIN attendance a ON a.employee_id = e.id AND a.date = $1::date
     LEFT JOIN overtime ot ON ot.employee_id = e.id AND ot.date = $1::date AND ot.status = 'running'
     WHERE e.status = 'active'
     ORDER BY e.employee_code`,
    [date]
  );
  send(res, 200, { activity });
});

route("GET", "/api/admin/dashboard", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const date = new URL(req.url, `http://${req.headers.host}`).searchParams.get("date") || today();
  const summary = await one(
    `SELECT
       COUNT(*) FILTER (WHERE a.status = 'running')::int AS masuk,
       COUNT(*) FILTER (WHERE a.id IS NULL)::int AS belum_masuk,
       (SELECT COUNT(*)::int FROM overtime WHERE date = $1::date AND status = 'running') AS lembur,
       (SELECT COUNT(*)::int FROM overtime WHERE status = 'completed') AS pending_overtime
     FROM employees e LEFT JOIN attendance a ON a.employee_id = e.id AND a.date = $1::date
     WHERE e.status = 'active'`,
    [date]
  );
  send(res, 200, { date, summary });
});

route("POST", "/api/overtime/start", async (req, res) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  if (user.role !== ROLE.EMPLOYEE) return error(res, 403, "Mulai lembur hanya untuk karyawan.");
  const body = await readBody(req);
  const attendance = await one("SELECT * FROM attendance WHERE employee_id = $1 AND date = $2::date AND status = 'completed'", [user.employee_id, today()]);
  if (!attendance) return error(res, 409, "Lembur baru bisa dimulai setelah Check-out kerja normal.");
  const running = await one("SELECT id FROM overtime WHERE employee_id = $1 AND date = $2::date AND status = 'running'", [user.employee_id, today()]);
  if (running) return error(res, 409, "Masih ada lembur berjalan.");
  if (!body.project_name || !body.description || !body.photo) return error(res, 422, "Proyek, keterangan, dan foto lembur wajib diisi.");
  if (!Number.isFinite(Number(body.latitude)) || !Number.isFinite(Number(body.longitude))) return error(res, 422, "Latitude dan longitude wajib valid.");
  const rate = await latestSalaryRate(user.employee_id);
  if (!rate) return error(res, 422, "Rate lembur belum tersedia.");
  const overtime = await one(
    `INSERT INTO overtime (id, employee_id, attendance_id, date, project_name, description, photo, latitude, longitude, start_time, rate, status, created_at, updated_at)
     VALUES ($1, $2, $3, $4::date, $5, $6, $7, $8, $9, NOW(), $10, 'running', NOW(), NOW()) RETURNING *`,
    [randomUUID(), user.employee_id, attendance.id, today(), String(body.project_name).trim(), String(body.description).trim(), body.photo, Number(body.latitude), Number(body.longitude), Number(rate.overtime_rate)]
  );
  await audit(user, "overtime", overtime.id, "start", null, overtime);
  send(res, 201, { overtime });
});

route("POST", "/api/overtime/:id/finish", async (req, res, params) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  if (user.role !== ROLE.EMPLOYEE) return error(res, 403, "Selesai lembur hanya untuk karyawan.");
  const before = await one("SELECT * FROM overtime WHERE id = $1 AND employee_id = $2", [params.id, user.employee_id]);
  if (!before) return error(res, 404, "Lembur tidak ditemukan.");
  if (before.status !== OVERTIME.RUNNING) return error(res, 409, "Lembur tidak sedang berjalan.");
  const endTime = nowIso();
  const duration = minutesBetween(before.start_time, endTime);
  const amount = moneyRound((duration / 60) * Number(before.rate));
  const overtime = await one(
    `UPDATE overtime SET end_time = $2, duration_minutes = $3, amount = $4, status = 'completed', updated_at = NOW()
     WHERE id = $1 RETURNING *`,
    [params.id, endTime, duration, amount]
  );
  await audit(user, "overtime", overtime.id, "finish", before, overtime);
  send(res, 200, { overtime });
});

route("GET", "/api/overtime/history", async (req, res) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  const url = new URL(req.url, `http://${req.headers.host}`);
  const employeeId = user.role === ROLE.ADMIN ? url.searchParams.get("employee_id") : user.employee_id;
  if (employeeId && !canAccessEmployee(user, employeeId)) return error(res, 403, "Tidak boleh melihat lembur ini.");
  const rows = await many(
    `SELECT ot.*, e.name AS employee_name FROM overtime ot JOIN employees e ON e.id = ot.employee_id
     WHERE ($1::text IS NULL OR ot.employee_id = $1)
     ORDER BY ot.date DESC, ot.start_time DESC`,
    [employeeId || null]
  );
  send(res, 200, { overtime: rows });
});

route("GET", "/api/overtime/pending", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const rows = await many("SELECT ot.*, e.name AS employee_name FROM overtime ot JOIN employees e ON e.id = ot.employee_id WHERE ot.status = 'completed' ORDER BY ot.date DESC");
  send(res, 200, { overtime: rows });
});

route("POST", "/api/overtime/:id/review", async (req, res, params) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const body = await readBody(req);
  const before = await one("SELECT * FROM overtime WHERE id = $1", [params.id]);
  if (!before) return error(res, 404, "Lembur tidak ditemukan.");
  if (![OVERTIME.COMPLETED, OVERTIME.CORRECTED].includes(before.status)) return error(res, 409, "Hanya lembur completed/corrected yang bisa direview.");
  let overtime;
  if (body.action === "approve" || body.action === "reject") {
    overtime = await one(
      `UPDATE overtime SET status = $2, reviewed_by = $3, reviewed_at = NOW(), updated_at = NOW() WHERE id = $1 RETURNING *`,
      [params.id, body.action === "approve" ? OVERTIME.APPROVED : OVERTIME.REJECTED, user.id]
    );
  } else if (body.action === "correct") {
    if (!isPositiveNumber(body.duration_minutes)) return error(res, 422, "duration_minutes wajib untuk koreksi lembur.");
    const duration = Number(body.duration_minutes);
    overtime = await one(
      `UPDATE overtime SET duration_minutes = $2, amount = $3, status = 'corrected', reviewed_by = $4, reviewed_at = NOW(), updated_at = NOW() WHERE id = $1 RETURNING *`,
      [params.id, duration, moneyRound((duration / 60) * Number(before.rate)), user.id]
    );
  } else {
    return error(res, 422, "action harus approve, reject, atau correct.");
  }
  await audit(user, "overtime", overtime.id, `review_${body.action}`, before, { ...overtime, reason: body.reason || null });
  send(res, 200, { overtime });
});

route("GET", "/api/cashbon", async (req, res) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  const url = new URL(req.url, `http://${req.headers.host}`);
  const employeeId = user.role === ROLE.ADMIN ? url.searchParams.get("employee_id") : user.employee_id;
  if (!employeeId) return error(res, 422, "employee_id wajib.");
  if (!canAccessEmployee(user, employeeId)) return error(res, 403, "Tidak boleh melihat cashbon ini.");
  send(res, 200, { balance: await cashbonBalance(employeeId), ledger: await cashbonLedger(employeeId) });
});

route("POST", "/api/cashbon", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const body = await readBody(req);
  if (!body.employee_id || !isPositiveNumber(body.amount)) return error(res, 422, "employee_id dan amount wajib valid.");
  const cashbon = await one(
    `INSERT INTO cashbon_transactions (id, employee_id, transaction_date, amount, description, status, created_by, created_at)
     VALUES ($1, $2, $3::date, $4, $5, $6, $7, NOW()) RETURNING *`,
    [randomUUID(), body.employee_id, body.transaction_date || today(), moneyRound(body.amount), body.description || "Cashbon", body.status || "approved", user.id]
  );
  await audit(user, "cashbon", cashbon.id, "create", null, cashbon);
  send(res, 201, { cashbon, balance: await cashbonBalance(body.employee_id) });
});

route("GET", "/api/cashbon/:employeeId/balance", async (req, res, params) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  if (!canAccessEmployee(user, params.employeeId)) return error(res, 403, "Tidak boleh melihat saldo cashbon ini.");
  send(res, 200, { employee_id: params.employeeId, balance: await cashbonBalance(params.employeeId) });
});

route("POST", "/api/payroll/generate", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const body = await readBody(req);
  const periodStart = body.period_start;
  const periodEnd = body.period_end;
  if (!periodStart || !periodEnd || periodStart > periodEnd) return error(res, 422, "period_start dan period_end wajib valid.");

  const payrolls = await tx(async (client) => {
    const locked = await one("SELECT id FROM payrolls WHERE period_start = $1::date AND period_end = $2::date AND status IN ('published', 'paid') LIMIT 1", [periodStart, periodEnd], client);
    if (locked) {
      const err = new Error("Payroll periode ini sudah pernah dipublish/paid.");
      err.status = 409;
      throw err;
    }
    await q("DELETE FROM payrolls WHERE period_start = $1::date AND period_end = $2::date AND status = 'draft'", [periodStart, periodEnd], client);
    const employees = await many("SELECT * FROM employees WHERE status = 'active' ORDER BY employee_code", [], client);
    const created = [];
    for (const employee of employees) {
      const calculated = await payrollCalculation(employee, periodStart, periodEnd, 0, client);
      if (calculated.error) {
        const err = new Error(calculated.error);
        err.status = 422;
        throw err;
      }
      const payroll = await one(
        `INSERT INTO payrolls (id, employee_id, employee_name, period_start, period_end, working_days, daily_rate_snapshot, overtime_rate_snapshot, overtime_minutes, normal_salary, overtime_amount, cashbon_balance, cashbon_deduction, net_salary, status, created_by, created_at, updated_at)
         VALUES ($1, $2, $3, $4::date, $5::date, $6, $7, $8, $9, $10, $11, $12, $13, $14, 'draft', $15, NOW(), NOW()) RETURNING *`,
        [randomUUID(), calculated.employee_id, calculated.employee_name, periodStart, periodEnd, calculated.working_days, calculated.daily_rate_snapshot, calculated.overtime_rate_snapshot, calculated.overtime_minutes, calculated.normal_salary, calculated.overtime_amount, calculated.cashbon_balance, calculated.cashbon_deduction, calculated.net_salary, user.id],
        client
      );
      created.push(payroll);
    }
    await audit(user, "payroll", `${periodStart}_${periodEnd}`, "generate", null, created.map((item) => item.id), client);
    return created;
  });
  send(res, 201, { payrolls: payrolls.map((row) => payrollDto(row, user)) });
});

route("GET", "/api/payroll", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const url = new URL(req.url, `http://${req.headers.host}`);
  const rows = await many(
    `SELECT * FROM payrolls
     WHERE ($1::date IS NULL OR period_start = $1::date)
       AND ($2::date IS NULL OR period_end = $2::date)
     ORDER BY employee_name`,
    [url.searchParams.get("period_start"), url.searchParams.get("period_end")]
  );
  send(res, 200, { payrolls: rows.map((row) => payrollDto(row, user)) });
});

route("GET", "/api/payroll/:id", async (req, res, params) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  const payroll = await one("SELECT * FROM payrolls WHERE id = $1", [params.id]);
  if (!payroll) return error(res, 404, "Payroll tidak ditemukan.");
  if (!canAccessEmployee(user, payroll.employee_id)) return error(res, 403, "Tidak boleh melihat payroll ini.");
  if (user.role === ROLE.EMPLOYEE && ![PAYROLL.PUBLISHED, PAYROLL.PAID].includes(payroll.status)) return error(res, 403, "Payslip belum diterbitkan.");
  send(res, 200, { payroll: payrollDto(payroll, user) });
});

route("GET", "/api/payroll/:id/document", async (req, res, params) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  const payroll = await one("SELECT * FROM payrolls WHERE id = $1", [params.id]);
  if (!payroll) return error(res, 404, "Payroll tidak ditemukan.");
  if (!canAccessEmployee(user, payroll.employee_id)) return error(res, 403, "Tidak boleh melihat dokumen payroll ini.");
  if (user.role === ROLE.EMPLOYEE && ![PAYROLL.PUBLISHED, PAYROLL.PAID].includes(payroll.status)) return error(res, 403, "Dokumen belum diterbitkan.");
  const workDays = await payrollWorkDays(payroll);
  send(res, 200, { document: buildPayrollDocument(payroll, workDays, user) });
});

route("GET", "/api/payroll/:id/document.pdf", async (req, res, params) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  const payroll = await one("SELECT * FROM payrolls WHERE id = $1", [params.id]);
  if (!payroll) return error(res, 404, "Payroll tidak ditemukan.");
  if (!canAccessEmployee(user, payroll.employee_id)) return error(res, 403, "Tidak boleh melihat dokumen payroll ini.");
  if (user.role === ROLE.EMPLOYEE && ![PAYROLL.PUBLISHED, PAYROLL.PAID].includes(payroll.status)) return error(res, 403, "Dokumen belum diterbitkan.");
  const workDays = await payrollWorkDays(payroll);
  const pdf = await buildPayrollPdf(payroll, workDays);
  sendPdf(res, pdf, payrollDocumentFileName(payroll));
});

route("PATCH", "/api/payroll/:id/cashbon-deduction", async (req, res, params) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const body = await readBody(req);
  const before = await one("SELECT * FROM payrolls WHERE id = $1", [params.id]);
  if (!before) return error(res, 404, "Payroll tidak ditemukan.");
  if (![PAYROLL.DRAFT, PAYROLL.REVIEWED].includes(before.status)) return error(res, 409, "Potongan hanya bisa diubah sebelum payroll published.");
  const amount = moneyRound(body.amount || 0);
  const balance = await cashbonBalance(before.employee_id);
  if (amount < 0) return error(res, 422, "Potongan cashbon tidak boleh negatif.");
  if (amount > balance) return error(res, 422, "Potongan cashbon tidak boleh lebih besar dari saldo aktif.");
  const payroll = await one(
    `UPDATE payrolls
     SET cashbon_deduction = $2, cashbon_balance = $3, net_salary = normal_salary + overtime_amount - $2, status = 'reviewed', updated_at = NOW()
     WHERE id = $1 RETURNING *`,
    [params.id, amount, balance]
  );
  await audit(user, "payroll", payroll.id, "set_cashbon_deduction", before, payroll);
  send(res, 200, { payroll: payrollDto(payroll, user), remaining_cashbon_after_payroll: balance - amount });
});

async function publishPayroll(payrollId, user, client) {
  const before = await one("SELECT * FROM payrolls WHERE id = $1 FOR UPDATE", [payrollId], client);
  if (!before) {
    const err = new Error("Payroll tidak ditemukan.");
    err.status = 404;
    throw err;
  }
  if (![PAYROLL.DRAFT, PAYROLL.REVIEWED].includes(before.status)) {
    const err = new Error("Payroll sudah published/paid.");
    err.status = 409;
    throw err;
  }
  const pending = await one(
    `SELECT id FROM overtime WHERE employee_id = $1 AND date BETWEEN $2::date AND $3::date AND status = 'completed' LIMIT 1`,
    [before.employee_id, before.period_start, before.period_end],
    client
  );
  if (pending) {
    const err = new Error("Masih ada lembur yang perlu review sebelum publish.");
    err.status = 409;
    throw err;
  }
  const payroll = await one(
    `UPDATE payrolls SET status = 'published', published_at = NOW(), published_by = $2, updated_at = NOW()
     WHERE id = $1 RETURNING *`,
    [payrollId, user.id],
    client
  );
  if (Number(payroll.cashbon_deduction) > 0) await allocateCashbonDeduction(payroll.employee_id, payroll.id, Number(payroll.cashbon_deduction), user, client);
  const payslip = await one(
    `INSERT INTO payslips (id, payroll_id, employee_id, issued_at, issued_by)
     VALUES ($1, $2, $3, NOW(), $4)
     ON CONFLICT (payroll_id) DO UPDATE SET issued_at = EXCLUDED.issued_at, issued_by = EXCLUDED.issued_by
     RETURNING *`,
    [randomUUID(), payroll.id, payroll.employee_id, user.id],
    client
  );
  await audit(user, "payroll", payroll.id, "publish", before, payroll, client);
  return { payroll, payslip };
}

route("POST", "/api/payroll/:id/publish", async (req, res, params) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const result = await tx((client) => publishPayroll(params.id, user, client));
  send(res, 200, { payroll: payrollDto(result.payroll, user), payslip: result.payslip });
});

route("POST", "/api/payroll/publish-period", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const body = await readBody(req);
  if (!body.period_start || !body.period_end) return error(res, 422, "period_start dan period_end wajib diisi.");
  const result = await tx(async (client) => {
    const rows = await many(
      "SELECT id FROM payrolls WHERE period_start = $1::date AND period_end = $2::date AND status IN ('draft', 'reviewed') ORDER BY employee_name FOR UPDATE",
      [body.period_start, body.period_end],
      client
    );
    if (rows.length === 0) {
      const err = new Error("Tidak ada payroll draft untuk periode ini.");
      err.status = 404;
      throw err;
    }
    const published = [];
    for (const row of rows) published.push((await publishPayroll(row.id, user, client)).payroll);
    return published;
  });
  send(res, 200, { published_count: result.length, payrolls: result.map((row) => payrollDto(row, user)) });
});

route("POST", "/api/payroll/:id/mark-paid", async (req, res, params) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const body = await readBody(req);
  const before = await one("SELECT * FROM payrolls WHERE id = $1", [params.id]);
  if (!before) return error(res, 404, "Payroll tidak ditemukan.");
  if (![PAYROLL.PUBLISHED, PAYROLL.PAID].includes(before.status)) return error(res, 409, "Payroll harus published sebelum ditandai paid.");
  const payroll = await one(
    `UPDATE payrolls SET status = 'paid', paid_at = NOW(), paid_by = $2, payment_note = $3, payment_reference = $4, updated_at = NOW()
     WHERE id = $1 RETURNING *`,
    [params.id, user.id, body.payment_note || null, body.payment_reference || null]
  );
  await audit(user, "payroll", payroll.id, "mark_paid", before, payroll);
  send(res, 200, { payroll: payrollDto(payroll, user) });
});

route("GET", "/api/payslips", async (req, res) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  const url = new URL(req.url, `http://${req.headers.host}`);
  const employeeId = user.role === ROLE.ADMIN ? url.searchParams.get("employee_id") : user.employee_id;
  if (!employeeId) return error(res, 422, "employee_id wajib.");
  if (!canAccessEmployee(user, employeeId)) return error(res, 403, "Tidak boleh melihat payslip ini.");
  const rows = await many(
    `SELECT ps.*, to_jsonb(p.*) AS payroll
     FROM payslips ps JOIN payrolls p ON p.id = ps.payroll_id
     WHERE ps.employee_id = $1 AND ($2::boolean OR p.status IN ('published', 'paid'))
     ORDER BY ps.issued_at DESC`,
    [employeeId, user.role === ROLE.ADMIN]
  );
  send(res, 200, { payslips: rows.map((row) => ({ ...row, payroll: payrollDto(row.payroll, user) })) });
});

route("GET", "/api/payslips/:id", async (req, res, params) => {
  const user = await requireAuth(req, res);
  if (!user) return;
  const row = await one(
    `SELECT ps.*, to_jsonb(p.*) AS payroll
     FROM payslips ps JOIN payrolls p ON p.id = ps.payroll_id
     WHERE ps.id = $1`,
    [params.id]
  );
  if (!row) return error(res, 404, "Payslip tidak ditemukan.");
  if (!canAccessEmployee(user, row.employee_id)) return error(res, 403, "Tidak boleh melihat payslip ini.");
  if (user.role === ROLE.EMPLOYEE && ![PAYROLL.PUBLISHED, PAYROLL.PAID].includes(row.payroll.status)) return error(res, 403, "Payslip belum diterbitkan.");
  send(res, 200, { payslip: { id: row.id, payroll_id: row.payroll_id, employee_id: row.employee_id, issued_at: row.issued_at, issued_by: row.issued_by }, payroll: payrollDto(row.payroll, user) });
});

route("GET", "/api/audit-logs", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  const rows = await many("SELECT * FROM audit_logs ORDER BY timestamp DESC LIMIT 200");
  send(res, 200, { audit_logs: rows });
});

const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") return send(res, 204, {});
  const url = new URL(req.url, `http://${req.headers.host}`);
  const matched = matchRoute(req.method, url.pathname);
  if (!matched) return error(res, 404, "Endpoint tidak ditemukan.");
  try {
    await matched.handler(req, res, matched.params);
  } catch (err) {
    error(res, err.status || 500, err.status ? err.message : "Terjadi kesalahan server.", process.env.NODE_ENV === "development" ? String(err.stack || err) : undefined);
  }
});

server.listen(PORT, () => {
  console.log(`Attendance payroll backend listening on http://localhost:${PORT}`);
  console.log(`PostgreSQL: ${DATABASE_URL.replace(/:\/\/([^:]+):([^@]+)@/, "://$1:***@")}`);
});
