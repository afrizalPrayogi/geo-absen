import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";

const { Pool } = pg;
const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");
const connectionString = process.env.DATABASE_URL || "postgres://postgres:postgres@localhost:5432/attendance_payroll";

const pool = new Pool({ connectionString });

try {
  const schema = await readFile(join(root, "db", "schema.sql"), "utf8");
  const seed = await readFile(join(root, "db", "seed.sql"), "utf8");
  await pool.query(schema);
  await pool.query(seed);
  console.log("Database schema and seed applied.");
} catch (err) {
  if (err.code === "ECONNREFUSED") {
    console.error("PostgreSQL belum berjalan di host/port DATABASE_URL.");
    console.error(`DATABASE_URL target: ${connectionString.replace(/:\/\/([^:]+):([^@]+)@/, "://$1:***@")}`);
    console.error("Jalankan PostgreSQL dan npm run db:create terlebih dahulu, lalu ulangi: npm run db:init");
    process.exitCode = 1;
  } else {
    throw err;
  }
} finally {
  await pool.end();
}
