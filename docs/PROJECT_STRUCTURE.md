# Project structure

| Path | Purpose |
| --- | --- |
| `client/` | React frontend workspace. |
| `client/package.json` | Frontend dependencies and Vite development, build, and preview scripts. Recharts is installed for future charts. |
| `client/.env.example` | Public API base URL template; no secrets belong here. |
| `client/index.html` | Browser document, WASSER title, and React mount element. |
| `client/vite.config.js` | React and Tailwind plugins, fixed frontend port, and local API proxy. |
| `client/src/` | Frontend source code. |
| `client/src/main.jsx` | React entry point and global stylesheet import. |
| `client/src/App.jsx` | Single WASSER setup placeholder, without feature pages. |
| `client/src/index.css` | Tailwind import and minimal global styles. |
| `server/` | Express backend workspace. |
| `server/package.json` | Backend dependencies, development/start scripts, syntax checks, and database check command. |
| `server/.env.example` | Server port, browser origin, and MySQL connection template with a blank password. |
| `server/src/` | Backend application source. |
| `server/src/app.js` | Express configuration, CORS, JSON parsing, health route, and JSON errors. |
| `server/src/index.js` | HTTP listener, startup errors, and shutdown handling. |
| `server/src/config/` | Backend configuration modules. |
| `server/src/config/env.js` | Loads server-local environment settings and validates port numbers. |
| `server/src/config/db.js` | Lazy MySQL connection pool using `mysql2/promise`. |
| `server/scripts/` | Backend maintenance/check commands. |
| `server/scripts/check-db.js` | Explicit MySQL 8 connectivity check; does not print passwords. |
| `database/` | Versioned SQL scripts; no application schema yet. |
| `database/001_create_database.sql` | Creates the empty `wasser` database with MySQL 8 Unicode collation. |
| `docs/` | Project documentation. |
| `docs/PROJECT_STRUCTURE.md` | This inventory of scaffold files and folders. |
| `package.json` | Private root workspace definition and commands for both applications. |
| `package-lock.json` | npm-generated dependency versions for reproducible workspace installs. |
| `.gitignore` | Excludes dependencies, build output, local environment files, logs, and editor metadata; permits `.env.example`. |
| `README.md` | Installation, configuration, database setup, commands, and scope. |

Generated `node_modules/` directories contain installed dependencies. Generated `client/dist/` contains the frontend build. Both are ignored by Git. Optional local `client/.env` and `server/.env` are user-specific configuration and ignored. The existing `.git/` directory is retained without reinitialization.
