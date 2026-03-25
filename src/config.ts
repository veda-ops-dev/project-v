/**
 * config.ts
 *
 * Loads and validates environment configuration.
 * All runtime settings are sourced here; no other module reads process.env directly.
 *
 * Required env vars:
 *   DATABASE_URL - PostgreSQL connection string
 *
 * Optional env vars with defaults:
 *   PORT     - HTTP listen port (default 3100)
 *   HOST     - HTTP listen host (default 127.0.0.1)
 *   NODE_ENV - runtime environment (default development)
 */

import 'dotenv/config';

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const config = {
  databaseUrl: requireEnv('DATABASE_URL'),
  port: parseInt(process.env['PORT'] ?? '3100', 10),
  host: process.env['HOST'] ?? '127.0.0.1',
  nodeEnv: process.env['NODE_ENV'] ?? 'development',
} as const;

export type Config = typeof config;
