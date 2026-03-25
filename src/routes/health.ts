/**
 * routes/health.ts
 *
 * Minimal health and readiness routes.
 *
 * GET /health
 *   Returns 200 if the server is alive.
 *   Returns the current version and environment.
 *
 * GET /health/db
 *   Returns 200 if the database is reachable.
 *   Returns the PostgreSQL version string on success.
 *   Returns 503 with an error body if the database is unreachable.
 *
 * These routes do not require project context and are not project-scoped.
 * They exist only to verify the scaffold is wired correctly.
 */

import type { FastifyInstance } from 'fastify';
import { checkDbConnection } from '../db/client.js';

export async function healthRoutes(app: FastifyInstance): Promise<void> {
  app.get('/health', async (_req, reply) => {
    return reply.send({
      status: 'ok',
      service: 'project-v',
      env: process.env['NODE_ENV'] ?? 'development',
    });
  });

  app.get('/health/db', async (_req, reply) => {
    try {
      const version = await checkDbConnection();
      return reply.send({ status: 'ok', db: version });
    } catch (err) {
      return reply.status(503).send({
        error: {
          code: 'DB_UNREACHABLE',
          message: 'Database connectivity check failed',
          details: err instanceof Error ? err.message : String(err),
        },
      });
    }
  });
}
