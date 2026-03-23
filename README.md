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
- PR-only Node 24 Actions canary lives in `.github/workflows/ci-node24-actions-canary.yml`.
- Sonar is enabled in quality jobs for both PR and push workflows (token-gated and fork-safe).
- CD is manual only via `.github/workflows/cd.yml` (`workflow_dispatch` with `environment`, `action`, `image_tag`).
- CD Terraform jobs run on self-hosted runner labels in Azure VNet (`taskapi-cd`, `vnet`).
- Hosted quality checks validate the app on Node 20 and Node 24 while the default local/runtime baseline stays on Node 20.
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

- Node.js 20 default runtime baseline
- Node.js 24 CI validation target
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
    +-- ci-node24-actions-canary.yml
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
- Lint + tests with coverage + Sonar + npm audit on Node 20 and Node 24
- Trivy filesystem/config scans
- Docker smoke tests for `node:20-alpine` and `node:24-alpine`
- PR summary

### CI Push: `.github/workflows/ci-push.yml`

Trigger:

- Pushes to `main`

Jobs:

- Lint + tests with coverage + Sonar + npm audit on Node 20 and Node 24
- Trivy filesystem/config scans
- Docker smoke tests for `node:20-alpine` and `node:24-alpine`
- Build and push immutable image tag `sha-<short_sha>` to DEV ACR
- Push summary with `image_tag`, `image_ref`, `image_digest`

### CD: `.github/workflows/cd.yml`

Trigger:

- Manual `workflow_dispatch` only

Inputs:

- `environment`: `dev | prod`
- `action`: `plan | apply | destroy`
- `image_tag`: required for `plan/apply`, ignored for `destroy`
- `bootstrap_mode`: opt-in first-apply bootstrap for Terraform-managed env prerequisites
- `actions_node24_canary`: opt-in Node 24 JavaScript Actions canary for a manual CD run

Behavior:

- Terraform is the deployment engine for both environments.
- For `prod` plan/apply, the workflow promotes the image from DEV ACR to PROD ACR by digest before Terraform.
- Terraform `plan` and `apply` jobs run on self-hosted runner labels: `self-hosted`, `linux`, `x64`, `taskapi-cd`, `vnet`.
- Preflight security check is mandatory before `plan/apply`.
- `destroy` is available for both `dev` and `prod` (manual use only).
- `destroy` runs as a GitHub-hosted break-glass path and temporarily allowlists the runner public IP on Key Vault during the teardown window.
- Normal release flow is `plan` then `apply` (reconciliation).
- `destroy` is full state teardown for the selected environment, not selective cleanup.

### Node24 Actions Canary: `.github/workflows/ci-node24-actions-canary.yml`

Trigger:

- Pull requests to `main`

Behavior:

- Forces JavaScript-based GitHub Actions onto Node 24 with `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true`.
- Mirrors the riskiest PR checks (semantic PR title, dependency review, quality, Trivy, Docker smoke) without changing the default push/CD path.
- Exists to surface upstream action compatibility early before GitHub's Node 24 runner default becomes mandatory.

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
  - Required only for the hosted runner-prep step that queries repository self-hosted runners while booting the shared Azure runner VM.
  - Use a fine-grained PAT with repository `Administration: Read`.

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

When running `./scripts/check-post-refactor-prereqs.sh` manually, export `ARM_CLIENT_ID` or `AZURE_CLIENT_ID` first so the deploy-identity Key Vault RBAC check is enforced.
