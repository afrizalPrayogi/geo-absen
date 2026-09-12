'use client';

import { useEffect, useState } from 'react';

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3000';

const navGroups = [
  { label: 'General', items: [['dashboard', 'Dashboard'], ['attendance', 'Kehadiran'], ['employees', 'Karyawan']] },
  { label: 'Persetujuan', items: [['leave', 'Pengajuan Izin'], ['overtime', 'Review Lembur']] },
  { label: 'Keuangan', items: [['payroll', 'Payroll'], ['cashbon', 'Cashbon']] }
];

const titles = { dashboard: 'Dashboard', attendance: 'Kehadiran', employees: 'Karyawan', leave: 'Pengajuan Izin', overtime: 'Review Lembur', payroll: 'Payroll', cashbon: 'Cashbon' };
const leaveTypeLabels = { sick: 'Sakit', personal: 'Keperluan pribadi', family: 'Acara keluarga', other: 'Lainnya' };

export default function AdminWeb() {
  const [session, setSession] = useState(null);
  const [tab, setTab] = useState('dashboard');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [data, setData] = useState({ summary: {}, activity: [], employees: [], attendance: [], leaves: [], overtime: [], payrolls: [] });
  const [periodStart, setPeriodStart] = useState('2026-09-01');
  const [periodEnd, setPeriodEnd] = useState('2026-09-08');

  async function request(path, options = {}) {
    const response = await fetch(`${API_BASE}${path}`, {
      ...options,
      headers: { 'Content-Type': 'application/json', ...(session?.token ? { Authorization: `Bearer ${session.token}` } : {}), ...(options.headers || {}) }
    });
    if (!response.ok) {
      const body = await response.json().catch(() => ({}));
      throw new Error(body.error?.message || 'Request gagal.');
    }
    return response.json();
  }

  async function login(event) {
    event.preventDefault();
    setLoading(true);
    setMessage('');
    const form = new FormData(event.currentTarget);
    try {
      const response = await fetch(`${API_BASE}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: form.get('username'), password: form.get('password') })
      });
      const body = await response.json();
      if (!response.ok) throw new Error(body.error?.message || 'Login gagal.');
      if (body.user.role !== 'admin') throw new Error('Akun ini bukan admin.');
      setSession(body);
      setMessage('Login admin berhasil.');
    } catch (err) {
      setMessage(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function loadData() {
    if (!session) return;
    setLoading(true);
    try {
      const [dashboard, activity, employees, attendance, leaves, overtime, payrolls] = await Promise.all([
        request('/api/admin/dashboard'),
        request('/api/activity'),
        request('/api/employees'),
        request('/api/attendance'),
        request('/api/leaves'),
        request('/api/overtime/pending'),
        request('/api/payroll')
      ]);
      setData({ summary: dashboard.summary || {}, activity: activity.activity || [], employees: employees.employees || [], attendance: attendance.attendance || [], leaves: leaves.leaves || [], overtime: overtime.overtime || [], payrolls: payrolls.payrolls || [] });
    } catch (err) {
      setMessage(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { loadData(); }, [session]);

  async function action(label, callback) {
    setLoading(true);
    try {
      await callback();
      setMessage(label);
      await loadData();
    } catch (err) {
      setMessage(err.message);
    } finally {
      setLoading(false);
    }
  }

  function reviewLeave(id, actionName) {
    return action(actionName === 'approve' ? 'Izin disetujui.' : 'Izin ditolak.', () => request(`/api/leaves/${id}/review`, { method: 'POST', body: JSON.stringify({ action: actionName, reason: actionName === 'reject' ? 'Tidak sesuai jadwal operasional.' : undefined }) }));
  }

  function reviewOvertime(id) {
    return action('Lembur disetujui.', () => request(`/api/overtime/${id}/review`, { method: 'POST', body: JSON.stringify({ action: 'approve' }) }));
  }

  function generatePayroll() {
    return action('Draft payroll dibuat.', () => request('/api/payroll/generate', { method: 'POST', body: JSON.stringify({ period_start: periodStart, period_end: periodEnd }) }));
  }

  function publishPayroll(id) {
    return action('Payslip dipublish.', () => request(`/api/payroll/${id}/publish`, { method: 'POST' }));
  }

  function markPaid(id) {
    return action('Payroll ditandai paid.', () => request(`/api/payroll/${id}/mark-paid`, { method: 'POST', body: '{}' }));
  }

  async function openPdf(id) {
    setLoading(true);
    try {
      const response = await fetch(`${API_BASE}/api/payroll/${id}/document.pdf`, { headers: { Authorization: `Bearer ${session.token}` } });
      if (!response.ok) throw new Error('PDF belum bisa dibuka. Pastikan payroll sudah valid.');
      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      window.open(url, '_blank');
      setMessage('Preview PDF dibuka di tab baru. Gunakan download dari viewer browser.');
      setTimeout(() => URL.revokeObjectURL(url), 30000);
    } catch (err) {
      setMessage(err.message);
    } finally {
      setLoading(false);
    }
  }

  if (!session) return <LoginScreen onSubmit={login} loading={loading} message={message} />;

  const pendingLeave = data.leaves.filter((item) => item.status === 'pending');
  const content = {
    dashboard: <Dashboard data={data} pendingLeave={pendingLeave} setTab={setTab} />,
    attendance: <AttendancePage items={data.attendance} activity={data.activity} />,
    employees: <EmployeesPage items={data.employees} />,
    leave: <LeavePage items={data.leaves} onReview={reviewLeave} />,
    overtime: <OvertimePage items={data.overtime} onApprove={reviewOvertime} />,
    payroll: <PayrollPage items={data.payrolls} periodStart={periodStart} periodEnd={periodEnd} setPeriodStart={setPeriodStart} setPeriodEnd={setPeriodEnd} onGenerate={generatePayroll} onPublish={publishPayroll} onPaid={markPaid} onPdf={openPdf} />,
    cashbon: <CashbonPage payrolls={data.payrolls} />
  }[tab];

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand"><span className="brand-mark" /><strong>Geo Admin.</strong></div>
        <div className="profile-mini"><div className="avatar">AD</div><div><strong>{session.user.name}</strong><span>HR Administrator</span></div></div>
        {navGroups.map((group) => <div key={group.label}><div className="nav-label">{group.label}</div><nav className="nav">{group.items.map(([id, label]) => <button key={id} className={`nav-item ${tab === id ? 'active' : ''}`} onClick={() => setTab(id)}><span>{label}</span>{id === 'leave' && pendingLeave.length > 0 ? <b>{pendingLeave.length}</b> : null}{id === 'overtime' && data.overtime.length > 0 ? <b>{data.overtime.length}</b> : null}</button>)}</nav></div>)}
        <button className="secondary-btn logout" onClick={() => setSession(null)}>Logout</button>
      </aside>
      <main className="main">
        <header className="topbar"><div><h1>{titles[tab]}</h1><p>Admin web untuk absensi, izin, lembur, payroll, dan cashbon.</p></div><div className="top-actions"><button className="secondary-btn" onClick={() => setTab('leave')}>{pendingLeave.length + data.overtime.length} perlu ditinjau</button><button className="primary-btn" onClick={loadData}>Refresh</button></div></header>
        {loading ? <div className="progress" /> : null}
        {message ? <div className="toast-inline">{message}</div> : null}
        <section className="content">{content}</section>
      </main>
    </div>
  );
}

function LoginScreen({ onSubmit, loading, message }) {
  return <main className="login"><form className="login-card" onSubmit={onSubmit}><div className="brand big"><span className="brand-mark" /><strong>Geo Admin.</strong></div><h1>Masuk Admin</h1><p>Gunakan akun admin backend lokal.</p><label>Username<input name="username" defaultValue="admin" /></label><label>Password<input name="password" type="password" defaultValue="qwerty2026!@#" /></label><button className="primary-btn" disabled={loading}>{loading ? 'Loading...' : 'Login'}</button>{message ? <div className="toast-inline">{message}</div> : null}</form></main>;
}

function Dashboard({ data, pendingLeave, setTab }) {
  const summary = data.summary;
  return <><PageHeading title="Ringkasan hari ini" note="Status terbaru dari aplikasi karyawan." action={<button className="primary-btn" onClick={() => setTab('attendance')}>Lihat kehadiran</button>} /><div className="metrics"><Metric dark label="Hadir/masuk" value={summary.masuk || 0} note="karyawan sedang bekerja" /><Metric label="Izin hari ini" value={summary.izin || 0} note={`${summary.sakit || 0} sakit`} /><Metric label="Belum masuk" value={summary.belum_masuk || 0} note="di luar izin approved" /><Metric label="Perlu review" value={(summary.pending_leave || 0) + (summary.pending_overtime || 0)} note="izin dan lembur" /></div><div className="dashboard-grid"><Panel title="Aktivitas tim" note="Status kerja terbaru">{data.activity.slice(0, 7).map((item) => <ActivityRow key={item.employee_id} item={item} />)}</Panel><Panel title="Perlu tindakan" note="Antrian persetujuan"><button className="action-row" onClick={() => setTab('leave')}><strong>{pendingLeave.length} pengajuan izin</strong><span>Review sakit/izin pribadi</span></button><button className="action-row" onClick={() => setTab('overtime')}><strong>{data.overtime.length} review lembur</strong><span>Verifikasi durasi dan nominal</span></button></Panel></div></>;
}

function AttendancePage({ items, activity }) {
  return <><PageHeading title="Kehadiran" note="Pantau check-in, check-out, lokasi, dan durasi kerja." /><DataTable columns={['Karyawan', 'Proyek', 'Check-in', 'Check-out', 'Durasi', 'Status']} rows={items.map((item) => [item.employee_name || '-', item.project_name, timeOnly(item.check_in_time), timeOnly(item.check_out_time), duration(item.duration_minutes), badge(item.status)])} empty="Belum ada data absensi." /><Panel title="Status hari ini" note="Termasuk izin approved">{activity.map((item) => <ActivityRow key={item.employee_id} item={item} />)}</Panel></>;
}

function EmployeesPage({ items }) {
  return <><PageHeading title="Data karyawan" note="Profil operasional, status, dan rate gaji." action={<button className="primary-btn">Tambah karyawan</button>} /><DataTable columns={['Kode', 'Nama', 'Status']} rows={items.map((item) => [item.employee_code, item.name, badge(item.status)])} empty="Belum ada karyawan." /></>;
}

function LeavePage({ items, onReview }) {
  return <><PageHeading title="Pengajuan izin" note="Izin/sakit memakai rentang tanggal dan tidak dihitung hari kerja payroll." /><div className="metrics"><Metric dark label="Pending" value={items.filter((i) => i.status === 'pending').length} note="menunggu review" /><Metric label="Approved" value={items.filter((i) => i.status === 'approved').length} note="izin valid" /><Metric label="Rejected" value={items.filter((i) => i.status === 'rejected').length} note="ditolak" /><Metric label="Total hari" value={items.reduce((sum, item) => sum + Number(item.duration_days || 0), 0)} note="semua pengajuan" /></div><DataTable columns={['Karyawan', 'Jenis', 'Tanggal', 'Durasi', 'Status', 'Aksi']} rows={items.map((item) => [person(item), leaveTypeLabels[item.type] || item.type, `${dateOnly(item.start_date)} - ${dateOnly(item.end_date)}`, `${item.duration_days} hari`, badge(item.status), item.status === 'pending' ? <div className="row-actions"><button className="mini-btn dark" onClick={() => onReview(item.id, 'approve')}>Approve</button><button className="mini-btn" onClick={() => onReview(item.id, 'reject')}>Reject</button></div> : '-'])} empty="Belum ada pengajuan izin." /></>;
}

function OvertimePage({ items, onApprove }) {
  return <><PageHeading title="Review lembur" note="Verifikasi durasi, bukti lokasi, dan nominal lembur." /><DataTable columns={['Karyawan', 'Proyek', 'Mulai', 'Durasi', 'Nominal', 'Aksi']} rows={items.map((item) => [person(item), item.project_name, timeOnly(item.start_time), duration(item.duration_minutes), rupiah(item.amount), <button className="mini-btn dark" onClick={() => onApprove(item.id)}>Approve</button>])} empty="Tidak ada lembur pending." /></>;
}

function PayrollPage({ items, periodStart, periodEnd, setPeriodStart, setPeriodEnd, onGenerate, onPublish, onPaid, onPdf }) {
  const total = items.reduce((sum, item) => sum + Number(item.net_salary || 0), 0);
  return <><PageHeading title="Payroll" note="Generate, publish payslip, mark paid, dan preview PDF." action={<div className="period"><input value={periodStart} onChange={(e) => setPeriodStart(e.target.value)} /><input value={periodEnd} onChange={(e) => setPeriodEnd(e.target.value)} /><button className="primary-btn" onClick={onGenerate}>Generate</button></div>} /><div className="metrics"><Metric dark label="Total payroll" value={rupiah(total)} note={`${items.length} karyawan`} /><Metric label="Draft" value={items.filter((i) => i.status === 'draft').length} note="belum publish" /><Metric label="Published" value={items.filter((i) => i.status === 'published').length} note="menunggu paid" /><Metric label="Paid" value={items.filter((i) => i.status === 'paid').length} note="selesai" /></div><DataTable columns={['Karyawan', 'Hari kerja', 'Gaji normal', 'Lembur', 'Cashbon', 'Gaji bersih', 'Status', 'Aksi']} rows={items.map((item) => [person(item), `${item.working_days} hari`, rupiah(item.normal_salary), rupiah(item.overtime_amount), `-${rupiah(item.cashbon_deduction)}`, <strong key="net">{rupiah(item.net_salary)}</strong>, badge(item.status), <div className="row-actions"><button className="mini-btn" onClick={() => onPdf(item.id)}>PDF</button>{['draft', 'reviewed'].includes(item.status) ? <button className="mini-btn dark" onClick={() => onPublish(item.id)}>Publish</button> : null}{item.status === 'published' ? <button className="mini-btn dark" onClick={() => onPaid(item.id)}>Paid</button> : null}</div>])} empty="Belum ada payroll. Generate periode dulu." /></>;
}

function CashbonPage({ payrolls }) {
  return <><PageHeading title="Cashbon" note="Saldo dan potongan cashbon terlihat pada payroll." /><DataTable columns={['Karyawan', 'Potongan payroll', 'Status payroll']} rows={payrolls.map((item) => [person(item), rupiah(item.cashbon_deduction), badge(item.status)])} empty="Belum ada data cashbon payroll." /></>;
}

function PageHeading({ title, note, action }) { return <div className="page-heading"><div><h2>{title}</h2><p>{note}</p></div>{action}</div>; }
function Metric({ label, value, note, dark }) { return <article className={`metric ${dark ? 'dark' : ''}`}><span className="dot" /><div className="metric-label">{label}</div><div className="metric-value">{value}</div><div className="metric-note">{note}</div></article>; }
function Panel({ title, note, children }) { return <div className="panel panel-pad"><div className="panel-head"><div><h3>{title}</h3><p>{note}</p></div></div><div className="stack small">{children}</div></div>; }
function ActivityRow({ item }) { return <div className="activity"><div className="avatar">{initials(item.employee_name)}</div><div><strong>{item.employee_name}</strong><small>{statusText(item.status)} {item.project_name ? `- ${item.project_name}` : ''}</small></div><time>{timeOnly(item.time)}</time></div>; }

function DataTable({ columns, rows, empty }) {
  if (!rows.length) return <div className="empty">{empty}</div>;
  return <div className="table-wrap"><table><thead><tr>{columns.map((item) => <th key={item}>{item}</th>)}</tr></thead><tbody>{rows.map((row, index) => <tr key={index}>{row.map((cell, cellIndex) => <td key={cellIndex}>{cell}</td>)}</tr>)}</tbody></table></div>;
}

function badge(value) { return <span className={`badge ${['paid', 'active', 'approved', 'completed'].includes(value) ? 'dark' : value === 'pending' || value === 'draft' ? 'outline' : ''}`}>{value}</span>; }
function person(item) { return <div className="person"><div className="avatar">{initials(item.employee_name || item.name)}</div><div><strong>{item.employee_name || item.name}</strong><small>{item.employee_code || item.employee_id}</small></div></div>; }
function initials(value = '-') { return value.split(' ').filter(Boolean).map((part) => part[0]).join('').slice(0, 2).toUpperCase(); }
function dateOnly(value) { return String(value || '').slice(0, 10); }
function timeOnly(value) { const date = value ? new Date(value) : null; return date && !Number.isNaN(date.valueOf()) ? `${String(date.getHours()).padStart(2, '0')}.${String(date.getMinutes()).padStart(2, '0')}` : '-'; }
function duration(minutes = 0) { const value = Number(minutes || 0); return value ? `${Math.floor(value / 60)}j ${String(value % 60).padStart(2, '0')}m` : '-'; }
function rupiah(value = 0) { return `Rp${Math.round(Number(value || 0)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`; }
function statusText(value) { return { masuk: 'sedang bekerja', pulang: 'sudah pulang', lembur_berjalan: 'lembur berjalan', izin: 'izin', sakit: 'sakit', belum_masuk: 'belum masuk' }[value] || value; }
