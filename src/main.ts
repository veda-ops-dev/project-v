/**
 * main.ts
 *
 * Application entrypoint.
 * Loads configuration, builds the app, verifies DB connectivity, and starts listening.
 */

import { config } from './config.js';
import { buildApp } from './app.js';
import { checkDbConnection } from './db/client.js';

async function main() {
  const app = await buildApp();

  // Verify database connectivity before accepting traffic.
  try {
    const dbVersion = await checkDbConnection();
    app.log.info({ dbVersion }, 'Database connection verified');
  } catch (err) {
    app.log.error({ err }, 'Database connectivity check failed on startup');
    process.exit(1);
  }

  await app.listen({ port: config.port, host: config.host });
  app.log.info(`project-v running on ${config.host}:${config.port}`);
}

main().catch((err) => {
  console.error('Fatal startup error:', err);
  process.exit(1);
});
