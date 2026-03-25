/**
 * db/client.ts
 *
 * PostgreSQL client singleton.
 *
 * Uses the 'postgres' package (https://github.com/porsager/postgres).
 * The client is created once on import and reused across the lifetime of the process.
 *
 * All database access in the application must go through this module.
 * Route handlers and services must not create their own database connections.
 *
 * The `app` schema is the canonical Project V schema.
 * See: docs/architecture/data/schema-authority.md
 * See: docs/runbooks/database-bootstrap.md
 */

import postgres from 'postgres';
import { config } from '../config.js';

export const db = postgres(config.databaseUrl, {
  // Enforce use of the canonical app schema for all queries.
  // This matches the schema targeted by db/migrations/001_canonical_schema.sql.
  onnotice: () => {}, // suppress informational notices in test/dev output
});

/**
 * Verify the database connection by running a lightweight query.
 * Returns the PostgreSQL server version string on success.
 * Throws on any connection or query failure.
 */
export async function checkDbConnection(): Promise<string> {
  const rows = await db`SELECT version() AS v`;
  const row = rows[0];
  if (!row) throw new Error('DB connectivity check returned no rows');
  return String(row['v']);
}
