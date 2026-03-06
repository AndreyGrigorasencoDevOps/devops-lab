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

## 5) Notes

- Keep dev/prod state isolated via backend keys.
- Use `plan` before `apply`.
- Manage secrets in Key Vault, not in Terraform variable files.
