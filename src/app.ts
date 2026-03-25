/**
 * app.ts
 *
 * Fastify application factory.
 *
 * Registers plugins and route families.
 * Returns a configured Fastify instance ready for listen() or injection-testing.
 *
 * Keep this file as a thin wiring layer.
 * Business logic belongs in services and enforcement helpers.
 */

import Fastify from 'fastify';
import sensible from '@fastify/sensible';
import { healthRoutes } from './routes/health.js';
import { projectRoutes } from './routes/projects.js';

export async function buildApp() {
  const app = Fastify({
    logger: {
      level: process.env['NODE_ENV'] === 'production' ? 'info' : 'debug',
    },
  });

  // -- Core plugins
  await app.register(sensible);

  // -- Routes
  await app.register(healthRoutes);
  await app.register(projectRoutes);

  return app;
}
