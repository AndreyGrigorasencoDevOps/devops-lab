Roadmap — Platform Evolution Plan

This project is evolving from a simple Node.js API into a production-style DevOps platform.

The goal is not just to build an API, but to simulate a real-world service lifecycle:
design → containerize → test → build → push → deploy → scale → secure → observe.

---

## Stage 1 — Quality & Testing (Foundation)

Objective: enforce production-grade quality gates.

- [x] ESLint (strict, flat config)
- [x] PR checks (lint + tests)
- [x] HTTP integration tests (supertest)
- [x] Test coverage reporting
- [ ] Conventional commits enforcement

Outcome:
Reliable CI that blocks low-quality code before merge.

---

## Stage 2 — Container CI (Build Artifacts)

Objective: treat Docker image as a release artifact.

- [ ] Build Docker image in GitHub Actions
- [ ] Push image to GHCR (sha + main tags)
- [ ] Semantic versioning (vX.Y.Z)
- [ ] Multi-environment tagging (dev/prod)

Outcome:
Every merge to main produces a versioned container image.

---

## Stage 3 — Cloud Deployment (Azure)

Objective: deploy containerized service to Azure before free trial expires.

- [ ] Azure Container Registry (ACR)
- [ ] Push image to ACR from GitHub Actions
- [ ] Deploy to Azure Container Apps (initial target)
- [ ] Environment separation (dev vs prod)
- [ ] Managed identity / secure registry access

Outcome:
Cloud-hosted API running from CI-built container.

---

## Stage 4 — Python Service (Company Stack Alignment)

Objective: align with Python-based backend stack.

- [ ] Add FastAPI microservice (`python-service/`)
- [ ] Dockerize Python service
- [ ] docker-compose: run Node + Python locally
- [ ] CI job for Python (lint + tests)
- [ ] Inter-service communication (Node → Python)

Outcome:
Multi-service architecture aligned with company stack.

---

## Stage 5 — Kubernetes

Objective: move from single-container deployment to orchestration.

- [ ] Kubernetes manifests (Deployment, Service)
- [ ] Readiness/Liveness probes
- [ ] Horizontal Pod Autoscaler
- [ ] Ingress controller
- [ ] Resource limits & requests

Outcome:
Production-style container orchestration.

---

## Stage 6 — Infrastructure as Code (Terraform)

Objective: provision Azure infrastructure programmatically.

- [ ] Resource Group
- [ ] VNet + Subnet
- [ ] Azure Container Registry
- [ ] Azure Kubernetes Service (AKS)
- [ ] Remote Terraform state (Azure Storage)

Outcome:
Fully reproducible infrastructure.

---

## Stage 7 — Security & Identity (Azure Entra ID)

Objective: enterprise-grade identity integration.

- [ ] Azure Entra ID integration
- [ ] Service-to-service authentication
- [ ] Secret management strategy
- [ ] RBAC configuration

Outcome:
Enterprise-ready authentication and authorization model.

---

## Stage 8 — Observability & Production Thinking

Objective: simulate real production environment concerns.

- [ ] Structured logs in cloud
- [ ] Health metrics
- [ ] Monitoring (Azure Monitor / Prometheus later)
- [ ] Failure simulation & recovery testing
- [ ] Rolling updates strategy

Outcome:
Operationally resilient service.