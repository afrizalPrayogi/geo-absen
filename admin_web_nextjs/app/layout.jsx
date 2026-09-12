import './globals.css';

export const metadata = {
  title: 'Admin HR',
  description: 'Admin web untuk absensi, izin, lembur, payroll, dan cashbon.'
};

export default function RootLayout({ children }) {
  return (
    <html lang="id">
      <body>{children}</body>
    </html>
  );
}
