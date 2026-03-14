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
- `TF_SHARED_RUNNER_ADMIN_SSH_PUBLIC_KEY` (for shared runner VM bootstrap/update)

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

Database + Key Vault model:

- PostgreSQL server and app database are created by Terraform.
- Container App reads all `DB_*` values from Key Vault references.
- Dedicated Key Vault per environment (`taskapi-dev-kv-uks`, `taskapi-prod-kv-uks`).
- Key Vault network mode is `public_allow` + private endpoint path for CD runner network.
- Target hardened state after CAE VNet migration is `firewall`.
- `DB_PASSWORD` is manual in env Key Vault as `<env>-db-password`.
- Terraform writes/updates:
  - `<env>-db-host`
  - `<env>-db-port`
  - `<env>-db-user`
  - `<env>-db-name`

Required Key Vault roles:

- Terraform deploy identity (GitHub OIDC app): `Key Vault Secrets Officer`
- Container App user-assigned identity: `Key Vault Secrets User`

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
az keyvault secret show --vault-name <kv_name> --name dev-db-password --query id -o tsv
```

### Set DB password secret (manual source of truth)

```bash
az keyvault secret set --vault-name <kv_name> --name dev-db-password --value "<strong_password_dev>"
az keyvault secret set --vault-name <kv_name> --name prod-db-password --value "<strong_password_prod>"
```

### Check role assignment for identity

```bash
az role assignment list \
  --assignee-object-id <principal_id> \
  --scope <resource_id> \
  -o table
```

## 5) Operational Workflow

1. PR checks pass in `ci.yml`.
2. Push to `main` produces image artifact in `ci-push.yml`.
3. CD (`cd.yml`) runs preflight (`check-post-refactor-prereqs.sh`) before `plan/apply`.
4. CD runs `plan` then `apply` for target environment.
5. Validate `/health` and `/ready` on deployed app.

Detailed steps:

- `docs/post-refactor-runbook.md`
- `scripts/check-post-refactor-prereqs.sh`
