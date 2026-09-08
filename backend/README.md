# Attendance Payroll Backend

Backend MVP untuk PRD `Sistem Absensi, Lembur, Cashbon & Payroll Proyek`.

Backend sekarang memakai PostgreSQL melalui dependency `pg`. Tabel dibuat dari `db/schema.sql`; `db/seed.sql` tidak memasukkan data awal.

## Setup PostgreSQL

Opsi paling cepat dengan Docker:

```bash
cd C:\Users\aprayogi\.cache\backend
docker compose up -d
npm install
npm run db:create
npm run db:init
npm start
```

Jika memakai PostgreSQL lokal tanpa Docker, buat database `attendance_payroll`, lalu set `DATABASE_URL`:

```bash
set DATABASE_URL=postgres://postgres:postgres@localhost:5432/attendance_payroll
npm run db:create
npm run db:init
npm start
```

Default koneksi:

```text
postgres://postgres:postgres@localhost:5432/attendance_payroll
```

## Script

- `npm start` menjalankan API server.
- `npm run start:local` menjalankan API server lokal tanpa PostgreSQL untuk demo cepat.
- `npm run check` validasi sintaks JavaScript.
- `npm run db:create` membuat database `attendance_payroll` jika belum ada.
- `npm run db:init` membuat schema database.

## Registrasi dan Login

Data awal dikosongkan. Buat akun karyawan dari aplikasi mobile atau endpoint register.

Register:

```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Nama Karyawan","username":"username","password":"passwordku"}'
```

Login:

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"username","password":"passwordku"}'
```

Gunakan response `token` sebagai header:

```text
Authorization: Bearer <token>
```

## Database Tables

- `app_users`
- `sessions`
- `employees`
- `salary_rates`
- `attendance`
- `overtime`
- `cashbon_transactions`
- `cashbon_deductions`
- `payrolls`
- `payslips`
- `audit_logs`

## Endpoint Utama

### Auth

- `POST /api/auth/login`
- `POST /api/auth/register`
- `GET /api/auth/me`

### Employee dan Salary Rate

- `GET /api/employees` admin
- `GET /api/employees/:id`
- `GET /api/employees/:id/salary-rate` admin
- `PUT /api/employees/:id/salary-rate` admin

### Attendance

- `GET /api/attendance/today`
- `POST /api/attendance/check-in` employee
- `POST /api/attendance/check-out` employee
- `GET /api/attendance/history`
- `GET /api/attendance` admin
- `GET /api/attendance/:id`
- `PATCH /api/attendance/:id/adjust` admin

Check-in wajib mengirim `project_name`, `photo`, `latitude`, dan `longitude`. Saat check-in diterima backend, waktu server, proyek, foto, dan lat-long dikunci ke transaksi attendance.

### Activity

- `GET /api/activity`
- `GET /api/admin/dashboard` admin

### Overtime

- `POST /api/overtime/start` employee
- `POST /api/overtime/:id/finish` employee
- `GET /api/overtime/history`
- `GET /api/overtime/pending` admin
- `POST /api/overtime/:id/review` admin

Overtime hanya bisa dimulai setelah attendance normal sudah `completed`.

### Cashbon

- `GET /api/cashbon?employee_id=<employee_id>`
- `POST /api/cashbon` admin
- `GET /api/cashbon/:employeeId/balance`

Cashbon diperlakukan sebagai saldo terpisah. Potongan payroll bisa `0`, sebagian, atau lunas. Saldo tidak hilang jika potongan minggu berjalan `0`.

### Payroll

- `POST /api/payroll/generate` admin
- `GET /api/payroll` admin
- `GET /api/payroll/:id`
- `PATCH /api/payroll/:id/cashbon-deduction` admin
- `POST /api/payroll/:id/publish` admin
- `POST /api/payroll/publish-period` admin
- `POST /api/payroll/:id/mark-paid` admin

Payroll menyimpan snapshot `daily_rate_snapshot`, `overtime_rate_snapshot`, `working_days`, `overtime_amount`, `cashbon_deduction`, dan `net_salary`.

### Payslip

- `GET /api/payslips`
- `GET /api/payslips/:id`

Employee hanya bisa melihat payslip setelah payroll `published` atau `paid`.

### Audit

- `GET /api/audit-logs` admin

## Contoh Flow Payroll

1. Login admin.
2. Review overtime pending lewat `GET /api/overtime/pending`.
3. Approve overtime lewat `POST /api/overtime/:id/review` dengan body `{ "action": "approve" }`.
4. Generate payroll:

```json
{
  "period_start": "2026-08-26",
  "period_end": "2026-09-01"
}
```

5. Set potongan cashbon per employee lewat `PATCH /api/payroll/:id/cashbon-deduction`.
6. Publish satu payroll atau publish periode.
7. Mark as paid setelah pembayaran manual selesai.

## Catatan Implementasi MVP

- Password masih plain text untuk scaffold lokal; production harus memakai hashing.
- File foto belum disimpan sebagai object storage; field `photo` menerima path/url/base64 dari client.
- Role permission sudah divalidasi di backend, bukan hanya UI.
- Published payroll tidak bisa dikoreksi langsung tanpa mekanisme reopen/adjustment khusus.
