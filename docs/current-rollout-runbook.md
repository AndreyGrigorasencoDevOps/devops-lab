# Current Rollout Runbook

This is the main "where am I now / what do I do next" guide for the current Azure rollout.

Use this file first.

- Reference doc: `docs/post-refactor-runbook.md`
- Historical archive: `docs/phase2-cutover-next-steps.md`

## Current snapshot (as of March 19, 2026)

- `prod` rollout already succeeded:
  - dedicated prod CAE exists
  - prod app is attached to the dedicated prod CAE
  - prod Key Vault private endpoint moved to the prod runtime subnet
  - prod `/health` and `/ready` passed
- `dev` dedicated CAE and app were already created, but the shared runner VM recreate became the main remaining blocker.
- Shared runner target is now:
  - location: `uksouth`
  - size: `Standard_F1als_v7`
  - mode: on-demand via CD (`start -> wait -> run -> deallocate`)
- `terraform/shared-ops` has not been applied yet.
- The temporary Trivy ignore is still intentionally present during the live convergence window.

## Where you are right now

If you are reading this while a local `dev` apply is running, you are at Step 1.

## Step 1 - Finish the local `dev` apply

Expected outcome:

- `taskapi-dev-app` stays attached to `taskapi-dev-cae-vnet-uks`
- shared runner VM exists in `taskapi-dev-rg-uks`
- shared runner VM target is `Standard_F1als_v7`

If this apply fails:

- stop here
- do not run `prod`
- keep the exact Terraform error output

## Step 2 - If the runner VM was recreated, register it once

Create a GitHub runner registration token:

```bash
RUNNER_TOKEN="$(gh api -X POST /repos/AndreyGrigorasencoDevOps/devops-lab/actions/runners/registration-token --jq .token)"
```

Register the runner on the VM:

```bash
az vm run-command invoke \
  --resource-group taskapi-dev-rg-uks \
  --name taskapi-shared-cd-runner-01 \
  --command-id RunShellScript \
  --scripts "/usr/local/bin/register-gh-runner.sh AndreyGrigorasencoDevOps/devops-lab ${RUNNER_TOKEN}"
```

Expected labels:

- `self-hosted`
- `linux`
- `x64`
- `taskapi-cd`
- `vnet`

## Step 3 - Validate `dev`

Get the dev FQDN:

```bash
DEV_FQDN="$(az containerapp show \
  --resource-group taskapi-dev-rg-uks \
  --name taskapi-dev-app \
  --query properties.configuration.ingress.fqdn -o tsv)"
```

Run the health checks:

```bash
curl -fsS --max-time 30 "https://${DEV_FQDN}/health"
curl -fsS --max-time 30 "https://${DEV_FQDN}/ready"
```

Optional runner VM sanity check:

```bash
az vm show \
  --resource-group taskapi-dev-rg-uks \
  --name taskapi-shared-cd-runner-01 \
  --query "{location:location,size:hardwareProfile.vmSize}" -o json
```

## Step 4 - Re-run strict preflight

```bash
./scripts/check-post-refactor-prereqs.sh --environment dev --repo AndreyGrigorasencoDevOps/devops-lab --strict-runner
./scripts/check-post-refactor-prereqs.sh --environment prod --repo AndreyGrigorasencoDevOps/devops-lab --strict-runner
```

If `strict-runner` still fails after the rollout, treat these as the main follow-up checks:

- Unable to verify `dev-db-password` or `prod-db-password` from a local shell
  - With `key_vault_network_mode = "firewall"` and `bypass = None`, this can be an expected local-firewall restriction rather than a missing secret.
  - If the app is healthy and `/ready` passes, treat this as a warning unless a Terraform plan/apply from the trusted path also fails on the same secret.
  - Only rotate or recreate the password if you have positive evidence the secret is actually missing.
- Missing shared runner peering back to the prod runtime VNet
  - Re-run a local `prod` Terraform plan/apply after secret access is validated through a trusted path.
  - The target state includes both runtime-to-runner and runner-to-runtime peering.
- Missing optional `*-db-host`, `*-db-port`, `*-db-user`, or `*-db-name`
  - These are warnings only.
  - Terraform can recreate them on the next successful apply.
- Missing `ARM_CLIENT_ID` or `AZURE_CLIENT_ID` in your local shell
  - This only prevents the script from validating deploy-identity RBAC locally.
  - It does not mean the rollout itself failed.

## Step 5 - Smoke-test the new on-demand CD runner flow

Use the latest known-good immutable image tag:

```bash
IMAGE_TAG="sha-<short_sha>"
```

Trigger a `dev` plan run:

```bash
gh workflow run cd.yml \
  --repo AndreyGrigorasencoDevOps/devops-lab \
  -f environment=dev \
  -f action=plan \
  -f image_tag="${IMAGE_TAG}"
```

What should happen:

- hosted job starts the runner VM
- runner comes online
- Terraform runs on self-hosted
- hosted cleanup job deallocates the VM

Optional post-run VM check:

```bash
az vm get-instance-view \
  --resource-group taskapi-dev-rg-uks \
  --name taskapi-shared-cd-runner-01 \
  --query "instanceView.statuses[?starts_with(code, 'PowerState/')].code | [0]" -o tsv
```

Expected result:

- `PowerState/deallocated`

## Step 6 - Apply shared ops

Do this after the runner flow is stable:

```bash
terraform -chdir=terraform/shared-ops init -backend-config=backend/shared.hcl -reconfigure
terraform -chdir=terraform/shared-ops plan -var-file=vars/shared.tfvars
terraform -chdir=terraform/shared-ops apply -var-file=vars/shared.tfvars
```

## Step 7 - Later follow-up

- Optional: deploy office-hours automation from the shared-ops schedule metadata.
- Later: remove the temporary Trivy ignore only after both environments are confirmed on the hardened Key Vault posture and CI stays green without it.
- Later: record patch evidence and monthly Azure Advisor right-sizing review.

## What you do not need to repeat right now

- You do not need to rerun the old Phase 2 manual cutover steps.
- You do not need to recreate the prod CAE again unless a new plan shows real drift.
- You do not need Spot runner changes for this rollout.

## Doc roles

- `docs/current-rollout-runbook.md`
  - current live rollout checklist
- `docs/post-refactor-runbook.md`
  - broader reference and operations background
- `docs/phase2-cutover-next-steps.md`
  - historical archive from the earlier free-tier/manual cutover phase
