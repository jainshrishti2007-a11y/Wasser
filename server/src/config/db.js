import mysql from 'mysql2/promise';
import { env } from './env.js';

// Connections are opened lazily. The HTTP health endpoint does not require MySQL.
export const pool = mysql.createPool({
  ...env.db,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  connectTimeout: 5000,
  decimalNumbers: false,
});
