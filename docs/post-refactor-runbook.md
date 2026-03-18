# Post-Refactor Runbook

This runbook is the operational baseline after the paid-normalization repo changes landed.

The repository now targets:

- dedicated CAE per environment
- env-local runtime VNets in `uksouth`
- env-local Key Vault private endpoints
- `key_vault_network_mode = "firewall"` with `bypass = None`
- shared runner target location `uksouth`
- shared-ops budget metadata under `terraform/shared-ops/`
- shared runner target size `Standard_B1s`

Important:

- The repo target state is ahead of the currently deployed Azure state until you run the rollout sequence below.
- Use `docs/phase2-cutover-next-steps.md` only as historical context; it no longer reflects the active target architecture.

## 0) Current execution status (as of March 17, 2026)

- `DONE`: Phase 2 cutover remains the last confirmed Azure baseline.
- `DONE`: Repo configuration now targets paid normalization.
- `DONE`: shared runner target size has been reduced to `Standard_B1s` for cost control.
- `NEXT`: converge Azure in this order: `dev`, `prod`, shared runner relocation, shared-ops apply.

## 0.1 Repo QA status

Cross-checks already completed in the repository:

- `terraform fmt -recursive terraform`
- `terraform -chdir=terraform validate`
- `terraform -chdir=terraform/shared-ops validate`
- `bash -n scripts/check-post-refactor-prereqs.sh`
- `git diff --check`

What is still pending because it requires live Azure execution:

- `dev` rollout to the dedicated CAE/runtime VNet target
- `prod` rollout to the dedicated CAE/runtime VNet target
- shared runner relocation to `uksouth`
- shared-ops `apply`
- health/readiness validation after each environment cutover
- runner private DNS validation after Key Vault PE migration
- Azure Start/Stop VMs off-hours automation deployment

## 1) Automation baseline

- `CI` workflow (`.github/workflows/ci.yml`) runs on PRs to `main`.
- `CI Push` workflow (`.github/workflows/ci-push.yml`) runs on `push` to `main` and publishes immutable `sha-<short_sha>` image tags.
- `CD` workflow (`.github/workflows/cd.yml`) remains manual (`workflow_dispatch`) and keeps digest promotion for prod.
- Terraform jobs in CD run on self-hosted runner labels:
  - `self-hosted`, `linux`, `x64`, `taskapi-cd`, `vnet`
- CD enforces preflight before `plan/apply`:
  - `./scripts/check-post-refactor-prereqs.sh --environment <dev|prod> --strict-runner`

## 1.1 Target security model

- Dedicated Key Vault per environment:
  - `taskapi-dev-kv-uks`
  - `taskapi-prod-kv-uks`
- Dedicated runtime VNet per environment:
  - `taskapi-dev-rt-vnet-uks`
  - `taskapi-prod-rt-vnet-uks`
- Dedicated CAE per environment:
  - `taskapi-dev-cae-vnet-uks`
  - `taskapi-prod-cae-vnet-uks`
- Shared runner VNet + private DNS zone:
  - DNS zone: `privatelink.vaultcore.azure.net`
  - target shared runner location: `uksouth`
  - target shared runner VM size: `Standard_B1s`
- Steady-state Key Vault posture:
  - `default_action = Deny`
  - `bypass = None`

## 1.2 Rollout order

Do not reorder these steps:

1. Apply `dev` and validate runtime/private-path health.
2. Apply `prod` and validate runtime/private-path health.
3. Relocate the shared runner from `eastus` to `uksouth`.
4. Apply the shared-ops layer and operationalize the runner office-hours schedule and patch cadence.

Important nuance:

- The shared runner platform is still owned by the `dev` Terraform state.
- Because the repo target for `shared_runner_location` is now `uksouth`, a full `dev` apply can include the runner relocation unless you intentionally defer it.
- If you want to keep the rollout in the exact phase order above, run the pre-relocation `dev` plan/apply with a temporary override:
  - `-var="shared_runner_location=eastus"`
- Then run the dedicated runner-relocation apply later from a trusted local shell without that override.

## 1.3 Why `terraform/shared-ops` exists

The env root under `terraform/` still manages environment-bound infrastructure such as app, DB, Key Vault, CAE, runtime VNet, and the shared runner VM itself.

`terraform/shared-ops/` was added for subscription-scoped operational controls that do not belong to either the `dev` state or the `prod` state:

- monthly subscription budget
- budget notification contacts
- runner office-hours metadata
- runner patch/right-sizing metadata

This split keeps shared operational controls in their own Terraform state so that:

- `dev` and `prod` plans stay focused on runtime infrastructure
- shared cost-control changes do not create noise or drift in env applies
- subscription-scope artifacts are not awkwardly "owned" by one environment by accident

## 2) One-time setup

### 2.1 GitHub environment variables (`dev` and `prod`)

Required in each GitHub environment:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ACR_NAME`
- `ACR_LOGIN_SERVER`
- `TF_APP_ENV_VARS_JSON` (optional)
- `TF_SHARED_RUNNER_ADMIN_SSH_PUBLIC_KEY`

### 2.2 Key Vault DB password bootstrap

Repo tfvars now target `firewall`, so the first converging applies may require a temporary local `/32` allowlist for bootstrap work.

```bash
az keyvault secret set --vault-name taskapi-dev-kv-uks --name dev-db-password --value "<strong_password_dev>"
az keyvault secret set --vault-name taskapi-prod-kv-uks --name prod-db-password --value "<strong_password_prod>"
```

Important:

- `az keyvault secret set` uses your Azure CLI principal, not the GitHub deploy identity.
- Your bootstrap principal needs `Key Vault Secrets Officer` (or broader equivalent) on the target vault scope.
- If bootstrap or local Terraform hits `ForbiddenByFirewall`, temporarily add your `/32` to `key_vault_allowed_ip_cidrs`, complete the step, then remove it.

Terraform continues to manage runtime metadata secrets automatically:

- `<env>-db-host`
- `<env>-db-port`
- `<env>-db-user`
- `<env>-db-name`

## 3) Deployment sequence

Bootstrap note:

- If the shared runner must be recreated, do that step from a trusted local shell or temporary break-glass GitHub-hosted runner, not from the self-hosted runner being replaced.
- Before the first full `dev` plan/apply, ensure `dev-db-password` already exists.
- Before the first full `prod` plan/apply, ensure `prod-db-password` already exists.
- For local Terraform `plan/apply`, always pass explicit `-var="container_image_tag=sha-<short_sha>"`.
- The new budget runner bootstrap now adds a `2 GiB` swap file; that safeguard takes effect when the runner VM is recreated or relocated.

1. Merge to `main` and capture `image_tag` from the `CI Push` summary.
2. Run `dev` `plan` and `apply` with that image tag.
3. Validate `dev` `/health` and `/ready`.
4. From the runner path, confirm private DNS resolution for `taskapi-dev-kv-uks`.
5. Run `prod` `plan` and `apply` with the same image tag.
6. Validate `prod` `/health` and `/ready`.
7. From a non-self-hosted path, relocate the shared runner to `uksouth`.
8. Apply the shared-ops layer:

```bash
terraform -chdir=terraform/shared-ops init -backend-config=backend/shared.hcl -reconfigure
terraform -chdir=terraform/shared-ops apply -var-file=vars/shared.tfvars
```

9. Deploy Azure Start/Stop VMs during off-hours using the metadata in `terraform/shared-ops/vars/shared.tfvars`.

## 3.1 Exact next steps to make the rollout work

Use this checklist in order:

1. Ensure `TF_SHARED_RUNNER_ADMIN_SSH_PUBLIC_KEY` is present in both GitHub environments.
2. Ensure `dev-db-password` and `prod-db-password` exist in their dedicated Key Vaults.
3. Merge the repo state to `main` and capture the immutable `sha-<short_sha>` image tag from `CI Push`.
4. From a trusted local shell, run `dev` `plan`, then `dev` `apply`, using a temporary `-var="shared_runner_location=eastus"` override if you want to postpone the runner move until the dedicated relocation step.
5. Validate `dev`:
   - `GET /health` returns `200`
   - `GET /ready` returns `200`
   - preflight passes with `--strict-runner`
   - Key Vault resolves privately from the runner path
6. Run `prod` `plan`, then `prod` `apply`, using the same image tag.
7. Validate `prod` with the same checks.
8. From a non-self-hosted path, relocate the shared runner so the new `Standard_B1s` VM lands in `uksouth`.
9. Re-register the GitHub runner if needed and confirm labels:
   - `self-hosted`, `linux`, `x64`, `taskapi-cd`, `vnet`
10. Apply `terraform/shared-ops`.
11. Deploy Azure Start/Stop VMs off-hours automation using the schedule values from `terraform/shared-ops/vars/shared.tfvars`.
12. Record the first patch window and the first monthly Azure Advisor right-sizing review.

## 4) Mandatory preflight checks

Local/manual:

```bash
./scripts/check-post-refactor-prereqs.sh --environment dev
./scripts/check-post-refactor-prereqs.sh --environment dev --strict-runner
./scripts/check-post-refactor-prereqs.sh --environment prod --strict-runner
```

The preflight now validates:

- dedicated Key Vault per env
- dedicated CAE per env
- expected Key Vault mode and bypass for that env
- DB password secret presence
- runtime/deploy identity RBAC on the env Key Vault
- shared runner VNet/private DNS linkage
- runtime VNet/private DNS linkage
- runner/runtime VNet peering
- Key Vault private endpoint placement in the env runtime PE subnet
- runner VM no-public-IP posture
- optional GitHub runner registration status by labels

## 5) Secret rotation and ownership model

Ownership:

- `*-db-password`: platform owner rotates manually in Key Vault.
- `*-db-host/port/user/name`: Terraform-owned runtime metadata.

Rotation steps:

1. Set a new version for `<env>-db-password` in the env Key Vault.
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

1. Temporarily switch CD Terraform jobs to `ubuntu-latest` or use a trusted local shell.
2. Add a temporary local `/32` allowlist only if bootstrap access is required.
3. Run `plan` then `apply` for the affected environment.
4. Restore the hardened `firewall` / `bypass = None` posture after the incident is resolved.

Do not destroy dedicated Key Vaults during rollback.

## 8) Ongoing operations

- Keep GitHub `prod` environment protection rules enabled.
- Keep `prod destroy` as break-glass only with explicit reviewer check.
- Maintain the following cadence:
  - quarterly access review
  - 90-day DB password rotation
  - runner office-hours schedule review
  - weekly Wednesday `22:00` `Europe/Paris` patch window
  - monthly Azure Advisor runner right-sizing review
