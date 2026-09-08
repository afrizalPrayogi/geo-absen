BEGIN;

CREATE TABLE IF NOT EXISTS app_users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('employee', 'admin')),
  employee_id TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS employees (
  id TEXT PRIMARY KEY,
  user_id TEXT UNIQUE REFERENCES app_users(id),
  employee_code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'app_users_employee_id_fkey'
  ) THEN
    ALTER TABLE app_users
      ADD CONSTRAINT app_users_employee_id_fkey
      FOREIGN KEY (employee_id) REFERENCES employees(id) DEFERRABLE INITIALLY DEFERRED;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS salary_rates (
  id TEXT PRIMARY KEY,
  employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  daily_rate INTEGER NOT NULL CHECK (daily_rate > 0),
  overtime_rate INTEGER NOT NULL CHECK (overtime_rate > 0),
  effective_date DATE NOT NULL,
  effective_until DATE,
  updated_by TEXT REFERENCES app_users(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS salary_rates_employee_effective_idx ON salary_rates(employee_id, effective_date DESC);

CREATE TABLE IF NOT EXISTS attendance (
  id TEXT PRIMARY KEY,
  employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  project_name TEXT NOT NULL,
  check_in_time TIMESTAMPTZ NOT NULL,
  check_in_latitude NUMERIC(10, 6) NOT NULL,
  check_in_longitude NUMERIC(10, 6) NOT NULL,
  check_in_photo TEXT NOT NULL,
  check_out_time TIMESTAMPTZ,
  notes TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL CHECK (status IN ('running', 'completed', 'corrected', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(employee_id, date)
);

CREATE INDEX IF NOT EXISTS attendance_date_idx ON attendance(date);
CREATE INDEX IF NOT EXISTS attendance_employee_date_idx ON attendance(employee_id, date DESC);

CREATE TABLE IF NOT EXISTS overtime (
  id TEXT PRIMARY KEY,
  employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  attendance_id TEXT NOT NULL REFERENCES attendance(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  project_name TEXT NOT NULL,
  description TEXT NOT NULL,
  photo TEXT NOT NULL,
  latitude NUMERIC(10, 6) NOT NULL,
  longitude NUMERIC(10, 6) NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  duration_minutes INTEGER NOT NULL DEFAULT 0 CHECK (duration_minutes >= 0),
  rate INTEGER NOT NULL CHECK (rate > 0),
  amount INTEGER NOT NULL DEFAULT 0 CHECK (amount >= 0),
  status TEXT NOT NULL CHECK (status IN ('running', 'completed', 'approved', 'corrected', 'rejected')),
  reviewed_by TEXT REFERENCES app_users(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS overtime_employee_date_idx ON overtime(employee_id, date DESC);
CREATE INDEX IF NOT EXISTS overtime_status_idx ON overtime(status);

CREATE TABLE IF NOT EXISTS cashbon_transactions (
  id TEXT PRIMARY KEY,
  employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  transaction_date DATE NOT NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'approved',
  created_by TEXT NOT NULL REFERENCES app_users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payrolls (
  id TEXT PRIMARY KEY,
  employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  employee_name TEXT NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  working_days INTEGER NOT NULL DEFAULT 0 CHECK (working_days >= 0),
  daily_rate_snapshot INTEGER NOT NULL CHECK (daily_rate_snapshot > 0),
  overtime_rate_snapshot INTEGER NOT NULL CHECK (overtime_rate_snapshot > 0),
  overtime_minutes INTEGER NOT NULL DEFAULT 0 CHECK (overtime_minutes >= 0),
  normal_salary INTEGER NOT NULL DEFAULT 0 CHECK (normal_salary >= 0),
  overtime_amount INTEGER NOT NULL DEFAULT 0 CHECK (overtime_amount >= 0),
  cashbon_balance INTEGER NOT NULL DEFAULT 0 CHECK (cashbon_balance >= 0),
  cashbon_deduction INTEGER NOT NULL DEFAULT 0 CHECK (cashbon_deduction >= 0),
  net_salary INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('draft', 'reviewed', 'published', 'paid')),
  published_at TIMESTAMPTZ,
  published_by TEXT REFERENCES app_users(id),
  paid_at TIMESTAMPTZ,
  paid_by TEXT REFERENCES app_users(id),
  payment_note TEXT,
  payment_reference TEXT,
  created_by TEXT NOT NULL REFERENCES app_users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(employee_id, period_start, period_end)
);

CREATE INDEX IF NOT EXISTS payrolls_period_idx ON payrolls(period_start, period_end);

CREATE TABLE IF NOT EXISTS cashbon_deductions (
  id TEXT PRIMARY KEY,
  cashbon_id TEXT NOT NULL REFERENCES cashbon_transactions(id) ON DELETE CASCADE,
  employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  payroll_id TEXT REFERENCES payrolls(id) ON DELETE SET NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  created_by TEXT NOT NULL REFERENCES app_users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payslips (
  id TEXT PRIMARY KEY,
  payroll_id TEXT NOT NULL UNIQUE REFERENCES payrolls(id) ON DELETE CASCADE,
  employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  issued_by TEXT NOT NULL REFERENCES app_users(id)
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES app_users(id),
  module TEXT NOT NULL,
  record_id TEXT NOT NULL,
  action TEXT NOT NULL,
  old_value JSONB,
  new_value JSONB,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMIT;
