import express from 'express';
import cors from 'cors';
import { env } from './config/env.js';

export const app = express();
app.disable('x-powered-by');
app.use(cors({ origin: env.clientOrigin }));
app.use(express.json({ limit: '100kb' }));

app.get('/api/health', (_req, res) => {
  res.json({ name: 'WASSER', status: 'ok' });
});

app.use((_req, res) => res.status(404).json({ message: 'Route not found' }));
app.use((error, _req, res, _next) => {
  const status = error.status === 400 ? 400 : error.status === 413 ? 413 : 500;
  res.status(status).json({ message: status === 400 ? 'Invalid JSON body' : status === 413 ? 'Request body too large' : 'Internal server error' });
});
