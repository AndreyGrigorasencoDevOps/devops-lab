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
- CD now exports Terraform runtime vars for Key Vault mode and RBAC stabilization:
  - `TF_VAR_key_vault_network_mode` (Phase 1 default: `public_allow`)
  - `TF_VAR_rbac_propagation_wait_seconds` (default: `45`)
- Runner-IP firewall allowlist steps exist in workflow for future hardening mode (`firewall`) but are disabled in current Phase 1 mode.

## 1.1 CD reconcile policy

Operational intent:

- Standard deploy/sync uses `action=plan` then `action=apply`.
- `action=apply` is the reconcile operation:
  - creates resources missing from infra/state
  - updates drifted/outdated managed resources
  - replaces resources when Terraform marks them `-/+` (ForceNew cases)
  - destroys managed resources removed from Terraform configuration
- `action=destroy` is a full environment reset for that state, not partial cleanup.

Plan interpretation:

- `+ create`: resource will be created.
- `~ update`: resource will be updated in-place.
- `-/+ replace`: resource will be destroyed and recreated.
- `- destroy` during `apply`: managed resource no longer in config and will be removed from infra.
- Resources created outside Terraform state are not removed by `apply`.

## 1.2 Two-phase Key Vault operating model

Current mode (Phase 1, active):

- Key Vault access model: `RBAC-only + public allow`.
- Goal: stable deploys from GitHub-hosted runners and reliable Container App secret resolution.
- Terraform includes a deterministic RBAC propagation wait before Container App revision updates.

Target mode (Phase 2, planned):

- Self-hosted GitHub runner in Azure VNet for Terraform/CD jobs.
- Key Vault private access model (`firewall` + private endpoint + private DNS).
- Split Key Vault per environment (dev/prod), while CAE stays shared due trial limits.

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

3. (Optional, firewall mode only) Grant management-plane rights to modify Key Vault firewall rules:

```bash
az role assignment create \
  --assignee <azure_client_id_for_env> \
  --role "Key Vault Contributor" \
  --scope "/subscriptions/<sub_id>/resourceGroups/<kv_rg>/providers/Microsoft.KeyVault/vaults/<shared_kv_name>"
```

Notes:

- Container App user-assigned identity gets `Key Vault Secrets User` from Terraform.
- `Key Vault Contributor` is optional in current Phase 1 (`public_allow`). Keep it for future `firewall` mode or if you intentionally enable firewall automation.
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
4. Run CD `dev plan` with that `image_tag` and review for unexpected `destroy/replace` on critical resources.
5. Run CD `dev apply` with the same `image_tag`.
6. Validate runtime:
   - `GET /health` returns 200
   - `GET /ready` returns 200
7. Run CD `prod plan` with the same `image_tag` and review diff.
8. Run CD `prod apply` with the same `image_tag`.
9. Re-check `/health` and `/ready` in prod.

Use `destroy` only for intentional full reset (dev/prod), not as part of normal release flow.

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
- [ ] (Optional in Phase 1) Terraform deploy identity has `Key Vault Contributor` for firewall allowlist automation
- [ ] PostgreSQL server + application database are created by Terraform apply
- [ ] Container App user-assigned identities have `Key Vault Secrets User` on shared Key Vault
- [ ] PR pipeline (`CI`) passed
- [ ] Push pipeline (`CI Push`) passed
- [ ] CD dev `plan/apply` passed with expected image tag
- [ ] CD prod `plan/apply` passed with digest promotion
- [ ] `/health` and `/ready` checks passed in both environments

## 7) Phase 2 migration checklist (private Key Vault + self-hosted runner)

- [ ] Provision self-hosted GitHub runner in Azure VNet and register runner labels.
- [ ] Create dedicated dev/prod Key Vaults and migrate secrets from shared vault.
- [ ] Add Key Vault private endpoints and private DNS linkage for runner/ACA path.
- [ ] Switch `key_vault_network_mode` to `firewall` in Terraform vars.
- [ ] Update `cd.yml` Terraform jobs to run on self-hosted runner labels.
- [ ] Re-run `dev plan/apply`, then `prod plan/apply`, and verify app secret resolution.

## 8) Validation scenarios

1. Add or modify a managed resource parameter, run `plan`, confirm `create/update`, then `apply` succeeds.
2. Remove a managed resource from Terraform config, run `plan`, confirm `destroy`, then `apply` removes only that managed resource.
3. Change a ForceNew parameter, run `plan`, confirm `-/+ replace`, then `apply` recreates resource successfully.
4. Run `destroy` only as explicit reset and verify it is never used in normal release sequence.
