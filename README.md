# WASSER

Society Water Tanker & Supply Billing Management System — university DBMS project.
This repository currently contains initial setup only: one placeholder screen, an API health endpoint, and MySQL connection configuration. Feature pages, business APIs, charts, and application tables are intentionally deferred.

## Requirements

- Node.js 24 LTS and npm (Node 22.12+ is supported).
- MySQL 8, running locally or on a reachable server.
- On Windows PowerShell, use `npm.cmd` if execution policy blocks `npm.ps1`. No policy change is needed. The commands below use `npm`; substituting `npm.cmd` is equivalent.

## Install

Run from this existing Wasser directory; do not initialize another Git repository:

```sh
npm install
```

The root package uses npm workspaces, so this installs both client and server dependencies. Commit the generated root `package-lock.json` when you choose to commit; subsequent reproducible installs can use `npm ci`.

Create your local configuration in PowerShell:

```powershell
Copy-Item server/.env.example server/.env
Copy-Item client/.env.example client/.env
```

Edit `server/.env` with your local database user and password. The examples contain no credentials. Never commit `.env` files; all `VITE_` values are public browser configuration.

## Database initialization

Open MySQL 8 as an administrator, then run the SQL script using an absolute path (forward slashes work in the MySQL client):

```sql
SOURCE C:/path/to/Wasser/database/001_create_database.sql;
```

Provision a local application user named `wasser_app` using MySQL administration tools and a password of your choice. Grant it privileges on `wasser.*` appropriate to your local development work. Keep that password in `server/.env`, never in tracked SQL. This setup creates only the database; tables and seed data come later.

```sh
npm run db:check
```

This explicitly checks credentials, connection, selected database, and MySQL 8 version. HTTP startup does not connect to MySQL; a healthy API alone does not prove database connectivity.

## Run locally

Terminal 1, from the repository root:

```sh
npm run dev:server
```

Terminal 2, from the repository root:

```sh
npm run dev:client
```

- Frontend: http://localhost:5173
- API health: http://localhost:5000/api/health
- Expected health JSON: `{"name":"WASSER","status":"ok"}`

Vite forwards `/api` requests to port 5000. If you change the backend port, update `client/vite.config.js` too. `CLIENT_ORIGIN` controls the backend's allowed browser origin. `VITE_API_BASE_URL` is provided for future API calls; the placeholder does not make requests yet.

## Checks and build

```sh
npm run check
npm run build
npm run start
```

`check` validates backend JavaScript syntax and builds the frontend. `build` alone creates `client/dist/`. `start` runs the API without watch mode; it does not serve the frontend. To inspect the production frontend bundle locally, run `npm run preview --workspace client`. The Vite development proxy applies only to development; a production deployment will need its own API routing configuration.

## Files and folders

See [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md) for the purpose of every scaffold file and folder. React and Recharts are client dependencies; Express, CORS, dotenv, and `mysql2/promise` are backend dependencies. Tailwind uses its Vite plugin, so a separate Tailwind or PostCSS config is unnecessary.

Setup references: [Vite guide](https://vite.dev/guide/) and [Tailwind Vite installation](https://tailwindcss.com/docs/installation/using-vite).
