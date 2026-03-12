# Terraform for Dev and Prod

This directory contains a single Terraform stack used for both environments via tfvars and remote backend files.

## Structure

```text
terraform/
+-- main.tf
+-- variables.tf
+-- outputs.tf
+-- versions.tf
+-- .terraform.lock.hcl
+-- backend/
|   +-- dev.hcl
|   L-- prod.hcl
L-- vars/
    +-- dev.tfvars
    L-- prod.tfvars
```

## What this stack manages

- Resource Group
- Azure Container Registry (ACR)
- Azure Database for PostgreSQL Flexible Server (+ application database)
- Azure Container App
- Shared-or-dedicated Container Apps Environment (CAE)
- Dedicated Key Vault per environment
- Key Vault private endpoint + private DNS zone group
- Shared runner infrastructure (VNet, subnets, NSG, Linux VM, private DNS zone + link)
- Role assignments:
  - `AcrPull` for Container App user-assigned identity
  - `Key Vault Secrets User` for Container App user-assigned identity

## Environment model

- `dev` creates CAE, dedicated dev Key Vault, and shared runner infrastructure.
- `prod` uses shared CAE, creates dedicated prod Key Vault, and reuses shared runner network assets from dev.
- Both environments keep isolated Terraform state keys:
  - `dev.terraform.tfstate`
  - `prod.terraform.tfstate`

## Backend

Backends are configured in:

- `backend/dev.hcl`
- `backend/prod.hcl`

Each command must run `terraform init` with the matching backend file.

## Required tools

- Terraform `>= 1.6`
- Azure CLI
- GitHub OIDC or Azure CLI login with sufficient RBAC

## Local usage

### Dev

```bash
terraform -chdir=terraform init -backend-config=backend/dev.hcl -reconfigure
terraform -chdir=terraform plan -var-file=vars/dev.tfvars -var="container_image_tag=sha-abc1234"
terraform -chdir=terraform apply -var-file=vars/dev.tfvars -var="container_image_tag=sha-abc1234"
terraform -chdir=terraform destroy -var-file=vars/dev.tfvars -auto-approve
```

### Prod

```bash
terraform -chdir=terraform init -backend-config=backend/prod.hcl -reconfigure
terraform -chdir=terraform plan -var-file=vars/prod.tfvars -var="container_image_tag=sha-abc1234"
terraform -chdir=terraform apply -var-file=vars/prod.tfvars -var="container_image_tag=sha-abc1234"
terraform -chdir=terraform destroy -var-file=vars/prod.tfvars -auto-approve
```

## Runtime variables

Important Terraform variables:

- `env`
- `location`
- `tags`
- `container_image_tag`
- `use_shared_cae`
- `shared_cae_name`
- `shared_cae_resource_group_name`
- `use_shared_key_vault`
- `key_vault_name`
- `app_env_vars` (non-sensitive map)
- Key Vault network policy:
  - `key_vault_network_mode` (`public_allow` currently, `firewall` after CAE VNet migration)
  - `key_vault_private_endpoint_enabled`
  - `key_vault_allowed_ip_cidrs` (used when mode is `firewall`)
  - `key_vault_allowed_subnet_ids` (used when mode is `firewall`)
- Shared runner platform:
  - `enable_shared_runner_platform`
  - `shared_runner_resource_group_name`
  - `shared_runner_location` (runner/PE region override, for example `eastus`)
  - `shared_runner_vnet_name`
  - `shared_runner_subnet_name`
  - `shared_runner_private_endpoints_subnet_name`
  - `shared_runner_private_dns_zone_name`
  - `shared_runner_admin_ssh_public_key`
  - `shared_runner_labels`
- `rbac_propagation_wait_seconds` (delay before Container App revision update after role assignments)
- PostgreSQL variables:
  - `postgres_server_version`
  - `postgres_sku_name`
  - `postgres_storage_mb`
  - `postgres_backup_retention_days`
  - `postgres_public_network_access_enabled`
  - `postgres_admin_username`
  - `postgres_database_name`

Terraform provisions PostgreSQL and configures Container App to read required `DB_*` values via Key Vault references.

Key Vault DB contract (per environment):

- Manual required secret:
  - `<env>-db-password` (example: `dev-db-password`)
- Terraform-managed secrets:
  - `<env>-db-host`
  - `<env>-db-port`
  - `<env>-db-user`
  - `<env>-db-name`

## CI/CD integration

- CI builds and pushes immutable image tags (`sha-<short_sha>`) to DEV ACR.
- CD receives `image_tag` and runs Terraform `plan|apply|destroy`.
- For PROD `plan/apply`, CD promotes the image from DEV ACR to PROD ACR by digest before Terraform.

CD action semantics:

- Use `plan` + `apply` for normal reconciliation.
- `apply` creates missing managed resources, updates drift, and performs replacement when required.
- `destroy` is a full environment reset for the selected Terraform state, not partial cleanup.
- Resources created outside Terraform state are not removed by `apply`.

## GitHub environment configuration

Each GitHub environment (`dev`, `prod`) must define:

### Variables

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ACR_NAME`
- `ACR_LOGIN_SERVER`
- `TF_APP_ENV_VARS_JSON` (optional JSON map, example: `{"NODE_ENV":"production"}`)
- `TF_SHARED_RUNNER_ADMIN_SSH_PUBLIC_KEY` (required for runner VM create/update)

### Secrets

- No Terraform secret input is required.

Additional requirement:

- The deploy identity running Terraform (GitHub OIDC app/service principal) must have `Key Vault Secrets Officer` on the target env Key Vault scope.
- Runtime identity (`<project>-<env>-ca-identity`) must have `Key Vault Secrets User` on the same env Key Vault scope.
- If Key Vault is created for the first time in an environment, bootstrap in three steps:
  1) create Key Vault,
  2) add `<env>-db-password` (or, in temporary `firewall` mode, add/remove your `/32` allowlist around this step),
  3) run full Terraform `plan/apply`.

## Notes

- `destroy` is available for both `dev` and `prod` in manual CD workflow.
- Runtime-compatible default is `key_vault_network_mode = public_allow` (until CAE VNet migration).
- If you temporarily switch to `firewall` mode for testing, add temporary KV firewall `/32` and pass the same value in `key_vault_allowed_ip_cidrs`.
- For local `plan/apply`, always pass explicit `container_image_tag` (for example `sha-<short_sha>` from CI Push).
- State keys and naming conventions are preserved to avoid accidental resource replacement.
- Phase 2 hardening is active: dedicated env Key Vaults + self-hosted runner in VNet + private endpoint path.
