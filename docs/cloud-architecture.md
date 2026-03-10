# Cloud Architecture - Task API Platform (Azure)

This document describes the current cloud architecture and near-term evolution path.

---

## Table of Contents

- [1. Overview](#1-overview)
- [2. Subscription and Tenant Model](#2-subscription-and-tenant-model)
- [3. Environments and Deployment Strategy](#3-environments-and-deployment-strategy)
- [4. Naming Convention](#4-naming-convention)
- [5. Current Architecture (March 2026)](#5-current-architecture-march-2026)
- [6. Security Baseline](#6-security-baseline)
- [7. Operations Baseline](#7-operations-baseline)
- [8. Future Evolution](#8-future-evolution)

---

## 1. Overview

The platform currently runs on Azure Container Apps and is managed by GitHub Actions + Terraform.

Current delivery model:

- PR validation (`ci.yml`)
- Push artifact build (`ci-push.yml`)
- Manual CD (`cd.yml`) using Terraform plan/apply/destroy

---

## 2. Subscription and Tenant Model

Use placeholders in docs and scripts. Do not commit environment-specific secret values.

| Property | Example Placeholder |
| --- | --- |
| Subscription ID | `<azure_subscription_id>` |
| Tenant ID | `<azure_tenant_id>` |
| Region | `uksouth` |

Security rule:

- Never commit client secrets, passwords, tokens, or connection strings.

---

## 3. Environments and Deployment Strategy

| Environment | Trigger Source | Deployment Mode |
| --- | --- | --- |
| `dev` | Push to `main` creates image artifact | Manual CD (`plan/apply`) |
| `prod` | Manual CD with selected immutable image tag | Digest promotion + Terraform |

Key point:

- Prod image is promoted from DEV ACR by digest before Terraform apply.

---

## 4. Naming Convention

Primary pattern:

```text
taskapi-<env>-<resource>-uks
```

Examples:

- `taskapi-dev-rg-uks`
- `taskapi-prod-rg-uks`
- `taskapi-dev-cae-uks`
- `taskapi-dev-kv-uks`
- `taskapi-prod-kv-uks`
- `taskapi-shared-runner-vnet-uks`

Notes:

- ACR names must be globally unique and lowercase.
- Key Vault names are globally unique and must follow Azure naming rules.

---

## 5. Current Architecture (March 2026)

```text
GitHub Actions (manual CD)
            |
            v
Self-hosted Runner (VNet, private DNS)
            |
            v
Terraform + Azure API
            |
            +--> Azure Container Registry (DEV/PROD)
            +--> Azure Container Apps (dev/prod runtime)
            +--> Azure Key Vault (dedicated per env + private endpoint)
```

Managed by Terraform:

- Resource Group
- Log Analytics Workspace
- Container Apps Environment (shared or dedicated)
- Azure Container Registry
- Azure Database for PostgreSQL Flexible Server (+ app database)
- Azure Container App
- Key Vault (dedicated per environment)
- Key Vault private endpoint + private DNS zone group
- Shared runner VNet + runner/PE subnets + NSG + Linux VM runner
- Shared private DNS zone `privatelink.vaultcore.azure.net` + VNet link
- RBAC assignments (`AcrPull`, `Key Vault Secrets User`)

---

## 6. Security Baseline

- GitHub -> Azure auth via OIDC (no long-lived cloud credentials in repo).
- Runtime access via Managed Identity.
- Key Vault firewall mode (`Deny`) with private endpoint access path from runner network.
- Pragmatic runtime compatibility mode: Key Vault `bypass = AzureServices` remains enabled until CAE VNet migration.
- Principle of least privilege enforced through RBAC assignments.

Database secret contract:

- `<env>-db-host`
- `<env>-db-port`
- `<env>-db-user`
- `<env>-db-password`
- `<env>-db-name`

Ownership:

- `<env>-db-password` is manually managed in Key Vault.
- `<env>-db-host`, `<env>-db-port`, `<env>-db-user`, `<env>-db-name` are written by Terraform to Key Vault.

---

## 7. Operations Baseline

- Health endpoints:
  - `GET /health` (liveness)
  - `GET /ready` (readiness)
- CI/CD runbooks:
  - `docs/post-refactor-runbook.md`
  - `scripts/check-post-refactor-prereqs.sh`
- CD preflight gate validates Key Vault/RBAC/runner prerequisites before `plan/apply`.
- Terraform operation guide:
  - `terraform/README.md`

---

## 8. Future Evolution

Planned next evolution layers:

- Multi-service architecture (Node + Python service)
- Kubernetes runtime track (AKS) as a future stage
- Expanded observability (dashboards, alerts, incident drills)
- Stronger policy guardrails for prod change management

AKS is a future target, not the current production runtime for this repository.
