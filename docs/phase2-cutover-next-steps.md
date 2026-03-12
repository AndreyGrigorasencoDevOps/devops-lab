# Phase 2 Manual Cutover: Next Steps

This checklist is the practical execution guide after local code changes.

## Execution Status (as of March 12, 2026)

- `DONE`: `dev apply` completed successfully.
- `DONE`: shared self-hosted runner infrastructure exists and runner is registered online with labels `self-hosted,linux,x64,taskapi-cd,vnet`.
- `DONE`: `dev-db-password` exists and runtime DB secrets are present in dev Key Vault.
- `DONE`: `./scripts/check-post-refactor-prereqs.sh --environment dev --repo <owner/repo> --strict-runner` passes.
- `DONE`: temporary runtime mode is active in tfvars: `key_vault_network_mode = "public_allow"` (`dev` and `prod`).
- `PENDING`: one-time prod bootstrap (`taskapi-prod-kv-uks` + `prod-db-password`).
- `PENDING`: prod CD cutover (`plan` -> `apply`) with digest promotion and health validation.

## Current temporary mode is intentional

The following are temporary by design in the free-tier period:

- shared CAE model (`prod` reuses shared CAE),
- runtime Key Vault mode `public_allow` + `bypass=AzureServices`,
- shared runner platform in `eastus`,
- targeted Trivy exception for `AZU-0013`/`AVD-AZU-0013`.

Close these only after the Phase 3 migration track is complete:

1. CAE VNet migration validated for `dev` and `prod`.
2. `key_vault_network_mode` returned to `firewall` for both environments.
3. Trivy exception removed and PR + Push CI stays green.
4. Runner relocation to `uksouth` completed (after paid-tier/SKU capacity readiness).

## 0) Preconditions

- Local tools: `az`, `gh`, `terraform`.
- Azure login is active: `az login`.
- GitHub CLI auth is active: `gh auth status`.
- Current temporary runtime mode in tfvars: `key_vault_network_mode = "public_allow"` (until CAE VNet migration).
- Replace placeholders:
  - `<owner/repo>`
  - `<subscription_id>`

## 1) Prepare SSH public key for runner VM admin

Check whether you already have a public key:

```bash
ls -l ~/.ssh/*.pub
```

If you do not have a dedicated key, create one:

```bash
ssh-keygen -t ed25519 -a 64 -C "taskapi-cd-runner" -f ~/.ssh/taskapi_cd_runner
```

Print public key (this value is safe to share):

```bash
cat ~/.ssh/taskapi_cd_runner.pub
```

Never upload the private key (`~/.ssh/taskapi_cd_runner`).

## 2) Set GitHub environment variables

Set in both `dev` and `prod` environments:

```bash
gh variable set TF_SHARED_RUNNER_ADMIN_SSH_PUBLIC_KEY --repo <owner/repo> --env dev --body "$(cat ~/.ssh/taskapi_cd_runner.pub)"
gh variable set TF_SHARED_RUNNER_ADMIN_SSH_PUBLIC_KEY --repo <owner/repo> --env prod --body "$(cat ~/.ssh/taskapi_cd_runner.pub)"
```

## 3) Ensure mandatory dev DB password secret exists

If this is the first-ever bootstrap and `taskapi-dev-kv-uks` does not exist yet, create Key Vault first via targeted apply:

```bash
terraform -chdir=terraform init -backend-config=backend/dev.hcl -reconfigure
terraform -chdir=terraform plan -var-file=vars/dev.tfvars -target=azurerm_key_vault.main[0]
terraform -chdir=terraform apply -var-file=vars/dev.tfvars -target=azurerm_key_vault.main[0]
```

Create required secret:

```bash
az keyvault secret set \
  --vault-name taskapi-dev-kv-uks \
  --name dev-db-password \
  --value "<strong_password_dev>"
```

If you temporarily switch `key_vault_network_mode` back to `firewall`, add/remove your `/32` IP around this command.

## 4) Bootstrap dev infrastructure (runner path + full stack)

Export SSH public key for Terraform local run:

```bash
export TF_VAR_shared_runner_admin_ssh_public_key="$(cat ~/.ssh/taskapi_cd_runner.pub)"
```

Choose explicit image tag from latest successful `CI Push`:

```bash
IMAGE_TAG="sha-<short_sha>"
```

Run dev full plan/apply with explicit image tag:

```bash
terraform -chdir=terraform init -backend-config=backend/dev.hcl -reconfigure
terraform -chdir=terraform plan -var-file=vars/dev.tfvars -var="container_image_tag=${IMAGE_TAG}"
terraform -chdir=terraform apply -var-file=vars/dev.tfvars -var="container_image_tag=${IMAGE_TAG}"
```

First apply after this policy switch must update Key Vault network ACL from `Deny` to `Allow` for runtime compatibility.

If you temporarily test `firewall` mode, pass `-var='key_vault_allowed_ip_cidrs=["<your_ip>/32"]'` for local runs.

If this run follows a failed VNet replacement and subnets are missing in Azure, re-run apply once with forced subnet recreation:

```bash
terraform -chdir=terraform apply -var-file=vars/dev.tfvars -var="container_image_tag=${IMAGE_TAG}" -replace=azurerm_subnet.shared_runner[0] -replace=azurerm_subnet.shared_runner_private_endpoints[0]
```

Expected result:

- shared runner VNet/subnets/private DNS exist,
- runner VM exists (shared runner path in `eastus`),
- `taskapi-dev-kv-uks` exists,
- full dev stack converges without missing `dev-db-password`.

## 5) Register self-hosted runner on VM

Create repo registration token:

```bash
RUNNER_TOKEN="$(gh api -X POST /repos/<owner/repo>/actions/runners/registration-token --jq .token)"
```

Run registration script on VM using Azure Run Command:

```bash
az vm run-command invoke \
  --resource-group taskapi-dev-rg-uks \
  --name taskapi-shared-cd-runner-01 \
  --command-id RunShellScript \
  --scripts "/usr/local/bin/register-gh-runner.sh <owner/repo> ${RUNNER_TOKEN}"
```

## 6) Checkpoint flow with prereq script

Use script at these points:

1. After dev bootstrap + secret, before runner registration (relaxed mode):

```bash
./scripts/check-post-refactor-prereqs.sh --environment dev --repo <owner/repo>
```

2. After runner registration (strict mode):

```bash
./scripts/check-post-refactor-prereqs.sh --environment dev --repo <owner/repo> --strict-runner
```

3. After prod bootstrap + secret (before prod CD apply, strict mode):

```bash
./scripts/check-post-refactor-prereqs.sh --environment prod --repo <owner/repo> --strict-runner
```

4. Before each critical `plan/apply` run, re-run the same command for target env.

## 7) Deploy dev via CD

Use the same `IMAGE_TAG` (from latest successful `CI Push`) and run:

```bash
gh workflow run cd.yml --repo <owner/repo> -f environment=dev -f action=plan -f image_tag=sha-<short_sha>
gh workflow run cd.yml --repo <owner/repo> -f environment=dev -f action=apply -f image_tag=sha-<short_sha>
```

Validate health endpoints in dev (`/health`, `/ready`).

## 8) One-time prod bootstrap (minimal local bootstrap only)

For the first `prod` cutover, local bootstrap must create or reconcile the dedicated Key Vault access path resources that CD preflight expects:

- `taskapi-prod-kv-uks`,
- Key Vault private endpoint in shared runner path,
- runtime identity `taskapi-prod-ca-identity`,
- runtime `Key Vault Secrets User` role assignment on the dedicated prod vault.

If `taskapi-prod-kv-uks` does not exist yet, create the Key Vault first:

```bash
terraform -chdir=terraform init -backend-config=backend/prod.hcl -reconfigure
terraform -chdir=terraform plan -var-file=vars/prod.tfvars -target=azurerm_key_vault.main[0]
terraform -chdir=terraform apply -var-file=vars/prod.tfvars -target=azurerm_key_vault.main[0]
```

Create the mandatory DB password secret before the rest of the bootstrap:

```bash
az keyvault secret set \
  --vault-name taskapi-prod-kv-uks \
  --name prod-db-password \
  --value "<strong_password_prod>"
```

This command uses your current Azure CLI login principal. If it fails with `ForbiddenByRbac`, grant your human/bootstrap principal `Key Vault Secrets Officer` on `taskapi-prod-kv-uks`, wait for RBAC propagation, and retry.

If you temporarily switch `key_vault_network_mode` back to `firewall`, add/remove your `/32` IP around this command.

Then reconcile the remaining bootstrap resources:

```bash
terraform -chdir=terraform plan -var-file=vars/prod.tfvars \
  -target=azurerm_private_endpoint.key_vault[0] \
  -target=azurerm_user_assigned_identity.container_app \
  -target=azurerm_role_assignment.key_vault_secrets_user
terraform -chdir=terraform apply -var-file=vars/prod.tfvars \
  -target=azurerm_private_endpoint.key_vault[0] \
  -target=azurerm_user_assigned_identity.container_app \
  -target=azurerm_role_assignment.key_vault_secrets_user
```

Grant the deploy identity access to the dedicated prod vault once:

```bash
KV_ID="$(az keyvault show --name taskapi-prod-kv-uks --resource-group taskapi-prod-rg-uks --query id -o tsv)"

if [[ "$(az role assignment list --assignee "${AZURE_CLIENT_ID}" --scope "${KV_ID}" --query "[?roleDefinitionName=='Key Vault Secrets Officer'] | length(@)" -o tsv)" == "0" ]]; then
  az role assignment create \
    --assignee "${AZURE_CLIENT_ID}" \
    --role "Key Vault Secrets Officer" \
    --scope "${KV_ID}"
fi
```

Stop after this point for the one-time local bootstrap.

Do not run a local full-stack `prod` apply. After Key Vault exists and `prod-db-password` is present, continue through the normal GitHub CD flow.

## 9) Validate prod bootstrap readiness

Use the same immutable image tag that will be deployed:

```bash
IMAGE_TAG="sha-<short_sha>"
```

Optional: export deploy client id to validate deploy RBAC without warning noise in local preflight:

```bash
export AZURE_CLIENT_ID="<prod_github_oidc_app_client_id>"
```

Run prod preflight checkpoint:

```bash
./scripts/check-post-refactor-prereqs.sh --environment prod --repo <owner/repo> --strict-runner
```

Expected result:

- `taskapi-prod-kv-uks` exists,
- Key Vault private endpoint exists on the prod vault,
- `prod-db-password` exists,
- runtime identity has `Key Vault Secrets User` on the prod vault,
- deploy identity has `Key Vault Secrets Officer` on the prod vault,
- strict preflight returns without failures.

## 10) First prod cutover via GitHub CD

Run `prod plan` through GitHub Actions:

```bash
gh workflow run cd.yml --repo <owner/repo> -f environment=prod -f action=plan -f image_tag="${IMAGE_TAG}"
```

Before running `prod plan`, verify GitHub `prod` environment variables point to the current prod ACR:

- `ACR_NAME=taskapiprodacrtoibsw`
- `ACR_LOGIN_SERVER=taskapiprodacrtoibsw.azurecr.io`

Review the `prod plan` run in GitHub:

- digest promotion from DEV ACR to PROD ACR succeeds,
- no unexpected critical `destroy` / `replace`,
- preflight gate is green.

Then run `prod apply` through GitHub Actions:

```bash
gh workflow run cd.yml --repo <owner/repo> -f environment=prod -f action=apply -f image_tag="${IMAGE_TAG}"
```

Validate `/health` and `/ready` in prod after apply.

## 11) Post-cutover hygiene

- Keep `terraform/modules/` (future module reuse).
- Keep legacy layout archived only in docs (`docs/archive/terraform-environments-legacy.md`).
- Continue quarterly access review and password rotation from `docs/security-operations.md`.

## 12) Prod-ready discipline (current `public_allow` mode)

- Configure GitHub environment protection rules for `prod`:
  - required reviewers;
  - restricted deploy trigger access.
- Keep `prod destroy` as break-glass path only (manual + explicit reviewer approval).
- Keep cadence:
  - quarterly access review;
  - `prod-db-password` rotation every 90 days;
  - runner VM patch/health checks.

## 13) Phase 3 (planned): Shared CAE VNet Migration

Decision: keep shared CAE model (prod continues to use shared CAE).

1. Create a new shared CAE with VNet integration in parallel to the current shared CAE.
2. Add runtime-path private connectivity from CAE VNet to dev/prod Key Vault paths.
3. Move `dev` app to the new shared CAE and validate `/health` + `/ready`.
4. Move `prod` app to the same new shared CAE and validate `/health` + `/ready`.
5. Switch `key_vault_network_mode` back to `firewall` for `dev` and `prod`.

Phase 3 rollback:

- move apps back to previous shared CAE;
- set `key_vault_network_mode` back to `public_allow` until issue is resolved.
