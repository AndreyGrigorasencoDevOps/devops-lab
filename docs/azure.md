# Azure Operations Guide

This guide is a compact operational reference for the current Azure setup.

## 1) Authentication Model

GitHub Actions uses OIDC with environment-scoped variables.

Required per GitHub environment (`dev`, `prod`):

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ACR_NAME`
- `ACR_LOGIN_SERVER`
- Optional: `TF_APP_ENV_VARS_JSON`

Use Azure login step in workflows:

```yaml
- uses: azure/login@v2
  with:
    client-id: ${{ vars.AZURE_CLIENT_ID }}
    tenant-id: ${{ vars.AZURE_TENANT_ID }}
    subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

## 2) Runtime and Registry Model

- DEV push workflow builds and pushes immutable image tags to DEV ACR.
- PROD deployments promote image by digest from DEV ACR to PROD ACR.
- Container App runtime pulls via managed identity (`AcrPull` role).

## 3) Key Vault and Secrets

Database bootstrap model:

- PostgreSQL server and app database are created by Terraform.
- Container App receives required DB runtime env vars from Terraform:
  - `DB_HOST`
  - `DB_PORT`
  - `DB_USER`
  - `DB_PASSWORD`
  - `DB_NAME`

For non-database application secrets, keep using Key Vault.

Reference naming contract for manual app secrets:

- `DB_HOST`
- `DB_USER`
- `DB_PASSWORD`
- `DB_NAME`

Role expectation:

- Container App managed identity must have `Key Vault Secrets User` on the shared Key Vault.

## 4) Useful Azure CLI Checks

### Account and subscription

```bash
az account show -o table
```

### List resource groups

```bash
az group list -o table
```

### Check Container App image and ingress

```bash
az containerapp show \
  --name <container_app_name> \
  --resource-group <resource_group> \
  --query "{image:properties.template.containers[0].image,fqdn:properties.configuration.ingress.fqdn}" \
  -o table
```

### Check ACR manifest digest by tag

```bash
az acr manifest show-metadata \
  --registry <acr_name> \
  --name task-api:sha-<short_sha> \
  --query digest -o tsv
```

### Check Key Vault secret existence

```bash
az keyvault secret show --vault-name <kv_name> --name DB_PASSWORD --query id -o tsv
```

### Check role assignment for managed identity

```bash
az role assignment list \
  --assignee-object-id <principal_id> \
  --scope <resource_id> \
  -o table
```

## 5) Operational Workflow

1. PR checks pass in `ci.yml`.
2. Push to `main` produces image artifact in `ci-push.yml`.
3. CD (`cd.yml`) runs `plan` then `apply` for target environment.
4. Validate `/health` and `/ready` on deployed app.

Detailed steps:

- `docs/post-refactor-runbook.md`
- `scripts/check-post-refactor-prereqs.sh`
