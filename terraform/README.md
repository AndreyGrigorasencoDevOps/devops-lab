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
¦   +-- dev.hcl
¦   L-- prod.hcl
L-- vars/
    +-- dev.tfvars
    L-- prod.tfvars
```

## What this stack manages

- Resource Group
- Azure Container Registry (ACR)
- Azure Container App
- Shared-or-dedicated Container Apps Environment (CAE)
- Shared-or-dedicated Key Vault
- Role assignments:
  - `AcrPull` for Container App managed identity
  - `Key Vault Secrets User` for Container App managed identity

## Environment model

- `dev` creates CAE and Key Vault (shared resources).
- `prod` uses shared CAE and shared Key Vault via data sources.
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
- `shared_key_vault_name`
- `shared_key_vault_resource_group_name`
- `app_env_vars` (non-sensitive map)

Secrets are managed manually in Azure Key Vault/Container Apps.

## CI/CD integration

- CI builds and pushes immutable image tags (`sha-<short_sha>`) to DEV ACR.
- CD receives `image_tag` and runs Terraform `plan|apply|destroy`.
- For PROD `plan/apply`, CD promotes the image from DEV ACR to PROD ACR by digest before Terraform.

## GitHub environment configuration

Each GitHub environment (`dev`, `prod`) must define:

### Variables

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ACR_NAME`
- `ACR_LOGIN_SERVER`
- `TF_APP_ENV_VARS_JSON` (optional JSON map, example: `{"NODE_ENV":"production"}`)

### Secrets

- No Terraform secret input is required; secrets are managed manually.

## Notes

- `destroy` is available for both `dev` and `prod` in manual CD workflow.
- State keys and naming conventions are preserved to avoid accidental resource replacement.
