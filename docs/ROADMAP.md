# Roadmap - Platform Evolution Plan

This roadmap is the source of truth for platform status and the learning path for a junior DevOps target.

## How To Use This Roadmap

- Follow the 8-week speedrun first (top-down execution order).
- Use Stage 0-10 as the long-term platform map and progress tracker.
- Treat each completed week/stage as portfolio evidence:
  - workflow run links
  - infra plan/apply outputs
  - short write-up of decisions and tradeoffs

## 8-Week Speedrun (Balanced Track)

| Week | Focus | Practical Artifact | Interview Checkpoint |
| --- | --- | --- | --- |
| 1 | CI foundations and code quality | Stable PR pipeline (`ci.yml`) with lint, tests, coverage, Sonar, dependency review | Explain branch protection and why PR-only checks exist |
| 2 | Container quality gates | Trivy + smoke-tested image build flow | Explain shift-left security and smoke test purpose |
| 3 | Azure identity and auth | OIDC-based GitHub -> Azure auth for dev/prod environments | Explain OIDC vs long-lived secrets |
| 4 | Terraform core stack | Reproducible infra (`terraform/` root stack) for dev/prod | Explain backend state, tfvars, and drift risks |
| 5 | Delivery workflow | Manual CD (`cd.yml`) with plan/apply/destroy and input validation | Explain safe deploy flow with plan before apply |
| 6 | Promotion model and release safety | PROD digest promotion from DEV ACR + verification | Explain tag vs digest and supply-chain integrity |
| 7 | Secrets and operational readiness | Key Vault contract + prereq checks + runbook execution | Explain secret ownership and runtime access model |
| 8 | Production simulation and portfolio hardening | End-to-end demo runbook + incident drill notes | Walk through "commit -> CI -> image -> CD -> health checks" |

---

## Stage 0 - From Scratch Product Build

Objective: capture the full origin story before DevOps hardening phases.

- [x] Bootstrapped project repository from zero
- [x] Implemented Node.js/Express Task API from scratch
- [x] Defined health/readiness/info endpoint contract
- [x] Added local runtime flow (`npm run dev`) and env contract (`.env.example`)
- [x] Added local containerized flow (`Dockerfile`, `docker-compose.yml`)
- [x] Added baseline tests and lint before cloud delivery phases

Outcome:
The product foundation was built manually end-to-end before CI/CD and cloud maturity stages.

---

## Stage 1 - Quality and Testing (Foundation)

Objective: enforce reliable quality gates before merge.

- [x] ESLint strict setup (flat config)
- [x] PR quality checks on `main`
- [x] Unit + integration tests (`node:test`, `supertest`)
- [x] Coverage reports (`c8` + `lcov`)
- [x] Conventional PR title validation
- [x] Dependency review on pull requests
- [x] Sonar analysis in CI (token-gated and fork-safe)

Outcome:
PRs are blocked on quality and security baseline checks.

---

## Stage 2 - Container CI and Artifact Quality

Objective: treat container images as verified release artifacts.

- [x] Build Docker image in GitHub Actions
- [x] Immutable image tag pattern (`sha-<short_sha>`)
- [x] Trivy filesystem and config scans
- [x] Docker smoke test against `/health`
- [x] Build and push to DEV ACR on push to `main`
- [x] Verify pushed image digest in ACR
- [x] CI summary with image tag/ref/digest for CD handoff
- [x] Deprecated old GHCR deploy-source flow (ACR is deployment source)

Outcome:
Each push to `main` produces a validated image and deployment metadata.

---

## Stage 3 - Azure Runtime Platform (Container Apps)

Objective: run the service in Azure with secure identity-based access.

- [x] Azure Container Apps target selected and running
- [x] Container Apps Environment and Log Analytics baseline
- [x] Managed identity on Container App
- [x] `AcrPull` role assignment for runtime identity
- [x] Key Vault integration pattern introduced
- [x] `Key Vault Secrets User` role assignment for runtime identity
- [x] Health endpoints used as deployment/runtime checks

Outcome:
Application runs on Azure Container Apps with managed identity and role-based access.

---

## Stage 4 - Terraform Foundation (Reproducible Infra)

Objective: provision and evolve infra from code, not manual clicks.

- [x] Single Terraform root stack (`terraform/`)
- [x] Remote backend split by environment (`backend/dev.hcl`, `backend/prod.hcl`)
- [x] Environment tfvars split (`vars/dev.tfvars`, `vars/prod.tfvars`)
- [x] Core resources managed in Terraform:
  - Resource Group
  - ACR
  - PostgreSQL Flexible Server + application database
  - Container App
  - Log Analytics Workspace
  - Shared-or-dedicated CAE model
  - Shared-or-dedicated Key Vault model
- [x] Infra outputs for deployment and visibility
- [x] Standardized tags by project/environment
- [x] Deprecated old `terraform/environments/*` stack layout
- [ ] Optional modules refactor for larger scale reuse (recommended after Stage 9 Phase 3 stabilization)

Outcome:
Dev/prod infrastructure is reproducible and versioned with Terraform.

---

## Stage 5 - Delivery Workflow (CI/CD + Promotion)

Objective: make deployments predictable, auditable, and environment-aware.

- [x] CI split to reduce skipped-job noise:
  - PR workflow: `.github/workflows/ci.yml`
  - Push workflow: `.github/workflows/ci-push.yml`
- [x] Manual CD workflow (`.github/workflows/cd.yml`) with:
  - `environment` input (`dev|prod`)
  - `action` input (`plan|apply|destroy`)
  - `image_tag` validation for plan/apply
- [x] Terraform-driven deploy path for dev and prod
- [x] PROD digest promotion from DEV ACR before Terraform plan/apply
- [x] CD summary for execution context and selected backend/tfvars
- [x] Post-refactor runbook + prereq checker script added
- [x] State adoption step for existing Container App in CD apply path
- [x] Phase 1 Key Vault stabilization mode in CD/Terraform (`public_allow`)
- [x] Transitional KV bootstrap in CD when existing vault firewall is still `Deny`
- [x] RBAC propagation wait before Container App revision updates
- [x] Deprecated old tag-driven direct prod deployment flow
- [x] Phase 2 status: Terraform CD jobs moved to self-hosted runner in VNet with mandatory preflight gate
- [x] On-demand shared runner flow in CD (hosted boot -> self-hosted Terraform -> hosted deallocate)
- [x] Environment protection rules review (required reviewers, prod safeguards)
- [x] Policy decision recorded: keep `prod destroy` path (manual, explicit reset only)

Outcome:
Deployments are controlled, traceable, and safer across environments.

---

## Stage 6 - Python Service (Stack Expansion)

Objective: add a second service to practice multi-service operations.

- [ ] Create `python-service/` (FastAPI)
- [ ] Add `/health` and one business endpoint
- [ ] Add pytest + coverage
- [ ] Dockerize Python service
- [ ] Extend compose to run Node + Python + Postgres
- [ ] Add CI checks for Python (lint/test)
- [ ] Add Node -> Python integration path with retries/timeouts

Outcome:
Multi-service architecture with service-to-service communication and CI quality gates.

---

## Stage 7 - Kubernetes Runtime (AKS)

Objective: learn orchestration and deployment control beyond single app runtime.

- [ ] Add Kubernetes manifests (`k8s/`)
- [ ] Configure liveness/readiness probes
- [ ] Define requests/limits
- [ ] Add ingress routing
- [ ] Add autoscaling baseline (HPA)

Outcome:
Service becomes operable in Kubernetes with health and scaling controls.

---

## Stage 8 - Terraform Expansion for AKS

Objective: manage Kubernetes infrastructure through Terraform.

- [ ] Add VNet/Subnet baseline for AKS
- [ ] Provision AKS via Terraform
- [ ] Attach ACR pull permissions to AKS identity
- [ ] Document network model decision (kubenet vs Azure CNI)

Outcome:
AKS platform is reproducible through Terraform with explicit network/security decisions.

---

## Stage 9 - Security and Identity Maturity

Objective: move from baseline security to production-grade identity model.

- [x] OIDC authentication from GitHub Actions to Azure
- [x] Managed identity + RBAC pattern for runtime services
- [x] Key Vault integration baseline introduced
- [x] Phase 1 secret-resolution stabilization documented (`RBAC-only + public allow`)
- [x] Phase 2 migration to private runner-path Key Vault access + self-hosted runner in VNet
- [x] Secret rotation runbook and ownership model
- [x] Access review cadence for CI/runtime/human identities
- [x] Add stronger policy checks (least privilege verification)
- [x] Phase 2 operating mode was active with pragmatic runtime compatibility (`key_vault_network_mode = public_allow` before paid normalization)
- [x] Phase 2 operational status in `dev` (strict preflight + runner online + successful apply)
- [x] Phase 2 operational status in `prod` (strict preflight + successful CD `plan` -> `apply`)
- [ ] Phase 3 paid normalization rollout (dedicated CAE per env + runtime VNet + `firewall` mode)

Current rollout status (repo target state, Azure convergence pending):

- Terraform now targets dedicated CAEs for both `dev` and `prod` with env-local runtime VNets and env-local Key Vault private endpoints.
- Terraform tfvars now target `key_vault_network_mode = firewall` with `bypass = None`; Azure must still be converged in the rollout order from the runbook.
- Shared runner location now targets `uksouth` on `Standard_F1als_v7`; the first recreate/register still needs a trusted local shell or break-glass path because CD depends on that runner.
- The temporary Trivy exception remains in repo config during the rollout window; remove it only after Azure is converged to the new Key Vault posture and Trivy stays green without it.

Post-paid normalization track:

- [ ] Create dedicated CAE for `dev` and `prod` (or finalize a different model only if platform constraints materially change)
- [ ] Complete CAE VNet migration and validate private runtime access for both environments
- [ ] Return Key Vault network mode to `firewall` (`default_action = Deny`) and remove the Trivy exception
- [ ] Relocate shared runner platform from `eastus` back to `uksouth` and validate CD stability
- [ ] Add cost controls: budget alerts, runner schedule/patch cadence, and periodic VM right-sizing review

Outcome:
Identity and secret management become auditable and operationally maintainable.

---

## Stage 10 - Observability and Operations

Objective: build production-thinking habits (monitoring, resilience, incident response).

- [x] Structured application logs in app code (Pino)
- [ ] Cloud log dashboards for key signals
- [ ] Alert rules for health, errors, and saturation
- [ ] Basic incident drills (DB down, dependency timeout, bad deploy)
- [ ] Post-incident notes template and recovery checklist

Outcome:
Service reliability is measured and failures are handled with repeatable process.

---

## Junior Readiness Exit Criteria (2-Month Target)

You are "junior-ready" for this stack when you can consistently do the following:

- [ ] Explain and operate both CI workflows (PR and push) and when each should fail.
- [ ] Run CD safely (`plan` before `apply`) and recover from a failed deploy.
- [ ] Trace one image from commit SHA to running environment by digest.
- [ ] Manage Terraform backend/tfvars per environment without state confusion.
- [x] Validate Key Vault + RBAC prerequisites before deployment.
- [ ] Demonstrate one end-to-end release in a short screen-share:
  - commit -> PR checks -> merge -> CI Push artifact -> CD apply -> health checks
- [ ] Provide portfolio evidence:
  - links to successful workflow runs
  - sample Terraform plan/apply outputs
  - short incident/recovery notes
