# Local Development

This repository supports two local development flows:

1. Host-run Node + Docker Postgres
2. Full Docker Compose

macOS is the primary workstation target, but the same flows are kept documented for WSL/Linux as a supported fallback.

## Quick Start

1. Initialize the default Node 20 baseline:

```bash
nvm use
```

CI also validates Node 24. To reproduce the canary path locally, you can optionally run:

```bash
nvm install 24
nvm use 24
```

2. Create local env file:

```bash
cp .env.example .env
```

3. Run the local doctor:

```bash
./scripts/check-local-dev-prereqs.sh
```

## Flow 1: Host Node + Docker Postgres

Use this when you want the best local DX for debugging the Node app on macOS.

1. Start only Postgres:

```bash
docker compose up -d db
```

2. Install dependencies:

```bash
npm ci
```

3. Start the app on the host:

```bash
npm run dev
```

4. Validate:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/ready
```

Notes:

- `.env.example` is host-friendly by default: `DB_HOST=127.0.0.1`.
- If port `5432` is already occupied on your workstation, set both `DB_PORT` and `LOCAL_DB_PORT` in `.env` to the same custom value.

## Flow 2: Full Docker Compose

Use this when you want a container-only local environment closer to CI smoke tests.

```bash
docker compose up --build
```

Validate:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/ready
```

Notes:

- The `api` container always talks to Postgres via `DB_HOST=db`.
- The `db` service is also published to the host via `LOCAL_DB_PORT`, so you can inspect it from local tools if needed.

## WSL to macOS Differences

- Shell startup: WSL users often configured `nvm` in `.bashrc`; on macOS you usually need the equivalent in `.zshrc`.
- Docker runtime: WSL can talk to the Linux daemon directly, while macOS typically relies on Docker Desktop and its socket lifecycle.
- Apple Silicon: ARM64 is supported by the current toolchain, but Homebrew paths and container startup times differ from x86 WSL setups.
- Line endings: macOS and Linux use LF by default; Windows clones often carry CRLF expectations unless git settings are normalized.
- Executable bits: macOS preserves Unix file modes, so scripts can show chmod-only diffs if git filemode settings are noisy.
- CLI auth: `gh` and `az` usually need a fresh login after moving to a new Mac.
- Cursor UI: YAML highlighting or language mode may need re-selection after a fresh editor install.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `client password must be a string` | `.env` was not loaded before DB pool creation, or `DB_PASSWORD` is empty | Recreate `.env`, run `npm ci`, and make sure the app is running with the current repo version |
| `ECONNREFUSED 127.0.0.1:5432` | Postgres is not running on the published host port | Start `docker compose up -d db` and verify `DB_PORT` / `LOCAL_DB_PORT` |
| Docker socket / daemon errors | Docker Desktop is not running on macOS | Start Docker Desktop, then rerun `./scripts/check-local-dev-prereqs.sh` |
| YAML files are pink in Cursor | Wrong language mode or theme tokenization | Set the file language to `YAML`, confirm the Red Hat YAML extension is enabled, and check semantic highlighting |
| `node` / `npm` not found | `nvm` is installed but not initialized in your shell | Add `nvm` init to `.zshrc`, reopen the terminal, then run `nvm use` |

## Cross-platform Tips

- Prefer `npm ci` over `npm install` for deterministic dependency setup.
- Run `./scripts/check-local-dev-prereqs.sh` after switching machines or reinstalling Docker/Desktop tools.
- Keep `.env` local and untracked; only commit `.env.example`.
