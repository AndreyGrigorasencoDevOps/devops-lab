# Revision Runbook

This runbook turns the roadmap into a repeatable study and assessment system. Use it to revise what you have already built, prepare for what you plan to build next, and strengthen your ability to explain the project clearly in interviews or internal discussions.

## Purpose

- Protect long-term memory by revisiting every stage in a structured way.
- Convert implementation work into explanation skill, not just task completion.
- Give you a stable path for self-revision, stage testing, and a final capstone exam.
- Keep future stages visible now so the learning system stays consistent as the project grows.

## How To Study Each Stage

1. Re-read the matching stage in [docs/ROADMAP.md](../ROADMAP.md).
2. Review the source-of-truth docs, code, workflows, and Terraform areas listed below.
3. Explain the stage out loud without notes.
4. Re-run the key commands, checks, or mental walkthroughs for that stage.
5. Gather evidence that proves the stage is real in this repo.
6. Take the stage test in `revision mode`, then later retake it in `exam mode`.

## Grading Model

- Every stage test is scored out of `100`.
- Pass mark for each stage test: `80/100`.
- Final exam pass mark: `80/100`.
- Stage tests are meant to be reused twice:
  - after stage completion
  - during end-of-roadmap consolidation

## Revision Mode vs Exam Mode

| Mode | Notes | Feedback timing | Scoring style |
| --- | --- | --- | --- |
| Revision mode | Allowed | After each answer | Coaching-first, still scored |
| Exam mode | Not allowed | End of session | Strict scoring, pass/fail recorded |

## How To Use These Files With Codex

Use one of these prompt patterns in a future chat:

- `Run Stage 4 test in revision mode from docs/revision/stage-04-test.md`
- `Run Stage 7 test in exam mode from docs/revision/stage-07-test.md`
- `Run the final exam from docs/revision/final-exam.md`

Expected Codex behavior for all assessments:

- ask one question at a time
- stay inside the file rubric
- avoid revealing model answers before scoring in exam mode
- score each answer against the file criteria
- finish with total score, pass/fail result, strengths, weak areas, and a short study prescription

## Stage 1 - Product Build and Local Runtime

- Status: `implemented`
- Goal in plain language: understand what the service does, how it boots, and how to run it locally before adding cloud and delivery complexity
- Revisit:
  - [docs/ROADMAP.md](../ROADMAP.md)
  - [docs/local-development.md](../local-development.md)
  - [src/app.js](../../src/app.js)
  - [src/index.mjs](../../src/index.mjs)
  - [src/config/env.js](../../src/config/env.js)
- Key features and behaviors to remember:
  - separate `/health`, `/ready`, and `/info` contracts
  - host-run Node plus Docker Postgres flow
  - full Docker Compose flow
  - `.env.example` as the local env contract
- Architecture decisions and tradeoffs to explain:
  - why liveness and readiness are different
  - why host-run Node is useful for debugging
  - why Compose is useful for higher-fidelity local parity
- Commands, workflows, or runtime checks to know:
  - `nvm use`
  - `cp .env.example .env`
  - `./scripts/check-local-dev-prereqs.sh`
  - `docker compose up -d db`
  - `npm ci`
  - `npm run dev`
  - `curl http://localhost:3000/health`
  - `curl http://localhost:3000/ready`
- Common failure modes and what they usually mean:
  - `client password must be a string` usually means env loading or `DB_PASSWORD` is wrong
  - `ECONNREFUSED 127.0.0.1:5432` usually means Postgres is not running on the expected port
- Evidence you should be able to show:
  - working local run output
  - successful health and readiness checks
  - proof that both local flows are understood
- Explain it out loud:
  - explain how the app starts locally and why the three core endpoints exist
- Revision checklist:
  - can explain both local run paths
  - can explain env-driven runtime configuration
  - can explain what readiness checks in this project

## Stage 2 - Quality Gates and CI Foundations

- Status: `implemented`
- Goal in plain language: prevent bad changes from reaching `main` by enforcing predictable pull-request checks
- Revisit:
  - [docs/ROADMAP.md](../ROADMAP.md)
  - [README.md](../../README.md)
  - [.github/workflows/ci.yml](../../.github/workflows/ci.yml)
  - [package.json](../../package.json)
  - [test/app.test.js](../../test/app.test.js)
- Key features and behaviors to remember:
  - PR-only validation flow
  - lint, tests, coverage, Sonar, dependency review, and semantic title checks
  - security audit and summary publication
- Architecture decisions and tradeoffs to explain:
  - why PR validation is separate from push artifact build
  - why Sonar is token-gated and fork-safe
  - why branch protection matters before deployment automation
- Commands, workflows, or runtime checks to know:
  - `npm run lint`
  - `npm run test:coverage`
  - `npm audit --omit=dev --audit-level=high`
  - how `ci.yml` is triggered
- Common failure modes and what they usually mean:
  - lint failures usually mean code style or unsafe patterns were introduced
  - test failures usually mean behavior drift or broken contracts
  - skipped Sonar in forks is expected when the token is unavailable
- Evidence you should be able to show:
  - successful PR workflow run
  - coverage output
  - examples of checks that would block merge
- Explain it out loud:
  - explain why these checks run before merge instead of during deployment
- Revision checklist:
  - can name each job in the PR workflow
  - can explain what should block a merge
  - can explain why coverage and dependency review matter

## Stage 3 - Container Artifact Delivery

- Status: `implemented`
- Goal in plain language: produce a trusted image artifact that CD can deploy safely
- Revisit:
  - [docs/ROADMAP.md](../ROADMAP.md)
  - [README.md](../../README.md)
  - [.github/workflows/ci-push.yml](../../.github/workflows/ci-push.yml)
  - [.github/workflows/ci.yml](../../.github/workflows/ci.yml)
  - [Dockerfile](../../Dockerfile)
- Key features and behaviors to remember:
  - immutable image tag pattern `sha-<short_sha>`
  - Trivy filesystem and config scans
  - Docker smoke test against `/health`
  - DEV ACR push and digest verification
- Architecture decisions and tradeoffs to explain:
  - why immutable tags are better than mutable tags for release tracking
  - why digest verification matters before CD handoff
  - why image security checks belong in CI
- Commands, workflows, or runtime checks to know:
  - how `ci-push.yml` is triggered
  - where `image_tag`, `image_ref`, and `image_digest` are published
  - how to inspect image digests in ACR
- Common failure modes and what they usually mean:
  - Trivy failure usually means a high or critical issue in code, config, or base image posture
  - smoke test failure usually means the container does not start cleanly or `/health` is broken
- Evidence you should be able to show:
  - push workflow summary with image metadata
  - proof that the image exists in DEV ACR
  - proof that the digest was captured for CD
- Explain it out loud:
  - explain how a Git commit becomes a deployable container artifact in this repo
- Revision checklist:
  - can explain immutable tag vs digest
  - can explain Trivy and smoke-test purpose
  - can locate the image metadata in workflow output

## Stage 4 - Azure Runtime Platform

- Status: `implemented`
- Goal in plain language: run the service in Azure with identity-based access instead of application-owned secrets
- Revisit:
  - [docs/ROADMAP.md](../ROADMAP.md)
  - [docs/cloud-architecture.md](../cloud-architecture.md)
  - [docs/azure.md](../azure.md)
  - [src/app.js](../../src/app.js)
  - [terraform/main.tf](../../terraform/main.tf)
- Key features and behaviors to remember:
  - Azure Container Apps as runtime target
  - managed identity on the Container App
  - `AcrPull` for image pull
  - `Key Vault Secrets User` for runtime secret access
  - health endpoints reused for deployment/runtime checks
- Architecture decisions and tradeoffs to explain:
  - why Container Apps was chosen before AKS
  - why managed identity is better than storing registry and Key Vault secrets in the app
  - why readiness matters at runtime, not just in CI
- Commands, workflows, or runtime checks to know:
  - Azure login with OIDC in workflows
  - `GET /health`
  - `GET /ready`
  - how to inspect Container App image and ingress with Azure CLI
- Common failure modes and what they usually mean:
  - image pull issues usually point to registry access or identity role problems
  - readiness failures usually point to DB or secret-access problems
- Evidence you should be able to show:
  - running app in Azure
  - Container App image and ingress details
  - proof of identity-based access model
- Explain it out loud:
  - explain how the app runs in Azure without storing registry or DB secrets in the codebase
- Revision checklist:
  - can explain Container Apps role in the platform
  - can explain managed identity and runtime secret access
  - can explain health vs readiness in cloud operations

## Stage 5 - Terraform Foundation

- Status: `implemented`
- Goal in plain language: manage dev and prod infrastructure from code with clear state separation
- Revisit:
  - [docs/ROADMAP.md](../ROADMAP.md)
  - [terraform/README.md](../../terraform/README.md)
  - [docs/terraform.md](../terraform.md)
  - [terraform/main.tf](../../terraform/main.tf)
  - [terraform/variables.tf](../../terraform/variables.tf)
  - [terraform/backend/dev.hcl](../../terraform/backend/dev.hcl)
  - [terraform/backend/prod.hcl](../../terraform/backend/prod.hcl)
- Key features and behaviors to remember:
  - single Terraform root
  - environment-specific backends and tfvars
  - reproducible core resources
  - outputs for visibility and handoff
- Architecture decisions and tradeoffs to explain:
  - why one root plus env-specific config was chosen
  - why backend isolation prevents state confusion
  - why manual clicks become a risk once environments diverge
- Commands, workflows, or runtime checks to know:
  - `terraform -chdir=terraform init -backend-config=backend/dev.hcl -reconfigure`
  - `terraform -chdir=terraform plan -var-file=vars/dev.tfvars -var="container_image_tag=sha-abc1234"`
  - equivalent prod commands
- Common failure modes and what they usually mean:
  - wrong backend init can point you at the wrong state
  - wrong tfvars can plan against the wrong environment assumptions
  - unmanaged drift appears when portal edits are not brought back into code
- Evidence you should be able to show:
  - plan and apply output for at least one environment
  - backend separation proof
  - resource ownership clearly visible in Terraform
- Explain it out loud:
  - explain how state, tfvars, and outputs work together in this project
- Revision checklist:
  - can explain backend vs tfvars
  - can name the main Terraform-managed resources
  - can explain drift risk in plain language

## Stage 6 - Delivery Workflow

- Status: `implemented`
- Goal in plain language: turn artifact creation into a controlled deployment process for dev and prod
- Revisit:
  - [docs/ROADMAP.md](../ROADMAP.md)
  - [README.md](../../README.md)
  - [.github/workflows/cd.yml](../../.github/workflows/cd.yml)
  - [scripts/check-post-refactor-prereqs.sh](../../scripts/check-post-refactor-prereqs.sh)
  - [docs/post-refactor-runbook.md](../post-refactor-runbook.md)
- Key features and behaviors to remember:
  - manual `workflow_dispatch` CD
  - validated inputs for `environment`, `action`, and `image_tag`
  - prod digest promotion before Terraform
  - self-hosted runner boot, Terraform execution, and deallocate flow
  - preflight gate before plan/apply
- Architecture decisions and tradeoffs to explain:
  - why the safe path is `plan` before `apply`
  - why prod uses digest promotion instead of direct tag deployment
  - why Terraform runs from a runner with the right network access
- Commands, workflows, or runtime checks to know:
  - CD launch inputs
  - preflight script usage
  - how to interpret the CD summary
- Common failure modes and what they usually mean:
  - input validation failure means the run was unsafe or incomplete before it began
  - runner-online failure usually means the shared runner VM or registration path is broken
  - preflight failure usually means security/network prerequisites are missing
- Evidence you should be able to show:
  - successful CD `plan`
  - successful CD `apply`
  - prod digest match after promotion
- Explain it out loud:
  - explain the full CD path from selected image tag to Terraform apply
- Revision checklist:
  - can explain all CD inputs
  - can explain prod promotion path
  - can explain why preflight exists

## Stage 7 - Identity, Secrets, and Secure Operations

- Status: `implemented`
- Goal in plain language: harden the platform so deployment and runtime access are auditable, least-privilege, and private where needed
- Revisit:
  - [docs/ROADMAP.md](../ROADMAP.md)
  - [docs/security-operations.md](../security-operations.md)
  - [docs/cloud-architecture.md](../cloud-architecture.md)
  - [docs/azure.md](../azure.md)
  - [docs/terraform.md](../terraform.md)
- Key features and behaviors to remember:
  - GitHub OIDC to Azure
  - managed identity for runtime
  - dedicated env Key Vaults
  - private endpoints and private DNS
  - shared runner inside the network path
  - secret rotation and access review cadence
- Architecture decisions and tradeoffs to explain:
  - why OIDC beats long-lived cloud credentials
  - why `public_allow` existed temporarily and why `firewall` is the target posture
  - why secret ownership is split between Terraform and manual control for the DB password
- Commands, workflows, or runtime checks to know:
  - preflight security checks
  - Key Vault secret checks
  - role assignment checks
  - rotation runbook steps
- Common failure modes and what they usually mean:
  - `ForbiddenByFirewall` usually means network posture and access path do not match
  - missing secret or wrong role usually breaks readiness or deployment
  - stale human access creates audit and least-privilege risk
- Evidence you should be able to show:
  - role model for deploy and runtime identities
  - Key Vault posture and private access path
  - documented rotation and access review process
- Explain it out loud:
  - explain how the project moved from workable secret access to the current hardened steady state
- Revision checklist:
  - can explain OIDC, managed identity, and Key Vault roles
  - can explain the current steady-state network posture
  - can explain secret ownership and rotation

## Stage 8 - Observability, Incident Response, and Release Readiness

- Status: `in progress`
- Goal in plain language: turn the platform into something you can observe, alert on, and recover when it fails
- Revisit:
  - [docs/ROADMAP.md](../ROADMAP.md)
  - [docs/cloud-architecture.md](../cloud-architecture.md)
  - [src/utils/logger.js](../../src/utils/logger.js)
  - [src/middlewares/httpLogger.js](../../src/middlewares/httpLogger.js)
  - [src/services/readiness.service.js](../../src/services/readiness.service.js)
- Key features and behaviors to remember:
  - structured logging already exists
  - dashboards, alerts, drills, and recovery artifacts are the next planned additions
  - the stage is about signals plus operator response, not logs alone
- Architecture decisions and tradeoffs to explain:
  - why availability, errors, latency, and saturation are the core first signals
  - why an alert is only useful if the recovery path is also defined
  - why drills matter before real incidents happen
- Commands, workflows, or runtime checks to know:
  - `/health` and `/ready` remain the simplest runtime checks
  - know where current logs are emitted and how they would feed future dashboards
- Common failure modes and what they usually mean:
  - noisy logs without signal design create confusion, not observability
  - alerts without tested ownership or recovery steps create alert fatigue
- Evidence you should be able to show:
  - current structured log examples
  - future dashboard and alert design plan
  - post-incident template once created
- Explain it out loud:
  - explain what observability gaps still exist and how Stage 8 is meant to close them
- Revision checklist:
  - can explain the four key signal types
  - can describe at least one useful alert path
  - can describe one rollback or failed-deploy drill you plan to run

## Stage 9 - Junior Readiness and Portfolio Evidence

- Status: `in progress`
- Goal in plain language: prove you can operate and explain the platform clearly enough for junior-level evaluation
- Revisit:
  - [docs/ROADMAP.md](../ROADMAP.md)
  - [README.md](../../README.md)
  - [.github/workflows/ci.yml](../../.github/workflows/ci.yml)
  - [.github/workflows/ci-push.yml](../../.github/workflows/ci-push.yml)
  - [.github/workflows/cd.yml](../../.github/workflows/cd.yml)
- Key features and behaviors to remember:
  - end-to-end release demo
  - digest trace from commit to runtime
  - evidence pack with runs, plans, and recovery notes
  - short explain-back of major tradeoffs
- Architecture decisions and tradeoffs to explain:
  - why explanation quality matters as much as implementation depth
  - why evidence beats vague theory in interviews and reviews
  - why this stage sits before multi-service and AKS expansion
- Commands, workflows, or runtime checks to know:
  - how to walk someone through CI, CI Push, and CD
  - how to show health checks after deployment
  - how to locate workflow evidence quickly
- Common failure modes and what they usually mean:
  - vague answers usually mean understanding is shallow even if the implementation exists
  - inability to trace an image by digest usually means the release model is not fully internalized yet
- Evidence you should be able to show:
  - one clean release story
  - one digest trace story
  - one failure and recovery story
  - one concise portfolio evidence pack
- Explain it out loud:
  - explain the full platform to a junior hiring manager in five minutes without opening every file in the repo
- Revision checklist:
  - can narrate the release path cleanly
  - can defend the major architecture choices
  - can show concrete proof for what you claim

## Stage 10 - Multi-Service Expansion

- Status: `planned`
- Goal in plain language: evolve from a single-service deployment to a small multi-service platform with real integration behavior
- Revisit:
  - [docs/ROADMAP.md](../ROADMAP.md)
  - [docs/cloud-architecture.md](../cloud-architecture.md)
  - [src/utils/retry.js](../../src/utils/retry.js)
  - [docker-compose.yml](../../docker-compose.yml)
  - [.github/workflows/ci.yml](../../.github/workflows/ci.yml)
- Key features and behaviors to remember:
  - planned FastAPI service
  - additional health endpoint and business endpoint
  - Node to Python integration with retries and timeouts
  - multi-service CI coverage
- Architecture decisions and tradeoffs to explain:
  - why add a second service only after the core platform is understandable
  - why retries and timeouts matter once services call each other
  - why multi-service complexity should still stay small at this stage
- Commands, workflows, or runtime checks to know:
  - expected Compose expansion for Node + Python + Postgres
  - expected CI additions for Python lint/test coverage
- Common failure modes and what they usually mean:
  - silent integration assumptions usually lead to flaky service-to-service behavior
  - missing timeouts or retries usually turn small dependencies into full request failures
- Evidence you should be able to show:
  - future Python service health proof
  - future integration test proof
  - future CI proof for both services
- Explain it out loud:
  - explain how the platform changes once the Node service depends on a second internal service
- Revision checklist:
  - can explain the planned service boundary
  - can explain retry and timeout needs
  - can explain how CI should expand for multi-service work

## Stage 11 - Kubernetes and AKS Expansion

- Status: `planned`
- Goal in plain language: learn when the current runtime stops being enough and what AKS adds operationally
- Revisit:
  - [docs/ROADMAP.md](../ROADMAP.md)
  - [docs/cloud-architecture.md](../cloud-architecture.md)
  - [terraform/README.md](../../terraform/README.md)
  - [docs/terraform.md](../terraform.md)
- Key features and behaviors to remember:
  - planned Kubernetes manifests
  - probes, requests/limits, ingress, and HPA
  - AKS provisioning and network model choice
- Architecture decisions and tradeoffs to explain:
  - when Container Apps is enough
  - when AKS becomes justified
  - kubenet vs Azure CNI as an explicit network design decision
- Commands, workflows, or runtime checks to know:
  - expected `k8s/` manifest coverage
  - expected Terraform ownership for AKS
  - expected ACR pull integration for AKS identity
- Common failure modes and what they usually mean:
  - moving to Kubernetes too early can create complexity without learning payoff
  - weak resource and probe design leads to noisy or unstable workloads
- Evidence you should be able to show:
  - future manifests
  - future AKS Terraform plans
  - future deployment and health validation proof
- Explain it out loud:
  - explain what new responsibilities Kubernetes introduces compared with the current Container Apps model
- Revision checklist:
  - can explain why AKS is later, not earlier
  - can explain the new runtime controls Kubernetes adds
  - can explain the planned network decision you will need to make
