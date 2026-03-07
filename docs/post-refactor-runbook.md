# Post-Refactor Runbook

This runbook covers the Sonar restore, CI split, and post-refactor operational checks for Terraform + Azure.

## 1) What is automated now

- `CI` workflow (`.github/workflows/ci.yml`) runs on `pull_request` to `main`:
  - PR title validation
  - dependency review
  - lint, tests with coverage, npm audit
  - Sonar scan (when token exists and PR is not from a fork)
  - Trivy scans
  - Docker smoke test
- `CI Push` workflow (`.github/workflows/ci-push.yml`) runs on `push` to `main`:
  - lint, tests with coverage, npm audit
  - Sonar scan (when token exists)
  - Trivy scans
  - Docker smoke test
  - build/push immutable image `sha-<short_sha>` to DEV ACR + digest verify
- `CD` workflow (`.github/workflows/cd.yml`) remains manual (`workflow_dispatch`) and uses Terraform for `plan|apply|destroy`.

## 2) One-time manual setup

## 2.1 Repo-level Sonar configuration

Required in GitHub repository:

- Secret: `SONAR_TOKEN`
- Variables: `SONAR_PROJECT`, `SONAR_ORG`

Commands:

```bash
gh secret set SONAR_TOKEN --repo <owner/repo>
gh variable set SONAR_PROJECT --repo <owner/repo> --body "<sonar_project_key>"
gh variable set SONAR_ORG --repo <owner/repo> --body "<sonar_org_key>"
```

## 2.2 GitHub environment variables (`dev` and `prod`)

Required variables in each environment:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ACR_NAME`
- `ACR_LOGIN_SERVER`
- Optional: `TF_APP_ENV_VARS_JSON` (JSON object string)

Example commands:

```bash
# dev
gh variable set AZURE_CLIENT_ID --repo <owner/repo> --env dev --body "<value>"
gh variable set AZURE_TENANT_ID --repo <owner/repo> --env dev --body "<value>"
gh variable set AZURE_SUBSCRIPTION_ID --repo <owner/repo> --env dev --body "<value>"
gh variable set ACR_NAME --repo <owner/repo> --env dev --body "<acr_name>"
gh variable set ACR_LOGIN_SERVER --repo <owner/repo> --env dev --body "<acr_login_server>"

# prod
gh variable set AZURE_CLIENT_ID --repo <owner/repo> --env prod --body "<value>"
gh variable set AZURE_TENANT_ID --repo <owner/repo> --env prod --body "<value>"
gh variable set AZURE_SUBSCRIPTION_ID --repo <owner/repo> --env prod --body "<value>"
gh variable set ACR_NAME --repo <owner/repo> --env prod --body "<acr_name>"
gh variable set ACR_LOGIN_SERVER --repo <owner/repo> --env prod --body "<acr_login_server>"
```

Optional `TF_APP_ENV_VARS_JSON`:

```bash
gh variable set TF_APP_ENV_VARS_JSON --repo <owner/repo> --env dev --body '{"NODE_ENV":"production"}'
gh variable set TF_APP_ENV_VARS_JSON --repo <owner/repo> --env prod --body '{"NODE_ENV":"production"}'
```

## 2.3 Database + Key Vault model

Current production-friendly model:

- Terraform creates PostgreSQL server + application database.
- Container App receives `DB_*` only via Key Vault references.
- `DB_PASSWORD` is manual in Key Vault (source of truth), env-scoped:
  - `dev-db-password`
  - `prod-db-password`
- Terraform creates/updates runtime Key Vault secrets:
  - `<env>-db-host`
  - `<env>-db-port`
  - `<env>-db-user`
  - `<env>-db-name`

One-time manual steps:

1. Create DB password secrets in shared Key Vault.

```bash
az keyvault secret set \
  --vault-name <shared_kv_name> \
  --name dev-db-password \
  --value "<strong_password_dev>"

az keyvault secret set \
  --vault-name <shared_kv_name> \
  --name prod-db-password \
  --value "<strong_password_prod>"
```

2. Grant Key Vault secret write/read rights to Terraform deploy identity (GitHub OIDC service principal for each environment):

```bash
az role assignment create \
  --assignee <azure_client_id_for_env> \
  --role "Key Vault Secrets Officer" \
  --scope "/subscriptions/<sub_id>/resourceGroups/<kv_rg>/providers/Microsoft.KeyVault/vaults/<shared_kv_name>"
```

Notes:

- Container App user-assigned identity gets `Key Vault Secrets User` from Terraform.
- If a Key Vault is being created for the first time, run a one-time bootstrap:
  1) create Key Vault (`terraform apply -target=azurerm_key_vault.main` for that env),
  2) create `<env>-db-password`,
  3) run full `plan/apply`.

## 3) Automated preflight check

Run the read-only prereq checker:

```bash
./scripts/check-post-refactor-prereqs.sh
```

Optional explicit inputs:

```bash
./scripts/check-post-refactor-prereqs.sh \
  --repo <owner/repo> \
  --project taskapi \
  --kv-name taskapi-shared-kv-uks \
  --kv-rg taskapi-dev-rg-uks \
  --dev-identity taskapi-dev-ca-identity \
  --prod-identity taskapi-prod-ca-identity
```

The script validates:

- GitHub Sonar secret/variables
- GitHub env variables (`dev` + `prod`)
- shared Key Vault existence
- required secrets `dev-db-password`, `prod-db-password`
- optional runtime secrets `<env>-db-host/port/user/name`
- `Key Vault Secrets User` role on Container App user-assigned identities (dev/prod)

## 4) Execution sequence

1. Open/update PR to `main` and confirm `CI` workflow passes.
2. Merge to `main` and confirm `CI Push` passes.
3. Capture `image_tag` (`sha-<short_sha>`) from CI Push summary.
4. Run CD `dev plan`, then `dev apply` with that `image_tag`.
5. Validate runtime:
   - `GET /health` returns 200
   - `GET /ready` returns 200
6. Run CD `prod plan`, then `prod apply` with same `image_tag`.
7. Re-check `/health` and `/ready` in prod.

## 5) CD commands (GitHub CLI)

```bash
# dev plan/apply
gh workflow run cd.yml -f environment=dev -f action=plan -f image_tag=sha-<short_sha>
gh workflow run cd.yml -f environment=dev -f action=apply -f image_tag=sha-<short_sha>

# prod plan/apply
gh workflow run cd.yml -f environment=prod -f action=plan -f image_tag=sha-<short_sha>
gh workflow run cd.yml -f environment=prod -f action=apply -f image_tag=sha-<short_sha>
```

## 6) Manual checklist

- [ ] `SONAR_TOKEN`, `SONAR_PROJECT`, `SONAR_ORG` configured in repository
- [ ] `dev` environment variables configured
- [ ] `prod` environment variables configured
- [ ] Key Vault secrets `dev-db-password` and `prod-db-password` exist
- [ ] Terraform deploy identity has `Key Vault Secrets Officer` on shared Key Vault
- [ ] PostgreSQL server + application database are created by Terraform apply
- [ ] Container App user-assigned identities have `Key Vault Secrets User` on shared Key Vault
- [ ] PR pipeline (`CI`) passed
- [ ] Push pipeline (`CI Push`) passed
- [ ] CD dev `plan/apply` passed with expected image tag
- [ ] CD prod `plan/apply` passed with digest promotion
- [ ] `/health` and `/ready` checks passed in both environments
