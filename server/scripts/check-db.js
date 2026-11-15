import { env } from '../src/config/env.js';
import { pool } from '../src/config/db.js';

try {
  if (!env.db.user || !env.db.password) {
    throw Object.assign(new Error('Set DB_USER and DB_PASSWORD in server/.env before checking MySQL.'), { code: 'DB_CONFIG_MISSING' });
  }
  const [rows] = await pool.query('SELECT VERSION() AS version, DATABASE() AS database_name');
  if (!/^8\./.test(rows[0].version)) {
    throw Object.assign(new Error('This project requires MySQL 8.'), { code: 'DB_VERSION_UNSUPPORTED' });
  }
  console.log(`MySQL ${rows[0].version}: connected to ${rows[0].database_name}`);
} catch (error) {
  console.error(`Database check failed (${error.code || 'unknown error'}). Check MySQL 8 and server/.env.`);
  process.exitCode = 1;
} finally {
  await pool.end();
}
