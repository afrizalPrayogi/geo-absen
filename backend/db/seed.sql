BEGIN;

INSERT INTO app_users (id, name, username, password, role, employee_id, status) VALUES
  ('user-andi', 'Andi Pratama', 'andi', 'password', 'employee', NULL, 'active'),
  ('user-siti', 'Siti Aminah', 'siti', 'password', 'employee', NULL, 'active'),
  ('user-dimas', 'Dimas Saputra', 'dimas', 'password', 'employee', NULL, 'active'),
  ('user-maya', 'Maya Lestari', 'maya', 'password', 'employee', NULL, 'active'),
  ('user-reza', 'Reza Maulana', 'reza', 'password', 'employee', NULL, 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO employees (id, user_id, employee_code, name, status) VALUES
  ('emp-andi', 'user-andi', 'EMP-001', 'Andi Pratama', 'active'),
  ('emp-siti', 'user-siti', 'EMP-002', 'Siti Aminah', 'active'),
  ('emp-dimas', 'user-dimas', 'EMP-003', 'Dimas Saputra', 'active'),
  ('emp-maya', 'user-maya', 'EMP-004', 'Maya Lestari', 'active'),
  ('emp-reza', 'user-reza', 'EMP-005', 'Reza Maulana', 'active')
ON CONFLICT (id) DO NOTHING;

UPDATE app_users SET employee_id = 'emp-andi' WHERE id = 'user-andi';
UPDATE app_users SET employee_id = 'emp-siti' WHERE id = 'user-siti';
UPDATE app_users SET employee_id = 'emp-dimas' WHERE id = 'user-dimas';
UPDATE app_users SET employee_id = 'emp-maya' WHERE id = 'user-maya';
UPDATE app_users SET employee_id = 'emp-reza' WHERE id = 'user-reza';

INSERT INTO salary_rates (id, employee_id, daily_rate, overtime_rate, effective_date, updated_by) VALUES
  ('rate-andi', 'emp-andi', 125000, 10000, '2026-09-01', NULL),
  ('rate-siti', 'emp-siti', 150000, 12500, '2026-09-01', NULL),
  ('rate-dimas', 'emp-dimas', 175000, 15000, '2026-09-01', NULL),
  ('rate-maya', 'emp-maya', 200000, 17500, '2026-09-01', NULL),
  ('rate-reza', 'emp-reza', 225000, 20000, '2026-09-01', NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO attendance (id, employee_id, date, project_name, check_in_time, check_in_latitude, check_in_longitude, check_in_photo, check_out_time, notes, status, created_at, updated_at) VALUES
  ('att-andi-2026-09-01', 'emp-andi', '2026-09-01', 'Proyek Menara Utara', '2026-09-01T01:00:00Z', -6.1754, 106.8272, 'photos/andi-2026-09-01.jpg', '2026-09-01T10:02:00Z', '', 'completed', '2026-09-01T01:00:00Z', '2026-09-01T10:02:00Z'),
  ('att-andi-2026-09-02', 'emp-andi', '2026-09-02', 'Proyek Menara Utara', '2026-09-02T01:01:00Z', -6.1754, 106.8272, 'photos/andi-2026-09-02.jpg', '2026-09-02T10:03:00Z', '', 'completed', '2026-09-02T01:01:00Z', '2026-09-02T10:03:00Z'),
  ('att-andi-2026-09-03', 'emp-andi', '2026-09-03', 'Proyek Menara Utara', '2026-09-03T01:02:00Z', -6.1754, 106.8272, 'photos/andi-2026-09-03.jpg', '2026-09-03T10:04:00Z', '', 'completed', '2026-09-03T01:02:00Z', '2026-09-03T10:04:00Z'),
  ('att-andi-2026-09-04', 'emp-andi', '2026-09-04', 'Proyek Menara Utara', '2026-09-04T01:03:00Z', -6.1754, 106.8272, 'photos/andi-2026-09-04.jpg', '2026-09-04T10:05:00Z', '', 'completed', '2026-09-04T01:03:00Z', '2026-09-04T10:05:00Z'),
  ('att-andi-2026-09-07', 'emp-andi', '2026-09-07', 'Proyek Menara Utara', '2026-09-07T01:04:00Z', -6.1754, 106.8272, 'photos/andi-2026-09-07.jpg', '2026-09-07T10:06:00Z', '', 'completed', '2026-09-07T01:04:00Z', '2026-09-07T10:06:00Z'),
  ('att-andi-2026-09-08', 'emp-andi', '2026-09-08', 'Proyek Menara Utara', '2026-09-08T01:05:00Z', -6.1754, 106.8272, 'photos/andi-2026-09-08.jpg', '2026-09-08T10:07:00Z', '', 'completed', '2026-09-08T01:05:00Z', '2026-09-08T10:07:00Z'),
  ('att-siti-2026-09-01', 'emp-siti', '2026-09-01', 'Proyek Gudang Timur', '2026-09-01T01:00:00Z', -6.2297, 106.6894, 'photos/siti-2026-09-01.jpg', '2026-09-01T10:02:00Z', '', 'completed', '2026-09-01T01:00:00Z', '2026-09-01T10:02:00Z'),
  ('att-siti-2026-09-02', 'emp-siti', '2026-09-02', 'Proyek Gudang Timur', '2026-09-02T01:01:00Z', -6.2297, 106.6894, 'photos/siti-2026-09-02.jpg', '2026-09-02T10:03:00Z', '', 'completed', '2026-09-02T01:01:00Z', '2026-09-02T10:03:00Z'),
  ('att-siti-2026-09-03', 'emp-siti', '2026-09-03', 'Proyek Gudang Timur', '2026-09-03T01:02:00Z', -6.2297, 106.6894, 'photos/siti-2026-09-03.jpg', '2026-09-03T10:04:00Z', '', 'completed', '2026-09-03T01:02:00Z', '2026-09-03T10:04:00Z'),
  ('att-siti-2026-09-04', 'emp-siti', '2026-09-04', 'Proyek Gudang Timur', '2026-09-04T01:03:00Z', -6.2297, 106.6894, 'photos/siti-2026-09-04.jpg', '2026-09-04T10:05:00Z', '', 'completed', '2026-09-04T01:03:00Z', '2026-09-04T10:05:00Z'),
  ('att-siti-2026-09-07', 'emp-siti', '2026-09-07', 'Proyek Gudang Timur', '2026-09-07T01:04:00Z', -6.2297, 106.6894, 'photos/siti-2026-09-07.jpg', '2026-09-07T10:06:00Z', '', 'completed', '2026-09-07T01:04:00Z', '2026-09-07T10:06:00Z'),
  ('att-siti-2026-09-08', 'emp-siti', '2026-09-08', 'Proyek Gudang Timur', '2026-09-08T01:05:00Z', -6.2297, 106.6894, 'photos/siti-2026-09-08.jpg', '2026-09-08T10:07:00Z', '', 'completed', '2026-09-08T01:05:00Z', '2026-09-08T10:07:00Z'),
  ('att-dimas-2026-09-01', 'emp-dimas', '2026-09-01', 'Proyek Ruko Selatan', '2026-09-01T01:00:00Z', -6.3024, 106.8951, 'photos/dimas-2026-09-01.jpg', '2026-09-01T10:02:00Z', '', 'completed', '2026-09-01T01:00:00Z', '2026-09-01T10:02:00Z'),
  ('att-dimas-2026-09-02', 'emp-dimas', '2026-09-02', 'Proyek Ruko Selatan', '2026-09-02T01:01:00Z', -6.3024, 106.8951, 'photos/dimas-2026-09-02.jpg', '2026-09-02T10:03:00Z', '', 'completed', '2026-09-02T01:01:00Z', '2026-09-02T10:03:00Z'),
  ('att-dimas-2026-09-03', 'emp-dimas', '2026-09-03', 'Proyek Ruko Selatan', '2026-09-03T01:02:00Z', -6.3024, 106.8951, 'photos/dimas-2026-09-03.jpg', '2026-09-03T10:04:00Z', '', 'completed', '2026-09-03T01:02:00Z', '2026-09-03T10:04:00Z'),
  ('att-dimas-2026-09-04', 'emp-dimas', '2026-09-04', 'Proyek Ruko Selatan', '2026-09-04T01:03:00Z', -6.3024, 106.8951, 'photos/dimas-2026-09-04.jpg', '2026-09-04T10:05:00Z', '', 'completed', '2026-09-04T01:03:00Z', '2026-09-04T10:05:00Z'),
  ('att-dimas-2026-09-07', 'emp-dimas', '2026-09-07', 'Proyek Ruko Selatan', '2026-09-07T01:04:00Z', -6.3024, 106.8951, 'photos/dimas-2026-09-07.jpg', '2026-09-07T10:06:00Z', '', 'completed', '2026-09-07T01:04:00Z', '2026-09-07T10:06:00Z'),
  ('att-dimas-2026-09-08', 'emp-dimas', '2026-09-08', 'Proyek Ruko Selatan', '2026-09-08T01:05:00Z', -6.3024, 106.8951, 'photos/dimas-2026-09-08.jpg', '2026-09-08T10:07:00Z', '', 'completed', '2026-09-08T01:05:00Z', '2026-09-08T10:07:00Z'),
  ('att-maya-2026-09-01', 'emp-maya', '2026-09-01', 'Proyek Apartemen Barat', '2026-09-01T01:00:00Z', -6.2019, 106.7816, 'photos/maya-2026-09-01.jpg', '2026-09-01T10:02:00Z', '', 'completed', '2026-09-01T01:00:00Z', '2026-09-01T10:02:00Z'),
  ('att-maya-2026-09-02', 'emp-maya', '2026-09-02', 'Proyek Apartemen Barat', '2026-09-02T01:01:00Z', -6.2019, 106.7816, 'photos/maya-2026-09-02.jpg', '2026-09-02T10:03:00Z', '', 'completed', '2026-09-02T01:01:00Z', '2026-09-02T10:03:00Z'),
  ('att-maya-2026-09-03', 'emp-maya', '2026-09-03', 'Proyek Apartemen Barat', '2026-09-03T01:02:00Z', -6.2019, 106.7816, 'photos/maya-2026-09-03.jpg', '2026-09-03T10:04:00Z', '', 'completed', '2026-09-03T01:02:00Z', '2026-09-03T10:04:00Z'),
  ('att-maya-2026-09-04', 'emp-maya', '2026-09-04', 'Proyek Apartemen Barat', '2026-09-04T01:03:00Z', -6.2019, 106.7816, 'photos/maya-2026-09-04.jpg', '2026-09-04T10:05:00Z', '', 'completed', '2026-09-04T01:03:00Z', '2026-09-04T10:05:00Z'),
  ('att-maya-2026-09-07', 'emp-maya', '2026-09-07', 'Proyek Apartemen Barat', '2026-09-07T01:04:00Z', -6.2019, 106.7816, 'photos/maya-2026-09-07.jpg', '2026-09-07T10:06:00Z', '', 'completed', '2026-09-07T01:04:00Z', '2026-09-07T10:06:00Z'),
  ('att-maya-2026-09-08', 'emp-maya', '2026-09-08', 'Proyek Apartemen Barat', '2026-09-08T01:05:00Z', -6.2019, 106.7816, 'photos/maya-2026-09-08.jpg', '2026-09-08T10:07:00Z', '', 'completed', '2026-09-08T01:05:00Z', '2026-09-08T10:07:00Z'),
  ('att-reza-2026-09-01', 'emp-reza', '2026-09-01', 'Proyek Mall Pusat', '2026-09-01T01:00:00Z', -6.1931, 106.8218, 'photos/reza-2026-09-01.jpg', '2026-09-01T10:02:00Z', '', 'completed', '2026-09-01T01:00:00Z', '2026-09-01T10:02:00Z'),
  ('att-reza-2026-09-02', 'emp-reza', '2026-09-02', 'Proyek Mall Pusat', '2026-09-02T01:01:00Z', -6.1931, 106.8218, 'photos/reza-2026-09-02.jpg', '2026-09-02T10:03:00Z', '', 'completed', '2026-09-02T01:01:00Z', '2026-09-02T10:03:00Z'),
  ('att-reza-2026-09-03', 'emp-reza', '2026-09-03', 'Proyek Mall Pusat', '2026-09-03T01:02:00Z', -6.1931, 106.8218, 'photos/reza-2026-09-03.jpg', '2026-09-03T10:04:00Z', '', 'completed', '2026-09-03T01:02:00Z', '2026-09-03T10:04:00Z'),
  ('att-reza-2026-09-04', 'emp-reza', '2026-09-04', 'Proyek Mall Pusat', '2026-09-04T01:03:00Z', -6.1931, 106.8218, 'photos/reza-2026-09-04.jpg', '2026-09-04T10:05:00Z', '', 'completed', '2026-09-04T01:03:00Z', '2026-09-04T10:05:00Z'),
  ('att-reza-2026-09-07', 'emp-reza', '2026-09-07', 'Proyek Mall Pusat', '2026-09-07T01:04:00Z', -6.1931, 106.8218, 'photos/reza-2026-09-07.jpg', '2026-09-07T10:06:00Z', '', 'completed', '2026-09-07T01:04:00Z', '2026-09-07T10:06:00Z'),
  ('att-reza-2026-09-08', 'emp-reza', '2026-09-08', 'Proyek Mall Pusat', '2026-09-08T01:05:00Z', -6.1931, 106.8218, 'photos/reza-2026-09-08.jpg', '2026-09-08T10:07:00Z', '', 'completed', '2026-09-08T01:05:00Z', '2026-09-08T10:07:00Z')
ON CONFLICT (employee_id, date) DO NOTHING;

INSERT INTO overtime (id, employee_id, attendance_id, date, project_name, description, photo, latitude, longitude, start_time, end_time, duration_minutes, rate, amount, status, reviewed_by, reviewed_at) VALUES
  ('ot-andi-2026-09-02', 'emp-andi', 'att-andi-2026-09-02', '2026-09-02', 'Proyek Menara Utara', 'Lembur penyelesaian pekerjaan', 'photos/andi-overtime-2026-09-02.jpg', -6.1754, 106.8272, '2026-09-02T10:15:00Z', '2026-09-02T11:15:00Z', 60, 10000, 10000, 'completed', NULL, NULL),
  ('ot-siti-2026-09-03', 'emp-siti', 'att-siti-2026-09-03', '2026-09-03', 'Proyek Gudang Timur', 'Lembur penyelesaian pekerjaan', 'photos/siti-overtime-2026-09-03.jpg', -6.2297, 106.6894, '2026-09-03T10:15:00Z', '2026-09-03T11:45:00Z', 90, 12500, 18750, 'completed', NULL, NULL),
  ('ot-dimas-2026-09-04', 'emp-dimas', 'att-dimas-2026-09-04', '2026-09-04', 'Proyek Ruko Selatan', 'Lembur penyelesaian pekerjaan', 'photos/dimas-overtime-2026-09-04.jpg', -6.3024, 106.8951, '2026-09-04T10:15:00Z', '2026-09-04T12:15:00Z', 120, 15000, 30000, 'completed', NULL, NULL),
  ('ot-maya-2026-09-07', 'emp-maya', 'att-maya-2026-09-07', '2026-09-07', 'Proyek Apartemen Barat', 'Lembur penyelesaian pekerjaan', 'photos/maya-overtime-2026-09-07.jpg', -6.2019, 106.7816, '2026-09-07T10:15:00Z', '2026-09-07T12:45:00Z', 150, 17500, 43750, 'completed', NULL, NULL),
  ('ot-reza-2026-09-08', 'emp-reza', 'att-reza-2026-09-08', '2026-09-08', 'Proyek Mall Pusat', 'Lembur penyelesaian pekerjaan', 'photos/reza-overtime-2026-09-08.jpg', -6.1931, 106.8218, '2026-09-08T10:15:00Z', '2026-09-08T13:15:00Z', 180, 20000, 60000, 'completed', NULL, NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO leave_requests (id, employee_id, type, start_date, end_date, duration_days, reason, attachment, status) VALUES
  ('leave-siti-2026-09-09', 'emp-siti', 'sick', '2026-09-09', '2026-09-10', 2, 'Sakit demam dan perlu istirahat.', 'attachments/siti-surat-dokter.jpg', 'pending'),
  ('leave-maya-2026-09-11', 'emp-maya', 'personal', '2026-09-11', '2026-09-11', 1, 'Keperluan keluarga mendadak.', NULL, 'pending'),
  ('leave-reza-2026-09-14', 'emp-reza', 'family', '2026-09-14', '2026-09-15', 2, 'Acara keluarga di luar kota.', NULL, 'approved')
ON CONFLICT (id) DO NOTHING;

COMMIT;
