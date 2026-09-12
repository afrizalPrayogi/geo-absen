# Admin Web Next.js

Admin web untuk absensi, pengajuan izin, review lembur, payroll, cashbon, dan preview/download PDF payroll.

## Jalankan lokal

Pastikan backend aktif di port `3000`, lalu jalankan:

```bash
npm run dev
```

Admin web berjalan di:

```text
http://localhost:3001
```

Jika backend tidak berada di `http://localhost:3000`, set environment:

```bash
NEXT_PUBLIC_API_BASE_URL=http://192.168.1.22:3000 npm run dev
```

## Akun fixture

```text
username: admin
password: qwerty2026!@#
```

## Halaman MVP

- Dashboard
- Kehadiran
- Karyawan
- Pengajuan Izin
- Review Lembur
- Payroll
- Cashbon
