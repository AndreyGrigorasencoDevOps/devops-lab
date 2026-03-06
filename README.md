# devops-lab

Node.js (Express) Task API used as a DevOps learning project.

## Start Here

- Main learning path: [Roadmap](./docs/ROADMAP.md)
- Current operational checklist: [Post-refactor runbook](./docs/post-refactor-runbook.md)

## Current Platform Snapshot (as of March 2026)

- CI is split by event to reduce noise:
  - PR checks: `.github/workflows/ci.yml` (pull_request only)
  - Push checks: `.github/workflows/ci-push.yml` (push to `main` only)
- Sonar is enabled in quality jobs for both PR and push workflows (token-gated and fork-safe).
- CD is manual only via `.github/workflows/cd.yml` (`workflow_dispatch` with `environment`, `action`, `image_tag`).
- Terraform uses one shared root stack (`terraform/`) with:
  - env-specific backend files (`backend/dev.hcl`, `backend/prod.hcl`)
  - env-specific tfvars (`vars/dev.tfvars`, `vars/prod.tfvars`)
- Prod deployment promotes image by digest from DEV ACR to PROD ACR before Terraform apply.

## Documentation Map

- Learning roadmap: [docs/ROADMAP.md](./docs/ROADMAP.md)
- Post-refactor operations: [docs/post-refactor-runbook.md](./docs/post-refactor-runbook.md)
- Terraform usage: [terraform/README.md](./terraform/README.md)
- Cloud architecture: [docs/cloud-architecture.md](./docs/cloud-architecture.md)

## Stack

- Node.js 20
- Express
- PostgreSQL (for readiness/connectivity checks)
- Docker / Docker Compose
- GitHub Actions (CI + CD)
- Terraform (Azure)

## API Overview

- `GET /health`
- `GET /ready`
- `GET /info`
- CRUD endpoints under `/tasks`

## Local Run

```bash
npm install
npm run dev
```

App default URL: `http://localhost:3000`

## Docker Compose

```bash
docker compose up --build
```

## Project Structure

```text
.
+-- src/
+-- test/
+-- scripts/
|   L-- check-post-refactor-prereqs.sh
+-- docs/
|   +-- ROADMAP.md
|   +-- post-refactor-runbook.md
|   +-- cloud-architecture.md
|   +-- azure.md
|   L-- terraform.md
+-- terraform/
|   +-- main.tf
|   +-- variables.tf
|   +-- outputs.tf
|   +-- versions.tf
|   +-- backend/
|   |   +-- dev.hcl
|   |   L-- prod.hcl
|   L-- vars/
|       +-- dev.tfvars
|       L-- prod.tfvars
L-- .github/workflows/
    +-- ci.yml
    +-- ci-push.yml
    L-- cd.yml
```

## CI/CD Model

### CI (PR): `.github/workflows/ci.yml`

Trigger:

- Pull requests to `main`

Jobs:

- Semantic PR title check
- Dependency review
- Lint + tests with coverage + Sonar + npm audit
- Trivy filesystem/config scans
- Docker smoke test (`/health`)
- PR summary

### CI Push: `.github/workflows/ci-push.yml`

Trigger:

- Pushes to `main`

Jobs:

- Lint + tests with coverage + Sonar + npm audit
- Trivy filesystem/config scans
- Docker smoke test (`/health`)
- Build and push immutable image tag `sha-<short_sha>` to DEV ACR
- Push summary with `image_tag`, `image_ref`, `image_digest`

### CD: `.github/workflows/cd.yml`

Trigger:

- Manual `workflow_dispatch` only

Inputs:

- `environment`: `dev | prod`
- `action`: `plan | apply | destroy`
- `image_tag`: required for `plan/apply`, ignored for `destroy`

Behavior:

- Terraform is the deployment engine for both environments.
- For `prod` plan/apply, the workflow promotes the image from DEV ACR to PROD ACR by digest before Terraform.
- `destroy` is available for both `dev` and `prod` (manual use only).

## Terraform Quick Start

See [terraform/README.md](./terraform/README.md) for full usage.

```bash
terraform -chdir=terraform init -backend-config=backend/dev.hcl -reconfigure
terraform -chdir=terraform plan -var-file=vars/dev.tfvars -var="container_image_tag=sha-abc1234"
```

## GitHub and Azure Configuration

### Repository-level Sonar (GitHub repository settings)

- Secret: `SONAR_TOKEN`
- Variables: `SONAR_PROJECT`, `SONAR_ORG`

### GitHub environment variables (`dev` and `prod`)

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ACR_NAME`
- `ACR_LOGIN_SERVER`
- `TF_APP_ENV_VARS_JSON` (optional JSON map)

### Database wiring contract

Terraform provisions PostgreSQL and injects these required runtime variables automatically:

- `DB_HOST`
- `DB_PORT`
- `DB_USER`
- `DB_PASSWORD`
- `DB_NAME`

Use Key Vault for other application secrets that are not provisioned by Terraform.

## Scripts

- `npm start`
- `npm run dev`
- `npm run lint`
- `npm test`
- `npm run test:coverage`
- `./scripts/check-post-refactor-prereqs.sh`
