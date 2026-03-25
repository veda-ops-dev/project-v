/**
 * scripts/db-migrate.ts
 *
 * Stateless migration runner.
 *
 * Reads SQL files from db/migrations/ and executes them in filename order.
 * Does NOT track applied migrations. Does NOT create any DB schema or tables.
 *
 * Authority: docs/runbooks/database-bootstrap.md
 *            docs/architecture/data/schema-governance.md
 *
 * Preflight safety check:
 *   If core tables exist, migrations are assumed applied. Exit 0.
 *   Detects partial schema and fails early.
 *
 * Usage:
 *   npm run db:migrate
 *
 * Required environment:
 *   DATABASE_URL=postgresql://project_v_app:projectv@localhost:5432/project_v_local
 */

import 'dotenv/config';
import postgres from 'postgres';
import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const MIGRATIONS_DIR = path.resolve(__dirname, '../db/migrations');

const databaseUrl = process.env['DATABASE_URL'];
if (!databaseUrl) {
  console.error('ERROR: DATABASE_URL is not set');
  process.exit(1);
}

const db = postgres(databaseUrl);

async function preflightCheck(): Promise<'fresh' | 'applied' | 'partial'> {
  const rows = await db<{ project: string | null; objective: string | null }[]>`
    SELECT
      to_regclass('app.project') AS project,
      to_regclass('app.objective') AS objective
  `;

  const projectExists = rows[0]?.project !== null;
  const objectiveExists = rows[0]?.objective !== null;

  if (projectExists && objectiveExists) return 'applied';
  if (!projectExists && !objectiveExists) return 'fresh';

  return 'partial';
}

async function run(): Promise<void> {
  console.log('project-v db:migrate');
  console.log('  migrations dir:', MIGRATIONS_DIR);

  const state = await preflightCheck();

  if (state === 'applied') {
    console.log('Migration appears already applied (core tables exist)');
    await db.end();
    process.exit(0);
  }

  if (state === 'partial') {
    console.error('ERROR: Partial schema detected.');
    console.error('       Some core tables exist but not all.');
    console.error('       Resolve manually before running migrations.');
    await db.end();
    process.exit(1);
  }

  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  if (files.length === 0) {
    console.log('  no migration files found');
    await db.end();
    return;
  }

  for (const filename of files) {
    const filePath = path.join(MIGRATIONS_DIR, filename);
    const sql = fs.readFileSync(filePath, 'utf8');

    console.log(`  applying: ${filename}`);
    await db.unsafe(sql);
    console.log(`  applied:  ${filename}`);
  }

  console.log(`  ${files.length} migration file(s) executed`);

  await db.end();
}

run().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
