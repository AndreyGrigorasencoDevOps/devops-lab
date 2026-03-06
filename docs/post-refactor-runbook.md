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

## 2.3 Database provisioning model

Database is now Terraform-managed:

- Terraform creates Azure Database for PostgreSQL Flexible Server.
- Terraform creates the application database (`taskdb` by default).
- Terraform injects required runtime variables into Container App automatically:
  - `DB_HOST`
  - `DB_PORT`
  - `DB_USER`
  - `DB_PASSWORD`
  - `DB_NAME`

Manual DB secret creation in Key Vault is no longer required for first startup.

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
  --kv-rg taskapi-dev-rg-uks
```

The script validates:

- GitHub Sonar secret/variables
- GitHub env variables (`dev` + `prod`)
- shared Key Vault existence
- `Key Vault Secrets User` role on Container App managed identities (dev/prod)

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
- [ ] PostgreSQL server + application database are created by Terraform apply
- [ ] Container App managed identities have `Key Vault Secrets User` on shared Key Vault
- [ ] PR pipeline (`CI`) passed
- [ ] Push pipeline (`CI Push`) passed
- [ ] CD dev `plan/apply` passed with expected image tag
- [ ] CD prod `plan/apply` passed with digest promotion
- [ ] `/health` and `/ready` checks passed in both environments
