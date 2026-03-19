# devops-lab

Node.js (Express) Task API used as a DevOps learning project.

## Start Here

- Main learning path: [Roadmap](./docs/ROADMAP.md)
- Revision system: [Revision runbook](./docs/revision/revision-runbook.md)
- Current operational baseline: [Security operations](./docs/security-operations.md)

## Current Platform Snapshot (as of March 2026)

- CI is split by event to reduce noise:
  - PR checks: `.github/workflows/ci.yml` (pull_request only)
  - Push checks: `.github/workflows/ci-push.yml` (push to `main` only)
- Sonar is enabled in quality jobs for both PR and push workflows (token-gated and fork-safe).
- CD is manual only via `.github/workflows/cd.yml` (`workflow_dispatch` with `environment`, `action`, `image_tag`).
- CD Terraform jobs run on self-hosted runner labels in Azure VNet (`taskapi-cd`, `vnet`).
- Terraform uses one shared root stack (`terraform/`) with:
  - env-specific backend files (`backend/dev.hcl`, `backend/prod.hcl`)
  - env-specific tfvars (`vars/dev.tfvars`, `vars/prod.tfvars`)
  - a shared-ops sub-root (`terraform/shared-ops/`) for the subscription budget
- Paid-normalization repo target is active: dedicated CAE per env, runtime VNets, Key Vault firewall mode, and a Terraform-managed subscription budget.
- Prod deployment promotes image by digest from DEV ACR to PROD ACR before Terraform apply.

## Documentation Map

- Learning roadmap: [docs/ROADMAP.md](./docs/ROADMAP.md)
- Revision runbook and assessments: [docs/revision/revision-runbook.md](./docs/revision/revision-runbook.md)
- Local development: [docs/local-development.md](./docs/local-development.md)
- Archived paid-normalization rollout: [docs/current-rollout-runbook.md](./docs/current-rollout-runbook.md)
- Archived post-refactor reference: [docs/post-refactor-runbook.md](./docs/post-refactor-runbook.md)
- Archived Phase 2 cutover: [docs/phase2-cutover-next-steps.md](./docs/phase2-cutover-next-steps.md)
- Legacy archive note: [docs/archive/terraform-environments-legacy.md](./docs/archive/terraform-environments-legacy.md)
- Security operations: [docs/security-operations.md](./docs/security-operations.md)
- Terraform usage: [terraform/README.md](./terraform/README.md)
- Shared ops Terraform: [terraform/shared-ops/README.md](./terraform/shared-ops/README.md)
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

Preferred onboarding:

```bash
nvm use
cp .env.example .env
./scripts/check-local-dev-prereqs.sh
```

### Host Node + Docker Postgres

```bash
docker compose up -d db
npm ci
npm run dev
```

App default URL: `http://localhost:3000`

### Full Docker Compose

```bash
docker compose up --build
```

See [docs/local-development.md](./docs/local-development.md) for the full macOS + WSL local runbook, troubleshooting, and migration notes.

## Project Structure

```text
.
+-- src/
+-- test/
+-- scripts/
|   L-- check-post-refactor-prereqs.sh
+-- docs/
|   +-- ROADMAP.md
|   +-- current-rollout-runbook.md
|   +-- post-refactor-runbook.md
|   +-- phase2-cutover-next-steps.md
|   +-- archive/
|   |   L-- terraform-environments-legacy.md
|   +-- security-operations.md
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
|   +-- shared-ops/
|   |   +-- main.tf
|   |   +-- variables.tf
|   |   +-- outputs.tf
|   |   +-- versions.tf
|   |   +-- backend/
|   |   |   L-- shared.hcl
|   |   L-- vars/
|   |       L-- shared.tfvars
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
- Terraform jobs run on self-hosted runner labels: `self-hosted`, `linux`, `x64`, `taskapi-cd`, `vnet`.
- Preflight security check is mandatory before `plan/apply`.
- `destroy` is available for both `dev` and `prod` (manual use only).
- Normal release flow is `plan` then `apply` (reconciliation).
- `destroy` is full state teardown for the selected environment, not selective cleanup.

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

### Repository-level GitHub Actions secrets

- `GH_RUNNER_ADMIN_TOKEN`
  - Required for CD to query repository self-hosted runners while booting the shared Azure runner VM.
  - Use a fine-grained PAT or GitHub App token with repository `Administration: Read`.

### GitHub environment variables (`dev` and `prod`)

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ACR_NAME`
- `ACR_LOGIN_SERVER`
- `TF_APP_ENV_VARS_JSON` (optional JSON map)
- `TF_SHARED_RUNNER_ADMIN_SSH_PUBLIC_KEY` (required for shared runner VM create/update)

### Database wiring contract

Terraform provisions PostgreSQL and configures Container App to load all DB variables from Key Vault secret references:

- `DB_HOST`
- `DB_PORT`
- `DB_USER`
- `DB_PASSWORD`
- `DB_NAME`

Secret ownership model:

- Manually managed in dedicated env Key Vault: `<env>-db-password` (`dev-db-password`, `prod-db-password`)
- Terraform-managed in dedicated env Key Vault: `<env>-db-host`, `<env>-db-port`, `<env>-db-user`, `<env>-db-name`

The Terraform deploy identity must have `Key Vault Secrets Officer` on the Key Vault scope.

## Scripts

- `npm start`
- `npm run dev`
- `npm run lint`
- `npm test`
- `npm run test:coverage`
- `./scripts/check-local-dev-prereqs.sh`
- `./scripts/check-post-refactor-prereqs.sh`
