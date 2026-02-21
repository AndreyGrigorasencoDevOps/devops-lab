# devops-lab

A small **Node.js (Express)** API that provides a **tasks CRUD** and system endpoints. It’s used as a playground for **DevOps practices**: Docker, environment-based config, PostgreSQL, health/readiness checks, and CI (GitHub Actions).
See [Roadmap](./ROADMAP.md) for the platform evolution plan.

---

## What it does

- **REST API** for tasks: list, get by id, create, update, delete. Task data is kept **in-memory** (no persistence across restarts). A PostgreSQL database is used for **connectivity checks** and readiness; the DB schema includes a `tasks` table for future persistence.
- **Operational endpoints**: liveness (`/health`), readiness (`/ready` — checks DB), and basic info (`/info`).
- **Structured logging** (Pino), HTTP request logging, centralized error handling, and **graceful shutdown** (closes HTTP server and DB pool on SIGTERM/SIGINT).
- **Docker**: multi-stage image (Node 20 Alpine, non-root user) and **docker-compose** with API + Postgres, healthchecks, and `depends_on` with DB healthy condition.
- **CI**: GitHub Actions runs on pull requests to `main` — lint and tests.

---

## Features

| Area | Details |
|------|--------|
| **API** | Express, JSON body, CRUD for tasks (in-memory) |
| **Config** | Env vars: `PORT`, `SERVICE_NAME`, `LOG_LEVEL`, `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` |
| **Database** | PostgreSQL 15 (Compose); used for readiness and init (schema); app uses in-memory store for tasks |
| **Logging** | Pino + pino-http; `LOG_LEVEL`; pino-pretty in non-production |
| **Docker** | Multi-stage Dockerfile, docker-compose (api + db), healthchecks |
| **CI** | PR checks: `npm ci`, `npm run lint`, `npm test` |
| **Code quality** | ESLint (flat config), Node built-in test runner |

---

## Requirements

- **Node.js 20+** (for local run and scripts)
- **Docker** and **Docker Compose** (recommended for full stack)
- For Compose: set `DB_USER` and `DB_PASSWORD` (see [Run with Docker Compose](#run-with-docker-compose))

---

## Project structure

```
.
├── src/
│   ├── server.js           # Entry: DB init, start server, graceful shutdown
│   ├── app.js              # Express app, routes, middlewares
│   ├── config/
│   │   └── db.js           # pg Pool and connection events
│   ├── db/
│   │   └── init.js         # Create tasks table (retry on failure)
│   ├── routes/
│   │   └── tasks.routes.js # GET/POST /tasks, GET/PATCH/DELETE /tasks/:id
│   ├── controllers/
│   │   └── tasks.controller.js
│   ├── services/
│   │   ├── tasks.service.js      # In-memory task store
│   │   └── readiness.service.js # DB check for /ready
│   ├── middlewares/
│   │   ├── httpLogger.js   # pino-http
│   │   └── errorHandler.js
│   └── utils/
│       ├── logger.js       # Pino instance
│       └── retry.js        # Async retry for DB init
├── test/
│   └── smoke.test.js       # Node test runner
├── .github/workflows/
│   └── pr-checks.yml       # Lint + tests on PR to main
├── Dockerfile              # Multi-stage, node:20-alpine
├── docker-compose.yml      # api + postgres, healthchecks
├── .env.example
├── eslint.config.js
└── package.json
```

---

## Run locally

1. **Install dependencies**

   ```bash
   npm install
   ```

2. **Environment**

   Copy `.env.example` to `.env` and set at least:

   - `PORT`, `SERVICE_NAME`, `LOG_LEVEL` for the API.
   - For readiness/DB init you need a running Postgres and `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` (e.g. local Postgres or a Compose-only `db` with host `localhost` and port `5432`).

   ```bash
   cp .env.example .env
   # Edit .env with your DB credentials if you want /ready and full startup
   ```

3. **Start (dev)**

   ```bash
   npm run dev
   ```

   API base: **http://localhost:3000** (or your `PORT`).

---

## Run with Docker Compose

Runs the API and PostgreSQL with healthchecks and `depends_on` so the API waits for the DB to be healthy.

1. **Environment**

   Create a `.env` (from `.env.example`) and set **required** variables:

   - `DB_USER`
   - `DB_PASSWORD`

   Optional: `DB_NAME` (default `tasksdb`), `IMAGE_TAG` (default `dev`).

2. **Build and run**

   ```bash
   docker compose up --build
   ```

   API: **http://localhost:3000**. DB is on port 5432 (internal to Compose; map in `docker-compose.yml` if you need external access).

---

## Run API container only (no Compose)

If you already have a Postgres instance:

1. **Build**

   ```bash
   docker build -t task-api:1.0 .
   ```

2. **Run**

   ```bash
   docker run --rm -p 3000:3000 \
     --env-file .env \
     -e DB_HOST=host.docker.internal \
     --name node-api \
     task-api:1.0
   ```

   Adjust `DB_HOST` (and optionally other `DB_*` vars) for your Postgres.

---

## API endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Liveness: `{ status: 'ok', service }` |
| GET | `/ready` | Readiness: checks DB; 200 or 503 |
| GET | `/info` | Service name, port, Node version, uptime |
| GET | `/tasks` | List all tasks |
| GET | `/tasks/:id` | Get task by id (positive integer) |
| POST | `/tasks` | Create task; body: `{ "title": "string" }` |
| PATCH | `/tasks/:id` | Update task; body: `{ "title"?, "completed"? }` |
| DELETE | `/tasks/:id` | Delete task by id |

---

## Scripts

| Command | Description |
|--------|-------------|
| `npm start` | Run production server: `node src/server.js` |
| `npm run dev` | Run with nodemon |
| `npm run lint` | ESLint (full, max-warnings 0) |
| `npm run lint:quick` | ESLint on `src` only |
| `npm test` | Run tests with Node built-in test runner |

---

## CI (GitHub Actions)

- **Workflow**: `.github/workflows/pr-checks.yml`
- **Trigger**: Pull requests targeting `main`
- **Steps**: Checkout → Setup Node 20 (npm cache) → `npm ci` → `npm run lint` → `npm test`

---

## Environment variables (reference)

| Variable | Description | Default / note |
|----------|-------------|----------------|
| `PORT` | HTTP port | `3000` |
| `SERVICE_NAME` | Service name in responses/logs | `node-api` |
| `LOG_LEVEL` | Pino log level | `info` |
| `NODE_ENV` | Environment | Set to `production` in Docker |
| `DB_HOST` | PostgreSQL host | Required for DB features |
| `DB_PORT` | PostgreSQL port | `5432` |
| `DB_USER` | PostgreSQL user | Required in Compose |
| `DB_PASSWORD` | PostgreSQL password | Required in Compose |
| `DB_NAME` | PostgreSQL database name | `tasksdb` |

---

## License

See repository for license information.
