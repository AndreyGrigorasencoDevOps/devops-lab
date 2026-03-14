# Post-Refactor Runbook

This runbook is the operational baseline after Stage 9 Phase 2 hardening.

For a step-by-step cutover execution checklist, use `docs/phase2-cutover-next-steps.md`.

## 0) Current execution status (as of March 13, 2026)

- `DONE`: Phase 2 cutover is operational in `dev` (runner online, strict preflight passing, dev apply successful).
- `DONE`: one-time prod bootstrap completed (`taskapi-prod-kv-uks` + `prod-db-password` + dedicated prod vault RBAC).
- `DONE`: first prod CD cutover completed successfully (`plan` -> `apply` with digest promotion).
- `DONE`: GitHub `prod` environment protection rules are enabled (required reviewer path active).
- `DECISION`: keep shared CAE model (`prod` continues to use shared CAE in this phase).

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
- Key Vault network mode: `public_allow` (temporary runtime compatibility until CAE VNet migration).
- Key Vault private endpoint enabled for each environment.
- Shared runner VNet + private DNS zone:
  - DNS zone: `privatelink.vaultcore.azure.net`
  - current shared runner location: `eastus` (app/runtime stays in `uksouth`)
- Runtime compatibility mode remains pragmatic:
  - Key Vault `bypass = AzureServices` is intentionally retained until Container Apps VNet migration.

## 1.2 Temporary deviations and closure triggers

Temporary constraints are tracked in the roadmap register:

- `docs/ROADMAP.md` -> `Temporary Constraints Register (Free-tier period)`.

Closure order (do not reorder):

1. Complete shared CAE VNet migration and validate `dev`/`prod` runtime path.
2. Switch `key_vault_network_mode` from `public_allow` to `firewall` in both tfvars and run converging applies.
3. Remove temporary Trivy exception (`AZU-0013`/`AVD-AZU-0013`) and confirm PR + Push workflows stay green.
4. Relocate shared runner platform from `eastus` to `uksouth` when subscription/SKU capacity allows.

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

Current default mode is `public_allow`, so bootstrap secrets directly:

```bash
az keyvault secret set --vault-name taskapi-dev-kv-uks --name dev-db-password --value "<strong_password_dev>"
az keyvault secret set --vault-name taskapi-prod-kv-uks --name prod-db-password --value "<strong_password_prod>"
```

Important:

- `az keyvault secret set` uses your current Azure CLI login principal, not the GitHub deploy identity.
- Your human/bootstrap principal needs `Key Vault Secrets Officer` (or broader equivalent) on the target vault scope before manual secret bootstrap will work.

If you temporarily switch network mode to `firewall`, add/remove your local `/32` allowlist around bootstrap and local Terraform runs.

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
- Before first full `dev` plan/apply, ensure `dev-db-password` already exists in `taskapi-dev-kv-uks`.
- Before first full `prod` plan/apply, run one-time local bootstrap for:
  - dedicated prod Key Vault,
  - manual `prod-db-password` secret creation before bootstrap steps that read DB password data,
  - prod Key Vault private endpoint,
  - runtime identity + `Key Vault Secrets User` assignment,
  - manual deploy identity `Key Vault Secrets Officer` assignment,
  - strict preflight validation before GitHub CD.
- After switching tfvars to `key_vault_network_mode = public_allow`, run one apply per env to converge Key Vault ACL from `Deny` to `Allow`.
- For local Terraform `plan/apply`, always pass explicit `-var="container_image_tag=sha-<short_sha>"` (do not rely on default `dev` tag).
- For local Terraform runs in temporary `firewall` mode, also pass `-var='key_vault_allowed_ip_cidrs=["<your_ip>/32"]'`.

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
./scripts/check-post-refactor-prereqs.sh --environment dev
./scripts/check-post-refactor-prereqs.sh --environment dev --strict-runner
./scripts/check-post-refactor-prereqs.sh --environment prod --strict-runner
```

Preflight sequencing:

- Use relaxed mode (`without --strict-runner`) before runner registration.
- Use strict mode (`with --strict-runner`) after runner registration and before every `plan/apply`.

The preflight validates:

- target env uses dedicated Key Vault (not shared)
- approved Key Vault network mode (`public_allow` now, `firewall` later) + private endpoint posture
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
2. Keep (or revert to) `key_vault_network_mode = public_allow` in target tfvars.
3. Run `plan` then `apply` for affected environment.
4. Restore hardened configuration after incident is resolved (for example, after CAE VNet migration to support `firewall` mode).

Do not destroy dedicated Key Vaults during rollback.

## 8) Prod-ready discipline (while runtime mode is `public_allow`)

- GitHub `prod` environment protection rules are active:
  - required reviewers are active;
  - deploy access is environment-gated.
- Keep `prod destroy` as break-glass only with explicit reviewer check.
- Maintain operating cadence:
  - quarterly access review;
  - 90-day prod DB password rotation;
  - runner VM patch + service health review.

## 9) Next phase: Shared CAE VNet migration (planned)

Goal: move runtime path to private connectivity and return Key Vault mode to `firewall`.

1. Create a new shared CAE with VNet integration (parallel to current shared CAE).
2. Add runtime private path from CAE VNet to Key Vault access for `dev` and `prod`.
3. Migrate `dev` app to new shared CAE; validate health/readiness.
4. Migrate `prod` app to new shared CAE; validate health/readiness.
5. Switch `dev/prod` tfvars from `public_allow` back to `firewall`.

Rollback:

- move apps back to previous shared CAE;
- restore `key_vault_network_mode = public_allow`.
