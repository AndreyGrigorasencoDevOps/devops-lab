# devops-lab

A small Node.js (Express) CRUD API used as a playground for DevOps practices: Docker, environment-based config, and later CI/CD + IaC.

## Features

- Express API
- CRUD endpoints (in-memory for now)
- Config via environment variables (`PORT`, `SERVICE_NAME`, `LOG_LEVEL`)
- Dockerized

## Requirements

- Node.js 18+ (if running locally)
- Docker (recommended)

## Project structure

```
.
├── src/
├── Dockerfile
├── .dockerignore
├── .gitignore
├── .env.example
├── package.json
└── package-lock.json
```

## Run locally

1. Install dependencies:

   ```bash
   npm install
   ```

2. Create your local env file:

   ```bash
   cp .env.example .env
   ```

3. Start (dev):

   ```bash
   npm run dev
   ```

API will be available at **http://localhost:3000**

## Run with Docker

1. Build image:

   ```bash
   docker build -t node-api:1.0 .
   ```

2. Run container:

   ```bash
   docker run --rm -p 3000:3000 \
     --env-file .env \
     --name node-api \
     node-api:1.0
   ```

## Example endpoints

| Method | Path     |
|--------|----------|
| GET    | /health  |
| GET    | /info    |
| GET    | /tasks   |

