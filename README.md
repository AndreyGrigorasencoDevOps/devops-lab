# devops-lab

Node.js (Express) Task API used as a DevOps playground.

## Stack

- Node.js 20
- Express
- PostgreSQL (for readiness/connectivity checks)
- Docker / Docker Compose
- GitHub Actions (CI + CD)
- Terraform (Azure)

## API overview

- `GET /health`
- `GET /ready`
- `GET /info`
- CRUD endpoints under `/tasks`

## Local run

```bash
npm install
npm run dev
```

App default URL: `http://localhost:3000`

## Docker Compose

```bash
docker compose up --build
```

## Project structure

```text
.
+-- src/
+-- test/
+-- terraform/
¦   +-- main.tf
¦   +-- variables.tf
¦   +-- outputs.tf
¦   +-- versions.tf
¦   +-- backend/
¦   ¦   +-- dev.hcl
¦   ¦   L-- prod.hcl
¦   L-- vars/
¦       +-- dev.tfvars
¦       L-- prod.tfvars
L-- .github/workflows/
    +-- ci.yml
    L-- cd.yml
```

## CI/CD model

### CI (`.github/workflows/ci.yml`)

Triggers:

- Pull requests to `main`
- Pushes to `main`

Jobs:

- Semantic PR title (PR only)
- Dependency review (PR only)
- Lint + tests + coverage + npm audit
- Trivy filesystem/config scans
- Docker smoke test (`/health`)
- Build and push immutable image tag `sha-<short_sha>` to DEV ACR (push to `main` only)

### CD (`.github/workflows/cd.yml`)

Trigger:

- Manual `workflow_dispatch` only

Inputs:

- `environment`: `dev | prod`
- `action`: `plan | apply | destroy`
- `image_tag`: required for `plan/apply`, ignored for `destroy`

Behavior:

- Terraform is the deployment engine for dev/prod.
- For `prod` + (`plan` or `apply`), image is promoted from DEV ACR to PROD ACR by digest before Terraform.
- `destroy` is allowed for both environments.

## Terraform usage

See [terraform/README.md](./terraform/README.md) for full commands.

Quick examples:

```bash
terraform -chdir=terraform init -backend-config=backend/dev.hcl -reconfigure
terraform -chdir=terraform plan -var-file=vars/dev.tfvars -var="container_image_tag=sha-abc1234"
```

## GitHub environment variables and secrets

Configure both `dev` and `prod` environments in GitHub:

Variables:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ACR_NAME`
- `ACR_LOGIN_SERVER`
- `TF_APP_ENV_VARS_JSON` (optional JSON map)

Secrets:

- `TF_APP_SECRETS_JSON` (optional JSON map)

## Scripts

- `npm start`
- `npm run dev`
- `npm run lint`
- `npm test`
- `npm run test:coverage`
