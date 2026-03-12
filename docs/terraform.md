# Terraform Quick Reference

Primary guide: [terraform/README.md](../terraform/README.md)

Use this file as a short command reference for day-to-day operations.

## 1) Authentication Modes

### CI (recommended for deployments)

- GitHub Actions + Azure OIDC
- Environment-scoped values:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`

### Local (manual operations)

```bash
az login
az account set --subscription <azure_subscription_id>
```

## 2) Backend Init Pattern

Always initialize Terraform with the correct backend file.

```bash
# dev
terraform -chdir=terraform init -backend-config=backend/dev.hcl -reconfigure

# prod
terraform -chdir=terraform init -backend-config=backend/prod.hcl -reconfigure
```

## 3) Common Commands

### Dev

```bash
terraform -chdir=terraform plan -var-file=vars/dev.tfvars -var="container_image_tag=sha-abc1234"
terraform -chdir=terraform apply -var-file=vars/dev.tfvars -var="container_image_tag=sha-abc1234"
terraform -chdir=terraform destroy -var-file=vars/dev.tfvars -auto-approve
```

### Prod

```bash
terraform -chdir=terraform plan -var-file=vars/prod.tfvars -var="container_image_tag=sha-abc1234"
terraform -chdir=terraform apply -var-file=vars/prod.tfvars -var="container_image_tag=sha-abc1234"
terraform -chdir=terraform destroy -var-file=vars/prod.tfvars -auto-approve
```

## 4) Runtime Variable Injection from CI

CD workflow exports:

- `TF_VAR_container_image_tag` (for plan/apply)
- `TF_VAR_app_env_vars` (optional map from `TF_APP_ENV_VARS_JSON`)
- `TF_VAR_rbac_propagation_wait_seconds` (default: `45`)
- `TF_VAR_shared_runner_admin_ssh_public_key` (from `TF_SHARED_RUNNER_ADMIN_SSH_PUBLIC_KEY` when set)

## 5) Key Vault Contract for Database

- Required manual secret before `plan/apply`:
  - `<env>-db-password` (for each env, for example `dev-db-password`)
- Terraform manages runtime DB metadata secrets in Key Vault:
  - `<env>-db-host`
  - `<env>-db-port`
  - `<env>-db-user`
  - `<env>-db-name`
- Container App reads all `DB_*` via Key Vault secret references.

Role requirements:

- Terraform deploy identity: `Key Vault Secrets Officer`
- Container App user-assigned identity: `Key Vault Secrets User`
- CD runner path uses Key Vault private endpoint + private DNS in shared runner VNet.
- Use `shared_runner_location` when shared runner VNet/VM must run in a different region than app resources.

Bootstrap note:

- If the Key Vault does not exist yet for an environment, create it first, then add `<env>-db-password`, then run full `plan/apply`.
- Current runtime-compatible mode is `public_allow` until CAE VNet migration.
- If temporary `firewall` mode blocks local access (`ForbiddenByFirewall`), add a temporary `/32` allowlist rule and pass the same `/32` via `key_vault_allowed_ip_cidrs` during local `plan/apply`.

## 6) Notes

- Keep dev/prod state isolated via backend keys.
- Use `plan` before `apply`.
- Always pass explicit `container_image_tag` for local `plan/apply` (for example `sha-<short_sha>` from latest CI Push).
- Manage secrets in Key Vault, not in Terraform variable files.
- Current hardening mode is dedicated env Key Vaults with private endpoints + `public_allow` runtime compatibility.
- Use `destroy` only for full environment reset; normal deploy path is `plan` -> `apply`.
- `apply` reconciles Terraform-managed resources only; unmanaged resources are not removed automatically.
