// Small mysql-client DELIMITER-aware runner for the three reviewed Phase 2 files.
import { readFile } from 'node:fs/promises';
import { pool } from '../src/config/db.js';

const file = process.argv[2];
const resume = process.argv[3] === '--resume';
const allowed = ['schema.sql', 'seed.sql', 'queries.sql'];
let connection;
try {
  if (!allowed.includes(file)) throw new Error(`Usage: node server/scripts/run-sql.js <${allowed.join('|')}>`);
  const source = await readFile(new URL(`../../database/${file}`, import.meta.url), 'utf8');
  connection = await pool.getConnection();
  if (file === 'schema.sql' && !resume) {
    const [objects] = await connection.query('SHOW FULL TABLES');
    const [routines] = await connection.query('SELECT ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE()');
    if (objects.length || routines.length) throw new Error('Schema installation requires an empty database. Existing objects were preserved.');
  }
  if (file === 'seed.sql') {
    const [[{ n: triggers }]] = await connection.query('SELECT COUNT(*) AS n FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE()');
    const [[{ n: routines }]] = await connection.query('SELECT COUNT(*) AS n FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE()');
    if (triggers !== 22 || routines !== 2) throw new Error('Complete schema installation first: expected 22 triggers and 2 procedures. No seed data was inserted.');
    const [rows] = await connection.query("SELECT COUNT(*) AS n FROM Society WHERE name LIKE 'WASSER Demo - %'");
    if (rows[0].n) throw new Error('Demo societies already exist; seed was not rerun.');
  }
  let delimiter = ';';
  let buffer = '';
  let count = 0;
  for (const line of source.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('--')) continue;
    if (/^DELIMITER\s+/i.test(trimmed)) {
      delimiter = trimmed.split(/\s+/)[1];
      continue;
    }
    buffer += `${line}\n`;
    if (trimmed.endsWith(delimiter)) {
      const sql = buffer.trimEnd().slice(0, -delimiter.length);
      if (file === 'schema.sql' && resume) {
        const match = /^CREATE (TABLE|VIEW|TRIGGER|PROCEDURE)\s+`?(\w+)`?/i.exec(sql);
        if (match) {
          const [, kind, name] = match;
          const catalog = kind === 'TRIGGER' ? ['TRIGGERS', 'TRIGGER_NAME', 'TRIGGER_SCHEMA']
            : kind === 'PROCEDURE' ? ['ROUTINES', 'ROUTINE_NAME', 'ROUTINE_SCHEMA']
              : ['TABLES', 'TABLE_NAME', 'TABLE_SCHEMA'];
          const [existing] = await connection.query(
            `SELECT 1 FROM information_schema.${catalog[0]} WHERE ${catalog[2]}=DATABASE() AND LOWER(${catalog[1]})=LOWER(?)`, [name]);
          if (existing.length) {
            console.log(`Preserved existing ${kind.toLowerCase()} ${name}.`);
            buffer = '';
            continue;
          }
        }
      }
      const [result] = await connection.query(sql);
      count++;
      if (file === 'queries.sql' && Array.isArray(result)) console.table(result);
      buffer = '';
    }
  }
  if (buffer.trim()) throw new Error('Unterminated SQL statement');
  console.log(`${file}: ${count} statements executed successfully.`);
} catch (error) {
  if (connection) await connection.rollback();
  console.error(`${file || 'SQL runner'} failed (${error.code || 'validation'}): ${error.sqlMessage || error.message}`);
  console.error('Stopped at the first error. MySQL DDL and earlier committed seed sections cannot be rolled back; inspect before retrying.');
  process.exitCode = 1;
} finally {
  connection?.release();
  await pool.end();
}
