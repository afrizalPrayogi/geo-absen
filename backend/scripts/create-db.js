import pg from "pg";

const { Client } = pg;
const targetUrl = new URL(process.env.DATABASE_URL || "postgres://postgres:postgres@localhost:5432/attendance_payroll");
const databaseName = targetUrl.pathname.replace(/^\//, "") || "attendance_payroll";

const maintenanceUrl = new URL(targetUrl);
maintenanceUrl.pathname = "/postgres";

const client = new Client({ connectionString: maintenanceUrl.toString() });

try {
  await client.connect();
  const exists = await client.query("SELECT 1 FROM pg_database WHERE datname = $1", [databaseName]);
  if (exists.rowCount === 0) {
    await client.query(`CREATE DATABASE ${quoteIdentifier(databaseName)}`);
    console.log(`Database created: ${databaseName}`);
  } else {
    console.log(`Database already exists: ${databaseName}`);
  }
} catch (err) {
  if (err.code === "ECONNREFUSED") {
    console.error("PostgreSQL belum berjalan di host/port DATABASE_URL.");
    console.error(`DATABASE_URL target: ${maskPassword(targetUrl.toString())}`);
    console.error("Jalankan PostgreSQL terlebih dahulu, lalu ulangi: npm run db:create");
    process.exitCode = 1;
  } else {
    throw err;
  }
} finally {
  await client.end().catch(() => {});
}

function quoteIdentifier(value) {
  return `"${String(value).replaceAll('"', '""')}"`;
}

function maskPassword(value) {
  return value.replace(/:\/\/([^:]+):([^@]+)@/, "://$1:***@");
}
