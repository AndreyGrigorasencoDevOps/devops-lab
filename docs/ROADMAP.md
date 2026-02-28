Roadmap — Platform Evolution Plan (Detailed)

This project evolves from a simple Node.js API into a production-style DevOps platform.

The goal is to simulate a real-world service lifecycle:
design → containerize → test → build → push → deploy → scale → secure → observe.

Principles:

- Everything goes through branches + PRs (no direct pushes to main).
- Each stage ends with a working, verifiable outcome.
- Prefer OIDC/Managed Identity over long-lived secrets.

---

## Stage 1 — Quality & Testing (Foundation)

Objective: enforce production-grade quality gates.

- [x] ESLint (strict, flat config)
- [x] PR checks (lint + tests)
- [x] HTTP integration tests (supertest)
- [x] Test coverage reporting
- [x] Conventional commits enforcement

Outcome:
Reliable CI that blocks low-quality code before merge.

---

## Stage 2 — Container CI (Build Artifacts)

Objective: treat Docker image as a release artifact.

- [x] Build Docker image in GitHub Actions
- [x] Push image to GHCR (sha + main tags)
- [x] Semantic versioning (vX.Y.Z)
- [x] Multi-environment tagging (dev/prod)
- [x] Smoke test in CI (container boots + /health)
- [x] Security scan in CI (Trivy fs + config)
- [x] CI Postgres service for smoke (CI-only credentials)

Outcome:
Every merge to main produces a versioned container image with quality + security gates.

---

## Stage 3 — Cloud Deployment (Azure) — Fast Path

Objective: deploy containerized service to Azure quickly (prove cloud deployment end-to-end).

### 3.1 Azure prep

- [x] Create Azure subscription setup notes (resource naming, region, budget alert)
- [x] Create a Resource Group for the project (manual is OK for Stage 3 fast path)
- [x] Decide environment naming: dev = main branch deployments, prod = release tag deployments

### 3.2 Azure Container Registry (ACR)

- [x] Create ACR (SKU: Basic)
- [x] Enable admin user: OFF (avoid username/password)
- [x] Confirm ACR login server name (e.g. xxx.azurecr.io)

### 3.3 Container Apps (initial target)

- [x] Create Container Apps Environment (Log Analytics workspace auto-created or explicit)
- [x] Create task-api-dev Container App (initial deployment can be from GHCR just to validate platform)
- [x] Configure ingress (external), target port = app port (e.g. 3000)
- [x] Configure environment variables for app: NODE_ENV=production, DB settings (temporary, dev only), LOG_LEVEL=info
- [x] Verify endpoints: /health returns 200, basic API endpoint returns expected response

### 3.4 CI deploy to Azure (dev)

- [x] Add GitHub Actions workflow step: Azure login via OIDC (no secrets)
- [x] Push image to ACR from GitHub Actions (main branch only)
- [x] Update Container App image to the new ACR image (main branch only)
- [x] Validate “merge to main → ACR image → Container App updated”

### 3.5 Managed identity / secure registry access

- [x] Configure Container App identity (system-assigned)
- [x] Grant identity AcrPull role on ACR
- [x] Ensure Container App pulls from ACR without credentials

Outcome:
Cloud-hosted API running on Azure Container Apps, updated from CI-built image, with secure registry access.

---

## Stage 4 — Infrastructure as Code (Terraform) — Foundation

Objective: provision Azure infrastructure programmatically (reproducible setup).

### 4.1 Terraform project structure

- [ ] Create terraform/ layout: terraform/README.md, terraform/environments/dev/, terraform/environments/prod/, terraform/modules/ (optional later)
- [ ] Add .gitignore for .terraform/, *.tfstate*

### 4.2 Remote Terraform state (Azure Storage)

- [ ] Create Storage Account + Container for remote state
- [ ] Configure Terraform backend (azurerm) for dev
- [ ] Repeat/parameterize for prod
- [ ] Document “how to init/apply” in terraform/README.md

### 4.3 Core resources (IaC)

- [ ] Resource Group
- [ ] Azure Container Registry (ACR)
- [ ] Container Apps Environment (+ Log Analytics)
- [ ] (Optional now / required later) VNet + Subnet baseline: VNet, Subnet; decide if needed for Container Apps now; keep for AKS stage

### 4.4 Outputs + naming

- [ ] Output ACR login server
- [ ] Output Container App name(s) / FQDN
- [ ] Standardize tags (owner, env, project)

Outcome:
Azure infrastructure for dev/prod can be recreated reliably via Terraform with remote state.

---

## Stage 5 — CI/CD to Azure (ACR + Container Apps) — Production-Style

Objective: make cloud deployment fully automated and environment-aware.

### 5.1 CI: image promotion rules

- [ ] Define tagging rules: main → deploy to dev, vX.Y.Z tag → deploy to prod
- [ ] Ensure GHCR remains “build artifact history” (optional), but ACR becomes “deployment source”

### 5.2 GitHub Actions: Azure auth (OIDC)

- [ ] Create Azure App Registration / Federated Credential for GitHub OIDC
- [ ] Assign minimum roles required (ACR push + Container Apps update)
- [ ] Remove any legacy Azure secrets if used

### 5.3 Deploy logic

- [ ] main pipeline: Build → security → smoke → push to ACR → update task-api-dev
- [ ] tag vX.Y.Z pipeline: Build → security → smoke → push to ACR → update task-api-prod
- [ ] Add “deployment summary” step (print URLs, image tags)

Outcome:
Hands-off deployments: main updates dev, release tags update prod, using OIDC + managed identity.

---

## Stage 6 — Python Service (Company Stack Alignment)

Objective: align with Python-based backend stack and introduce a second service safely.

### 6.1 Add FastAPI microservice

- [ ] Create python-service/ (FastAPI skeleton)
- [ ] Add /health endpoint
- [ ] Add one simple “compute” endpoint (e.g. /v1/score) to demonstrate real work
- [ ] Add minimal tests (pytest)

### 6.2 Dockerize Python service

- [ ] Add python-service/Dockerfile (non-root, small image)
- [ ] Add .dockerignore

### 6.3 docker-compose: run Node + Python locally

- [ ] Extend docker-compose.yml: Node API, Python service, Postgres
- [ ] Add service discovery (Node calls Python by service name)
- [ ] Document local run instructions

### 6.4 CI job for Python (lint + tests)

- [ ] Add Python linting (ruff/flake8) + formatting
- [ ] Add pytest in CI
- [ ] Add coverage for python-service

### 6.5 Inter-service communication (Node → Python)

- [ ] Add a Node endpoint that calls Python service
- [ ] Add integration test verifying Node↔Python flow
- [ ] Add retries/timeouts for HTTP calls
- [ ] Add basic error handling + logs

Outcome:
Multi-service architecture (Node + Python) with local compose + CI gates.

---

## Stage 7 — Kubernetes (AKS)

Objective: move from single-container deployment to orchestration (real platform skills).

### 7.1 Kubernetes manifests (baseline)

- [ ] Create k8s/ folder: deployment.yaml, service.yaml
- [ ] Deployment for Node API
- [ ] Service (ClusterIP)

### 7.2 Probes

- [ ] Readiness probe (/health)
- [ ] Liveness probe (/health or dedicated /live)

### 7.3 Resource limits & requests

- [ ] Define CPU/memory requests
- [ ] Define CPU/memory limits

### 7.4 Ingress controller

- [ ] Install/define ingress (NGINX or AGIC later)
- [ ] Ingress resource routing to service

### 7.5 Horizontal Pod Autoscaler (HPA)

- [ ] Enable metrics server (if needed)
- [ ] Add HPA based on CPU utilization

Outcome:
Production-style container orchestration with scaling, routing, and health management.

---

## Stage 8 — Infrastructure as Code (Terraform) — AKS Expansion

Objective: provision Kubernetes infrastructure cleanly (AKS + networking).

This stage extends Stage 4 Terraform to cover AKS.

- [ ] VNet + Subnet (AKS-ready)
- [ ] Network decisions documented: kubenet vs Azure CNI (choose one, explain why)
- [ ] Azure Kubernetes Service (AKS)
- [ ] Attach ACR to AKS (AcrPull)
- [ ] Remote Terraform state already in place (reuse)

Outcome:
AKS infrastructure fully reproducible and integrated with ACR and networking.

---

## Stage 9 — Security & Identity (Azure Entra ID)

Objective: enterprise-grade identity integration.

- [ ] Azure Entra ID integration (AKS/Apps depending on target)
- [ ] Service-to-service authentication: managed identity where possible, token-based auth between services (if required)
- [ ] Secret management strategy: Azure Key Vault plan, Kubernetes Secrets baseline (then move to CSI driver)
- [ ] RBAC configuration: principle of least privilege, separate roles for CI vs humans vs runtime

Outcome:
Enterprise-ready authentication, authorization, and secrets strategy.

---

## Stage 10 — Observability & Production Thinking

Objective: simulate real production environment concerns.

### 10.1 Structured logs in cloud

- [ ] Ensure JSON logs (already in app) are viewable in Azure logs
- [ ] Add correlation id (request id) middleware
- [ ] Log redaction rules (no secrets)

### 10.2 Health metrics

- [ ] Add /metrics endpoint (optional now; Prometheus later)
- [ ] Track basic counters (requests, errors, latency)

### 10.3 Monitoring

- [ ] Azure Monitor / Log Analytics dashboards
- [ ] Alerts: CPU high, restarts/crashes, 5xx rate, latency threshold

### 10.4 Failure simulation & recovery testing

- [ ] Simulate DB down (expected behavior documented)
- [ ] Simulate app crash loop (observe restart behavior)
- [ ] Simulate slow dependency (timeouts, retries)

### 10.5 Rolling updates strategy

- [ ] Rolling update settings validated
- [ ] Can deploy without downtime (prove with logs)

Outcome:
Operationally resilient service with monitoring, alerting, and controlled releases.