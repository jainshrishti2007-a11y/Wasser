import { app } from './app.js';
import { env } from './config/env.js';
import { pool } from './config/db.js';

const server = app.listen(env.port, () => {
  console.log(`WASSER API listening on http://localhost:${env.port}`);
});
server.on('error', (error) => {
  console.error(`WASSER API could not start (${error.code || 'unknown error'}).`);
  process.exitCode = 1;
});

function shutdown() {
  server.close(async () => {
    await pool.end();
  });
}
process.once('SIGINT', shutdown);
process.once('SIGTERM', shutdown);
