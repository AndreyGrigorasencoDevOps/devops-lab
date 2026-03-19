# Cloud Architecture - Task API Platform (Azure)

This document describes the current repo target architecture and the rollout direction for Azure.

## 1. Overview

The platform runs on Azure Container Apps and is managed by GitHub Actions plus Terraform.

Delivery model:

- PR validation: `ci.yml`
- Push artifact build: `ci-push.yml`
- Manual CD: `cd.yml`
- Shared-ops budget layer: `terraform/shared-ops/`

## 2. Subscription and tenant model

Use placeholders in docs and scripts. Do not commit environment-specific secret values.

| Property | Example Placeholder |
| --- | --- |
| Subscription ID | `<azure_subscription_id>` |
| Tenant ID | `<azure_tenant_id>` |
| Region | `uksouth` |

## 3. Environments and deployment strategy

| Environment | Trigger Source | Deployment Mode |
| --- | --- | --- |
| `dev` | Push to `main` creates image artifact | Manual CD (`plan/apply`) |
| `prod` | Manual CD with selected immutable image tag | Digest promotion + Terraform |

Key point:

- Prod image is promoted from DEV ACR by digest before Terraform apply.

## 4. Naming convention

Primary pattern:

```text
taskapi-<env>-<resource>-uks
```

Examples:

- `taskapi-dev-rg-uks`
- `taskapi-prod-rg-uks`
- `taskapi-dev-cae-vnet-uks`
- `taskapi-prod-cae-vnet-uks`
- `taskapi-dev-rt-vnet-uks`
- `taskapi-shared-runner-vnet-uks`

## 5. Repo target architecture (March 2026)

```text
GitHub Actions (manual CD)
            |
            +--> Hosted bootstrap / cleanup jobs
            |        |
            |        v
            |   Start / deallocate shared runner VM
            |
            v
Self-hosted Runner (on-demand VM, shared VNet, private DNS)
            |
            v
Terraform + Azure API
            |
            +--> Azure Container Registry (DEV/PROD)
            +--> Azure Container Apps (dedicated CAE per env)
            +--> Azure Key Vault (dedicated per env + env-local private endpoint)
            +--> Shared Ops (subscription budget only)
```

Managed by the env stack:

- Resource Group
- Runtime VNet + CAE infrastructure subnet + env PE subnet
- Log Analytics Workspace
- Dedicated Container Apps Environment
- Azure Container Registry
- Azure Database for PostgreSQL Flexible Server (+ app database)
- Azure Container App
- Key Vault (dedicated per environment)
- Key Vault private endpoint + private DNS zone group
- Shared runner infrastructure (VNet, runner subnet, PE subnet, NSG, Linux VM)
- Shared private DNS zone `privatelink.vaultcore.azure.net`
- Runner/runtime VNet peering
- RBAC assignments (`AcrPull`, `Key Vault Secrets User`)

Managed by the shared-ops stack:

- subscription budget

## 6. Security baseline

- GitHub -> Azure auth via OIDC
- Runtime access via Managed Identity
- Dedicated CAE and runtime VNet per environment
- Key Vault steady-state target:
  - `key_vault_network_mode = firewall`
  - `default_action = Deny`
  - `bypass = None`
- Key Vault private endpoint access path from both runtime and runner networks
- Least-privilege RBAC through env-scoped role assignments

Database secret contract:

- `<env>-db-host`
- `<env>-db-port`
- `<env>-db-user`
- `<env>-db-password`
- `<env>-db-name`

Ownership:

- `<env>-db-password` is manually managed in Key Vault
- `<env>-db-host`, `<env>-db-port`, `<env>-db-user`, `<env>-db-name` are written by Terraform

## 7. Operations baseline

- Health endpoints:
  - `GET /health`
  - `GET /ready`
- CD boots the shared runner on demand and deallocates it after every run.
- Runbooks:
  - `docs/security-operations.md`
- Preflight:
  - `scripts/check-post-refactor-prereqs.sh`
- Terraform guides:
  - `terraform/README.md`
  - `terraform/shared-ops/README.md`

## 8. Future evolution

Planned next evolution layers:

- expanded observability and alerts
- incident drills and recovery evidence
- stronger prod guardrails
- future AKS exploration only if the runtime model changes materially
