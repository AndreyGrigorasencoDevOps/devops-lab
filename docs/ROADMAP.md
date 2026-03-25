# Roadmap - Junior-Ready Platform Path

This roadmap is the source of truth for platform status and the recommended learning path for a junior DevOps target on the current stack.

## Status Snapshot

- Core platform foundations are complete through Stage 7.
- Current recommended focus: Stage 8, then Stage 9.
- Current runtime and delivery baseline: Node 24 across local development, Docker, CI, and CD.
- Stages 10 and 11 are later expansion tracks and are not required for junior readiness on the current Azure Container Apps + Terraform + GitHub Actions stack.
- Treat each completed stage as both learning evidence and portfolio evidence.
- Companion study system: [Revision runbook](./revision/revision-runbook.md)

## How To Use This Roadmap

- Follow the stages in numerical order.
- Treat each completed stage as portfolio evidence:
  - workflow run links
  - Terraform plan/apply outputs
  - short notes on decisions, tradeoffs, failures, and recoveries
- Use the checklists to track both implementation progress and explanation readiness.
- Revisit earlier stages when later work exposes a concept you still cannot explain clearly.
- Use the stage tests and final exam in [`docs/revision/`](./revision/revision-runbook.md) to turn the roadmap into a repeatable revision loop.

## Recommended 8-10 Week Execution Plan

| Window | Focus | Target stages | Primary artifact |
| --- | --- | --- | --- |
| Weeks 1-2 | Product baseline and CI foundations | Stages 1-2 | Working service, local runbook, stable PR checks |
| Weeks 3-4 | Container delivery, Azure runtime, and Terraform baseline | Stages 3-5 | Reproducible platform with validated image flow |
| Weeks 5-6 | Delivery workflow and secure operations | Stages 6-7 | Manual gated CD, OIDC, Key Vault/RBAC, private access path |
| Weeks 7-8 | Observability, incident response, and release readiness | Stage 8 | Dashboards, alerts, drills, recovery notes |
| Weeks 9-10 | Junior readiness and portfolio proof | Stage 9 | End-to-end release demo, evidence pack, explain-back |
| Later expansion | Multi-service and Kubernetes/AKS practice | Stages 10-11 | Python service and orchestration experience |

---

## Stage 1 - Product Build and Local Runtime

Objective:
Establish the service baseline and local developer workflow before adding automation and cloud complexity.

Why it matters:
You troubleshoot DevOps systems more effectively when you understand the application contract, local runtime, and basic failure modes end to end.

Checklist:

- [x] Bootstrap the project repository from zero
- [x] Implement the Node.js/Express Task API from scratch
- [x] Define `/health`, `/ready`, and `/info` endpoint contracts
- [x] Add a local runtime flow (`npm run dev`) and env contract (`.env.example`)
- [x] Add a local containerized flow (`Dockerfile`, `docker-compose.yml`)
- [x] Add baseline tests and lint before cloud delivery phases

Outcome:
The product foundation exists with clear runtime and health contracts.

Portfolio / Interview checkpoint:
Walk through the local run flows and explain why the service exposes separate liveness, readiness, and info endpoints.

---

## Stage 2 - Quality Gates and CI Foundations

Objective:
Enforce reliable merge-time checks before artifact build and deployment.

Why it matters:
Strong CI foundations reduce broken mainline changes and create a safe base for later delivery automation.

Checklist:

- [x] Enforce ESLint with a strict flat config
- [x] Protect `main` with pull-request quality checks
- [x] Add unit and integration tests (`node:test`, `supertest`)
- [x] Publish coverage reports (`c8` + `lcov`)
- [x] Validate conventional pull-request titles
- [x] Run dependency review on pull requests
- [x] Run Sonar analysis in CI (token-gated and fork-safe)

Outcome:
Pull requests are blocked on a quality and security baseline before merge.

Portfolio / Interview checkpoint:
Explain branch protection, why PR-only checks exist, and what should fail before code reaches `main`.

---

## Stage 3 - Container Artifact Delivery

Objective:
Treat the container image as a validated release artifact rather than a byproduct of the build.

Why it matters:
A trustworthy image pipeline creates the handoff point between CI, security checks, and deployment.

Checklist:

- [x] Build the Docker image in GitHub Actions
- [x] Use immutable image tags (`sha-<short_sha>`)
- [x] Run Trivy filesystem and config scans
- [x] Run a Docker smoke test against `/health`
- [x] Build and push images to DEV ACR on push to `main`
- [x] Verify pushed image digests in ACR
- [x] Publish a CI summary with image tag, image ref, and digest for CD handoff
- [x] Retire the old GHCR deployment-source flow

Outcome:
Each push to `main` produces a validated image plus the metadata needed for controlled deployment.

Portfolio / Interview checkpoint:
Explain shift-left security, why smoke tests belong in CI, and why immutable tags matter.

---

## Stage 4 - Azure Runtime Platform

Objective:
Run the service in Azure using an identity-based runtime model.

Why it matters:
A real platform target makes the delivery pipeline and operational model meaningful.

Checklist:

- [x] Select Azure Container Apps as the runtime target and get the service running
- [x] Establish the Container Apps Environment and Log Analytics baseline
- [x] Attach a managed identity to the Container App
- [x] Grant `AcrPull` to the runtime identity
- [x] Introduce the Key Vault integration pattern
- [x] Grant `Key Vault Secrets User` to the runtime identity
- [x] Use health endpoints as deployment and runtime checks

Outcome:
The application runs on Azure Container Apps with managed identity and role-based access.

Portfolio / Interview checkpoint:
Explain why Container Apps fits this stage, how managed identity replaces app secrets, and how readiness checks protect deployments.

---

## Stage 5 - Terraform Foundation

Objective:
Provision and evolve the platform from code instead of manual portal changes.

Why it matters:
Environment separation, repeatability, and drift visibility are core infrastructure skills for junior DevOps work.

Checklist:

- [x] Consolidate infrastructure into a single Terraform root stack (`terraform/`)
- [x] Split remote backends by environment (`backend/dev.hcl`, `backend/prod.hcl`)
- [x] Split environment tfvars (`vars/dev.tfvars`, `vars/prod.tfvars`)
- [x] Manage the core platform resources in Terraform:
  - Resource Group
  - ACR
  - PostgreSQL Flexible Server + application database
  - Container App
  - Log Analytics Workspace
  - Shared-or-dedicated CAE model
  - Shared-or-dedicated Key Vault model
- [x] Publish infrastructure outputs for deployment and visibility
- [x] Standardize tags by project and environment
- [x] Retire the old `terraform/environments/*` stack layout
- [ ] Optionally refactor into modules for larger-scale reuse after the core platform path is stable

Outcome:
Dev and prod infrastructure are reproducible, versioned, and environment-aware.

Portfolio / Interview checkpoint:
Explain backend state, tfvars, environment separation, and the main drift risks in a shared cloud subscription.

---

## Stage 6 - Delivery Workflow

Objective:
Make deployments predictable, auditable, and environment-aware.

Why it matters:
Delivery maturity is where quality checks, artifact trust, runtime configuration, and operator safety start working together.

Checklist:

- [x] Split CI by event to reduce skipped-job noise:
  - PR workflow: `.github/workflows/ci.yml`
  - Push workflow: `.github/workflows/ci-push.yml`
- [x] Provide a manual CD workflow (`.github/workflows/cd.yml`) with validated `environment`, `action`, and `image_tag` inputs
- [x] Make Terraform the deployment engine for both `dev` and `prod`
- [x] Promote PROD images from DEV ACR by digest before Terraform plan/apply
- [x] Publish CD summaries with execution context and selected backend/tfvars
- [x] Add a post-refactor runbook and prerequisite checker script
- [x] Adopt existing Container App state during CD apply when needed
- [x] Support Phase 1 Key Vault stabilization mode in CD/Terraform (`public_allow`)
- [x] Add transitional Key Vault bootstrap handling when an existing vault still has firewall `Deny`
- [x] Add an RBAC propagation wait before Container App revision updates
- [x] Retire the old tag-driven direct production deployment flow
- [x] Move Terraform CD jobs to a self-hosted runner in the VNet with a mandatory preflight gate
- [x] Implement an on-demand shared runner flow in CD (hosted boot -> self-hosted Terraform -> hosted deallocate)
- [x] Review environment protection rules, required reviewers, and production safeguards
- [x] Keep a manual `prod destroy` path as an explicit reset-only policy decision

Outcome:
Deployments are controlled, traceable, and safer across environments.

Portfolio / Interview checkpoint:
Explain why the safe release path is `plan` before `apply`, why prod promotion uses digests instead of tags, and why the runner path lives inside the network boundary.

---

## Stage 7 - Identity, Secrets, and Secure Operations

Objective:
Move from baseline secret usage to an auditable identity and network posture.

Why it matters:
This stage turns the platform from “working” into “operationally defensible.”

Checklist:

- [x] Authenticate GitHub Actions to Azure with OIDC
- [x] Use managed identity + RBAC for runtime services
- [x] Establish the Key Vault integration baseline
- [x] Document Phase 1 secret-resolution stabilization (`RBAC-only + public allow`)
- [x] Migrate to private runner-path Key Vault access plus a self-hosted runner in the VNet
- [x] Define a secret rotation runbook and ownership model
- [x] Define an access review cadence for CI, runtime, and human identities
- [x] Add stronger policy checks for least-privilege verification
- [x] Operate Phase 2 successfully with pragmatic runtime compatibility (`key_vault_network_mode = public_allow` before paid normalization)
- [x] Validate Phase 2 in `dev` with strict preflight, runner online, and successful apply
- [x] Validate Phase 2 in `prod` with strict preflight and successful CD `plan` -> `apply`
- [x] Complete Phase 3 paid normalization (dedicated CAE per env + runtime VNet + `firewall` mode)
- [x] Create dedicated CAEs for `dev` and `prod` (or formally keep a different model only if platform constraints materially change)
- [x] Complete CAE VNet migration and validate private runtime access for both environments
- [x] Restore Key Vault network mode to `firewall` (`default_action = Deny`) and remove the temporary Trivy exception
- [x] Relocate the shared runner platform from `eastus` back to `uksouth` and validate CD stability
- [x] Add baseline cost controls with a subscription budget plus on-demand runner boot/deallocate flow

Outcome:
Identity and secret management are auditable and operationally maintainable. The current steady-state baseline is dedicated CAEs per environment, env-local runtime VNets and Key Vault private endpoints, Key Vault `firewall` mode with `bypass = None`, and an on-demand shared runner in `uksouth`.

Portfolio / Interview checkpoint:
Explain OIDC vs long-lived secrets, secret ownership boundaries, why private Key Vault access matters, and how the current steady-state posture differs from the earlier stabilization phases.

---

## Stage 8 - Observability, Incident Response, and Release Readiness

Objective:
Build production-thinking habits around signals, alerts, incident handling, and recovery.

Why it matters:
Being able to detect, explain, and recover from failure is what makes a platform job-ready instead of just deployable.

Checklist:

- [x] Add structured application logs in app code (Pino)
- [ ] Build cloud log dashboards for availability, errors, latency, and saturation
- [ ] Configure alert rules for health, errors, and saturation, and validate at least one alert path end to end
- [ ] Run incident drills for DB outage, dependency timeout, bad deploy, and one failed-deploy or rollback recovery
- [ ] Create a post-incident notes template and recovery checklist

Outcome:
Service reliability is measured, alerts are actionable, and failure handling becomes repeatable.

Portfolio / Interview checkpoint:
Walk through one alert, one failure drill, and the recovery steps you would follow before, during, and after an incident.

---

## Stage 9 - Junior Readiness and Portfolio Evidence

Objective:
Prove you can explain, operate, and present the platform as junior-level delivery evidence.

Why it matters:
Hiring readiness depends on explanation quality and operational proof, not only on how many technologies you touched.

Checklist:

- [ ] Explain and operate both CI workflows (PR and push) and describe when each should fail
- [ ] Run CD safely (`plan` before `apply`) and recover from a failed deploy
- [ ] Trace one image from commit SHA to the running environment by digest
- [ ] Manage Terraform backends and tfvars per environment without state confusion
- [x] Validate Key Vault and RBAC prerequisites before deployment
- [ ] Demonstrate one end-to-end release in a short screen-share:
  - commit -> PR checks -> merge -> CI Push artifact -> CD apply -> health checks
- [ ] Assemble one portfolio evidence pack:
  - links to successful workflow runs
  - sample Terraform plan/apply outputs
  - short incident and recovery notes
- [ ] Prepare a short explain-back covering the main platform tradeoffs and why those decisions were made

Outcome:
You are junior-ready for this stack when you can both operate the platform safely and explain its tradeoffs clearly.

Portfolio / Interview checkpoint:
Be ready to walk through the full release path, justify the major design choices, and show evidence instead of speaking only in theory.

---

## Stage 10 - Multi-Service Expansion

Objective:
Add a second service so the platform supports service-to-service behavior instead of a single deployable only.

Why it matters:
This is the next meaningful step after junior readiness because it introduces integration boundaries, retries, and cross-service operational thinking.

Checklist:

- [ ] Create `python-service/` (FastAPI)
- [ ] Add `/health` and one business endpoint
- [ ] Add pytest + coverage
- [ ] Dockerize the Python service
- [ ] Extend Compose to run Node + Python + Postgres
- [ ] Add CI checks for Python (lint/test)
- [ ] Add a Node -> Python integration path with retries/timeouts

Outcome:
The platform evolves into a small multi-service architecture with service-to-service communication and CI quality gates.

Portfolio / Interview checkpoint:
Explain where the integration boundary lives, what retry and timeout behavior is needed, and how CI proves both services still work together.

---

## Stage 11 - Kubernetes and AKS Expansion

Objective:
Learn orchestration and infrastructure patterns beyond the current Container Apps runtime model.

Why it matters:
AKS is valuable expansion work, but it should be built on top of an already well-understood delivery and operations foundation.

Checklist:

- [ ] Add Kubernetes manifests (`k8s/`)
- [ ] Configure liveness and readiness probes
- [ ] Define resource requests and limits
- [ ] Add ingress routing
- [ ] Add autoscaling baseline (HPA)
- [ ] Add a VNet and subnet baseline for AKS
- [ ] Provision AKS via Terraform
- [ ] Attach ACR pull permissions to the AKS identity
- [ ] Document the network model decision (kubenet vs Azure CNI)

Outcome:
The service becomes operable in Kubernetes, and the AKS platform is reproducible through Terraform with explicit network and security decisions.

Portfolio / Interview checkpoint:
Explain when Container Apps is enough, when AKS becomes justified, and what new operational responsibilities Kubernetes introduces.
