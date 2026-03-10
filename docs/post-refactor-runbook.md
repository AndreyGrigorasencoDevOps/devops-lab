# Post-Refactor Runbook

This runbook is the operational baseline after Stage 9 Phase 2 hardening.

## 1) Current automation baseline

- `CI` workflow (`.github/workflows/ci.yml`) runs on PRs to `main`.
- `CI Push` workflow (`.github/workflows/ci-push.yml`) runs on `push` to `main` and publishes immutable `sha-<short_sha>` image tags.
- `CD` workflow (`.github/workflows/cd.yml`) is manual (`workflow_dispatch`) and keeps digest promotion for prod.
- Terraform jobs in CD run on self-hosted runner labels:
  - `self-hosted`, `linux`, `x64`, `taskapi-cd`, `vnet`
- CD enforces preflight security checks before `plan/apply`:
  - `./scripts/check-post-refactor-prereqs.sh --environment <dev|prod> --strict-runner`

## 1.1 Security operating model (active)

- Dedicated Key Vault per environment:
  - `taskapi-dev-kv-uks`
  - `taskapi-prod-kv-uks`
- Key Vault network mode: `firewall` (`defaultAction=Deny`).
- Key Vault private endpoint enabled for each environment.
- Shared runner VNet + private DNS zone:
  - DNS zone: `privatelink.vaultcore.azure.net`
- Runtime compatibility mode remains pragmatic:
  - Key Vault `bypass = AzureServices` is intentionally retained until Container Apps VNet migration.

## 2) One-time setup (required)

## 2.1 GitHub environment variables (`dev` and `prod`)

Required in each GitHub environment:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ACR_NAME`
- `ACR_LOGIN_SERVER`
- `TF_APP_ENV_VARS_JSON` (optional)
- `TF_SHARED_RUNNER_ADMIN_SSH_PUBLIC_KEY` (required when creating/updating shared runner VM)

## 2.2 Key Vault DB password bootstrap

Create manual source-of-truth DB password secrets in dedicated vaults:

```bash
az keyvault secret set --vault-name taskapi-dev-kv-uks --name dev-db-password --value "<strong_password_dev>"
az keyvault secret set --vault-name taskapi-prod-kv-uks --name prod-db-password --value "<strong_password_prod>"
```

Terraform manages runtime secrets automatically:

- `<env>-db-host`
- `<env>-db-port`
- `<env>-db-user`
- `<env>-db-name`

## 2.3 Required Azure RBAC

For each environment (`dev`, `prod`):

- Deploy identity (GitHub OIDC app/service principal):
  - `Key Vault Secrets Officer` on environment Key Vault scope.
- Runtime user-assigned identity (`<project>-<env>-ca-identity`):
  - `Key Vault Secrets User` on environment Key Vault scope.

## 3) Deployment sequence

Bootstrap note:

- If shared runner infrastructure does not exist yet, run initial `dev` Terraform apply once from a trusted local shell (or temporary break-glass `ubuntu-latest`) to create runner VNet/VM/DNS assets first.

1. Merge to `main` and capture `image_tag` from `CI Push` summary.
2. Run CD `dev plan` with that image tag.
3. Run CD `dev apply` with the same image tag.
4. Validate dev endpoints: `/health` and `/ready` return `200`.
5. Run CD `prod plan` with the same image tag.
6. Run CD `prod apply` with the same image tag.
7. Validate prod endpoints: `/health` and `/ready` return `200`.

CLI examples:

```bash
gh workflow run cd.yml -f environment=dev -f action=plan -f image_tag=sha-<short_sha>
gh workflow run cd.yml -f environment=dev -f action=apply -f image_tag=sha-<short_sha>
gh workflow run cd.yml -f environment=prod -f action=plan -f image_tag=sha-<short_sha>
gh workflow run cd.yml -f environment=prod -f action=apply -f image_tag=sha-<short_sha>
```

## 4) Mandatory preflight checks

Local/manual:

```bash
./scripts/check-post-refactor-prereqs.sh --environment dev --strict-runner
./scripts/check-post-refactor-prereqs.sh --environment prod --strict-runner
```

The preflight validates:

- target env uses dedicated Key Vault (not shared)
- `firewall` + private endpoint posture for Key Vault
- required DB password secret in env Key Vault
- runtime/deploy identity RBAC on env Key Vault
- shared runner VNet/subnets/private DNS linkage
- runner VM no-public-IP posture
- optional GitHub runner registration status by labels

## 5) Secret rotation and ownership model

Ownership:

- `*-db-password`: platform owner rotates manually in Key Vault.
- `*-db-host/port/user/name`: Terraform-owned runtime metadata.

Rotation SLA:

- Production DB password rotation every 90 days.
- Dev DB password rotation every 90 days or on-demand after incidents.

Rotation steps:

1. Set a new version for `<env>-db-password` in env Key Vault.
2. Run CD `plan` then `apply` for the same env.
3. Verify `/ready` and application DB connectivity.
4. Record rotation date and actor in ops notes.

## 6) Access review cadence

Quarterly checklist:

- Deploy identities: confirm only required Key Vault role assignments remain.
- Runtime identities: confirm `Key Vault Secrets User` only on same-env vault.
- Human principals/groups: remove stale privileged assignments.
- Runner VM: confirm no public IP, latest OS patches, and runner service online.

## 7) Break-glass rollback

If emergency rollback is needed:

1. Temporarily switch CD Terraform jobs to `ubuntu-latest`.
2. Temporarily set `key_vault_network_mode = public_allow` in target tfvars.
3. Run `plan` then `apply` for affected environment.
4. Restore hardened configuration after incident is resolved.

Do not destroy dedicated Key Vaults during rollback.
