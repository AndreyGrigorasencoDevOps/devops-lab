# Terraform for Dev and Prod

This directory contains the env-specific Terraform stack for `dev` and `prod`.

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
+-- shared-ops/
|   +-- main.tf
|   +-- variables.tf
|   +-- outputs.tf
|   +-- versions.tf
|   +-- backend/
|   |   L-- shared.hcl
|   L-- vars/
|       L-- shared.tfvars
L-- vars/
    +-- dev.tfvars
    L-- prod.tfvars
```

## What the env stack manages

- Resource Group
- Runtime VNet
- CAE infrastructure subnet
- Runtime private-endpoints subnet
- Dedicated Container Apps Environment
- Log Analytics Workspace
- Azure Container Registry
- Azure Database for PostgreSQL Flexible Server (+ application database)
- Azure Container App
- Dedicated Key Vault per environment
- Key Vault private endpoint + private DNS zone group
- Shared runner infrastructure (owned by `dev` state)
- Runner/runtime VNet peering
- Role assignments:
  - `AcrPull`
  - `Key Vault Secrets User`

## Environment model

- `dev` manages:
  - dedicated CAE `taskapi-dev-cae-vnet-uks`
  - runtime VNet `taskapi-dev-rt-vnet-uks`
  - shared runner infrastructure
- `prod` manages:
  - dedicated CAE `taskapi-prod-cae-vnet-uks`
  - runtime VNet `taskapi-prod-rt-vnet-uks`
  - its own Key Vault + app/db resources
  - reverse peering back to the shared runner VNet
- State remains split:
  - `dev.terraform.tfstate`
  - `prod.terraform.tfstate`

## Backends

Env stack backends:

- `backend/dev.hcl`
- `backend/prod.hcl`

Shared-ops backend:

- `shared-ops/backend/shared.hcl`

## Local usage

### Dev

```bash
terraform -chdir=terraform init -backend-config=backend/dev.hcl -reconfigure
terraform -chdir=terraform plan -var-file=vars/dev.tfvars -var="container_image_tag=sha-abc1234"
terraform -chdir=terraform apply -var-file=vars/dev.tfvars -var="container_image_tag=sha-abc1234"
```

### Prod

```bash
terraform -chdir=terraform init -backend-config=backend/prod.hcl -reconfigure
terraform -chdir=terraform plan -var-file=vars/prod.tfvars -var="container_image_tag=sha-abc1234"
terraform -chdir=terraform apply -var-file=vars/prod.tfvars -var="container_image_tag=sha-abc1234"
```

### Shared ops

```bash
terraform -chdir=terraform/shared-ops init -backend-config=backend/shared.hcl -reconfigure
terraform -chdir=terraform/shared-ops plan -var-file=vars/shared.tfvars
terraform -chdir=terraform/shared-ops apply -var-file=vars/shared.tfvars
```

## Important variables

- Common:
  - `env`
  - `location`
  - `tags`
  - `container_image_tag`
- CAE / runtime network:
  - `use_shared_cae`
  - `container_app_environment_name`
  - `runtime_virtual_network_name`
  - `runtime_virtual_network_cidrs`
  - `container_app_environment_infrastructure_subnet_name`
  - `container_app_environment_infrastructure_subnet_cidrs`
  - `runtime_private_endpoints_subnet_name`
  - `runtime_private_endpoints_subnet_cidrs`
- Key Vault network policy:
  - `key_vault_network_mode`
  - `key_vault_private_endpoint_enabled`
  - `key_vault_allowed_ip_cidrs`
  - `key_vault_allowed_subnet_ids`
- Shared runner:
  - `enable_shared_runner_platform`
  - `shared_runner_resource_group_name`
  - `shared_runner_location`
  - `shared_runner_vnet_name`
  - `shared_runner_subnet_name`
  - `shared_runner_private_endpoints_subnet_name`
  - `shared_runner_private_dns_zone_name`
  - `shared_runner_admin_ssh_public_key`
  - `shared_runner_labels`

Steady-state target:

- `key_vault_network_mode = firewall`
- Key Vault `bypass = None`
- env-local Key Vault private endpoints
- shared runner target location `uksouth`
- repo default remains `firewall`; use `public_allow` only as a short-lived break-glass override

## CI/CD integration

- CI builds immutable image tags (`sha-<short_sha>`) to DEV ACR.
- CD receives `image_tag` and runs Terraform `plan|apply|destroy`.
- PROD promotes the image from DEV ACR to PROD ACR by digest before Terraform.
- Preflight is mandatory before `plan/apply`.

## Notes

- For local runs, always pass explicit `container_image_tag`.
- If initial bootstrap in `firewall` mode blocks local access, temporarily add your `/32` to `key_vault_allowed_ip_cidrs`, complete the step, then remove it.
- Shared runner relocation must be executed from a trusted local shell or temporary GitHub-hosted break-glass path, not from the self-hosted runner VM being replaced.
- Shared-ops now codifies only the subscription budget; runner scheduling is handled by the CD workflow boot/deallocate flow instead of a separate Terraform layer.
