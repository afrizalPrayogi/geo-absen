BEGIN;

INSERT INTO app_users (id, name, username, password, role, employee_id, status) VALUES
  ('user-admin', 'Admin', 'admin', 'password', 'admin', NULL, 'active'),
  ('user-budi', 'Budi Santoso', 'budi', 'password', 'employee', NULL, 'active'),
  ('user-doni', 'Doni Saputra', 'doni', 'password', 'employee', NULL, 'active'),
  ('user-ahmad', 'Ahmad', 'ahmad', 'password', 'employee', NULL, 'active'),
  ('user-rudi', 'Rudi', 'rudi', 'password', 'employee', NULL, 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO employees (id, user_id, employee_code, name, status) VALUES
  ('emp-budi', 'user-budi', 'EMP-001', 'Budi Santoso', 'active'),
  ('emp-doni', 'user-doni', 'EMP-002', 'Doni Saputra', 'active'),
  ('emp-ahmad', 'user-ahmad', 'EMP-003', 'Ahmad', 'active'),
  ('emp-rudi', 'user-rudi', 'EMP-004', 'Rudi', 'active')
ON CONFLICT (id) DO NOTHING;

UPDATE employees SET user_id = 'user-budi' WHERE id = 'emp-budi';
UPDATE employees SET user_id = 'user-doni' WHERE id = 'emp-doni';
UPDATE employees SET user_id = 'user-ahmad' WHERE id = 'emp-ahmad';
UPDATE employees SET user_id = 'user-rudi' WHERE id = 'emp-rudi';
UPDATE app_users SET employee_id = 'emp-budi' WHERE id = 'user-budi';
UPDATE app_users SET employee_id = 'emp-doni' WHERE id = 'user-doni';
UPDATE app_users SET employee_id = 'emp-ahmad' WHERE id = 'user-ahmad';
UPDATE app_users SET employee_id = 'emp-rudi' WHERE id = 'user-rudi';

INSERT INTO salary_rates (id, employee_id, daily_rate, overtime_rate, effective_date, updated_by) VALUES
  ('rate-budi', 'emp-budi', 150000, 50000, '2026-08-01', 'user-admin'),
  ('rate-doni', 'emp-doni', 200000, 25000, '2026-08-01', 'user-admin'),
  ('rate-ahmad', 'emp-ahmad', 160000, 30000, '2026-08-01', 'user-admin'),
  ('rate-rudi', 'emp-rudi', 140000, 25000, '2026-08-01', 'user-admin')
ON CONFLICT (id) DO NOTHING;

INSERT INTO attendance (id, employee_id, date, project_name, check_in_time, check_in_latitude, check_in_longitude, check_in_photo, check_out_time, notes, status, created_at, updated_at) VALUES
  ('att-budi-2026-08-26', 'emp-budi', '2026-08-26', 'Apartemen Cempaka', '2026-08-26T01:03:00Z', -6.2088, 106.8456, 'photos/budi-2026-08-26.jpg', '2026-08-26T10:05:00Z', '', 'completed', '2026-08-26T01:03:00Z', '2026-08-26T10:05:00Z'),
  ('att-budi-2026-08-27', 'emp-budi', '2026-08-27', 'Apartemen Cempaka', '2026-08-27T01:00:00Z', -6.2088, 106.8456, 'photos/budi-2026-08-27.jpg', '2026-08-27T10:02:00Z', '', 'completed', '2026-08-27T01:00:00Z', '2026-08-27T10:02:00Z'),
  ('att-budi-2026-08-28', 'emp-budi', '2026-08-28', 'Apartemen Cempaka', '2026-08-28T01:04:00Z', -6.2088, 106.8456, 'photos/budi-2026-08-28.jpg', '2026-08-28T10:06:00Z', '', 'completed', '2026-08-28T01:04:00Z', '2026-08-28T10:06:00Z'),
  ('att-budi-2026-08-29', 'emp-budi', '2026-08-29', 'Apartemen Cempaka', '2026-08-29T01:02:00Z', -6.2088, 106.8456, 'photos/budi-2026-08-29.jpg', '2026-08-29T10:01:00Z', '', 'completed', '2026-08-29T01:02:00Z', '2026-08-29T10:01:00Z'),
  ('att-budi-2026-08-31', 'emp-budi', '2026-08-31', 'Apartemen Cempaka', '2026-08-31T01:05:00Z', -6.2088, 106.8456, 'photos/budi-2026-08-31.jpg', '2026-08-31T10:08:00Z', '', 'completed', '2026-08-31T01:05:00Z', '2026-08-31T10:08:00Z'),
  ('att-budi-2026-09-01', 'emp-budi', '2026-09-01', 'Apartemen Cempaka', '2026-09-01T01:03:00Z', -6.2088, 106.8456, 'photos/budi-2026-09-01.jpg', '2026-09-01T10:05:00Z', '', 'completed', '2026-09-01T01:03:00Z', '2026-09-01T10:05:00Z'),
  ('att-doni-2026-08-26', 'emp-doni', '2026-08-26', 'Proyek Senayan', '2026-08-26T00:58:00Z', -6.2261, 106.8018, 'photos/doni-2026-08-26.jpg', '2026-08-26T10:03:00Z', '', 'completed', '2026-08-26T00:58:00Z', '2026-08-26T10:03:00Z'),
  ('att-doni-2026-08-27', 'emp-doni', '2026-08-27', 'Proyek Senayan', '2026-08-27T00:57:00Z', -6.2261, 106.8018, 'photos/doni-2026-08-27.jpg', '2026-08-27T10:04:00Z', '', 'completed', '2026-08-27T00:57:00Z', '2026-08-27T10:04:00Z'),
  ('att-doni-2026-08-28', 'emp-doni', '2026-08-28', 'Proyek Senayan', '2026-08-28T00:59:00Z', -6.2261, 106.8018, 'photos/doni-2026-08-28.jpg', '2026-08-28T10:01:00Z', '', 'completed', '2026-08-28T00:59:00Z', '2026-08-28T10:01:00Z'),
  ('att-doni-2026-08-29', 'emp-doni', '2026-08-29', 'Proyek Senayan', '2026-08-29T01:01:00Z', -6.2261, 106.8018, 'photos/doni-2026-08-29.jpg', '2026-08-29T10:06:00Z', '', 'completed', '2026-08-29T01:01:00Z', '2026-08-29T10:06:00Z'),
  ('att-doni-2026-08-31', 'emp-doni', '2026-08-31', 'Proyek Senayan', '2026-08-31T00:56:00Z', -6.2261, 106.8018, 'photos/doni-2026-08-31.jpg', '2026-08-31T10:02:00Z', '', 'completed', '2026-08-31T00:56:00Z', '2026-08-31T10:02:00Z'),
  ('att-doni-2026-09-01', 'emp-doni', '2026-09-01', 'Proyek Senayan', '2026-09-01T00:58:00Z', -6.2261, 106.8018, 'photos/doni-2026-09-01.jpg', '2026-09-01T10:03:00Z', '', 'completed', '2026-09-01T00:58:00Z', '2026-09-01T10:03:00Z'),
  ('att-ahmad-2026-09-02', 'emp-ahmad', '2026-09-02', 'Gudang Cikarang', '2026-09-02T01:00:00Z', -6.261, 107.151, 'photos/ahmad-2026-09-02.jpg', '2026-09-02T10:02:00Z', '', 'completed', '2026-09-02T01:00:00Z', '2026-09-02T10:02:00Z')
ON CONFLICT (employee_id, date) DO NOTHING;

INSERT INTO overtime (id, employee_id, attendance_id, date, project_name, description, photo, latitude, longitude, start_time, end_time, duration_minutes, rate, amount, status, reviewed_by, reviewed_at) VALUES
  ('ot-doni-2026-09-01', 'emp-doni', 'att-doni-2026-09-01', '2026-09-01', 'Proyek Senayan', 'Penyelesaian instalasi', 'photos/doni-overtime.jpg', -6.2261, 106.8018, '2026-09-01T11:05:00Z', '2026-09-01T13:05:00Z', 120, 25000, 50000, 'approved', 'user-admin', NOW()),
  ('ot-budi-2026-09-01', 'emp-budi', 'att-budi-2026-09-01', '2026-09-01', 'Apartemen Cempaka', 'Penyelesaian instalasi', 'photos/budi-overtime.jpg', -6.2088, 106.8456, '2026-09-01T11:03:00Z', '2026-09-01T13:03:00Z', 120, 50000, 100000, 'completed', NULL, NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO cashbon_transactions (id, employee_id, transaction_date, amount, description, status, created_by) VALUES
  ('cashbon-budi-1', 'emp-budi', '2026-08-24', 500000, 'Cashbon', 'approved', 'user-admin')
ON CONFLICT (id) DO NOTHING;

INSERT INTO cashbon_deductions (id, cashbon_id, employee_id, payroll_id, amount, created_by, created_at) VALUES
  ('deduction-budi-prev', 'cashbon-budi-1', 'emp-budi', NULL, 150000, 'user-admin', '2026-08-18T10:00:00Z')
ON CONFLICT (id) DO NOTHING;

COMMIT;
