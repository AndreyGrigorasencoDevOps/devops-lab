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

- Node 24 is the default application and container runtime baseline.
- DEV push workflow builds and pushes immutable image tags to DEV ACR.
- PROD deployments promote image by digest from DEV ACR to PROD ACR.
- Container App runtime pulls via managed identity (`AcrPull` role).

## 2.1) ACR Hygiene and Cost Control

- Both live registries run on the `Basic` SKU, so the current ACR bill is primarily the fixed tier fee, not a storage overage.
- Old image cleanup is still useful because it keeps growth bounded and makes rollback inventory easier to reason about.
- `.github/workflows/acr-cleanup.yml` is the repo-managed registry hygiene workflow.
- The workflow always preserves the currently deployed Container App image tag, even if it is older than the newest retained tags.
- Cleanup is digest-safe: it only deletes a manifest when none of its tags are protected by the retention rules.
- Retention policy:
  - DEV: keep the active tag plus the latest 5 additional `sha-*` tags; delete only tags older than 7 days
  - PROD: keep the active tag plus the latest 10 additional `sha-*` tags; delete only tags older than 30 days
- Non-`sha-*` tags are ignored by the cleanup workflow.
- Preferred rollout:
  1. run `workflow_dispatch` with `dry_run=true`
  2. review the step summary
  3. rerun with `dry_run=false`
  4. leave the weekly schedule in place for steady-state hygiene
- Do not treat this as a major current cost-saving lever. It is registry hygiene and future storage control.

## 3) Key Vault and Secrets

Database + Key Vault model:

- PostgreSQL server and app database are created by Terraform.
- Container App reads all `DB_*` values from Key Vault references.
- Dedicated Key Vault per environment (`taskapi-dev-kv-uks`, `taskapi-prod-kv-uks`).
- Key Vault network mode target is `firewall` with env-local private endpoints and runner/runtime private DNS resolution.
- Dedicated CAE + runtime VNet now exist in repo config for both environments.
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
5. Validate `/health` and `/ready` on the deployed app.
6. For runner relocation or break-glass work, use a trusted local shell or temporary GitHub-hosted runner, not the self-hosted runner VM being replaced.
7. Use `acr-cleanup.yml` for registry hygiene after deployments have settled; avoid running manual cleanup during an active prod rollout.

Detailed steps:

- `docs/post-refactor-runbook.md`
- `scripts/check-post-refactor-prereqs.sh`
