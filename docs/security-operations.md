# Security Operations Playbook

This playbook defines the recurring security and operational checks for the paid-normalization target state.

## 1) Secret ownership

- Manual secret ownership:
  - `<env>-db-password` in env Key Vault (`taskapi-dev-kv-uks`, `taskapi-prod-kv-uks`)
- Terraform ownership:
  - `<env>-db-host`
  - `<env>-db-port`
  - `<env>-db-user`
  - `<env>-db-name`

## 2) Rotation runbook

Cadence:

- Prod DB password every 90 days
- Dev DB password every 90 days or immediately after incidents

Procedure:

1. Create a new secret version for `<env>-db-password`.
2. Run CD `plan` then `apply` for the same environment.
3. Validate `/ready` and DB connectivity.
4. Record evidence: workflow URL, timestamp, actor.

## 3) Access review cadence

Quarterly review checklist:

- Deploy identities:
  - confirm only `Key Vault Secrets Officer` on matching env vault scope
- Runtime identities:
  - confirm only `Key Vault Secrets User` on matching env vault scope
- Human access:
  - remove stale roles on runner RG, env RGs, Key Vault scopes
- Runner posture:
  - VM has no public IP
  - OS patches are current
  - runner service is online

## 4) Policy checks before deploy

`cd.yml` enforces preflight checks before `plan/apply` via:

```bash
./scripts/check-post-refactor-prereqs.sh --environment <dev|prod> --strict-runner
```

The gate now verifies:

- dedicated env Key Vault model (`use_shared_key_vault=false`)
- dedicated env CAE model (`use_shared_cae=false`)
- Key Vault network mode posture and expected bypass
- Key Vault private endpoint posture
- required DB password secret in the target env vault
- runtime/deploy identity role bindings on the target env vault
- shared runner VNet/private DNS prerequisites
- runtime VNet/private DNS prerequisites
- runner/runtime VNet peering
- runner VM no-public-IP posture

## 4.1) Trivy policy

- Temporary exception `AZU-0013` / `AVD-AZU-0013` remains approved only for the rollout window.
- Remove it immediately after both environments are confirmed on Key Vault `firewall` mode and Trivy stays green without the exception.
- Expected steady-state: repo and Azure both converge to Key Vault `default_action = Deny` and `bypass = None`.
- If Azure is temporarily behind repo state during rollout, do not reintroduce a long-lived ignore; use the documented rollout order and converge the infra instead.

## 5) Runner ops cadence

- Office-hours target:
  - Mon-Fri `07:00` start / `23:00` stop in `Europe/Paris`
- Patch cadence:
  - weekly Wednesday `22:00` `Europe/Paris`
- Right-sizing review:
  - monthly, using Azure Advisor plus runner utilization

Source of truth:

- `terraform/shared-ops/vars/shared.tfvars`
- `terraform/shared-ops/README.md`

## 6) Break-glass posture

- Run break-glass Terraform from `ubuntu-latest` or a trusted local shell, not from a self-hosted runner that is being replaced.
- Add a temporary `/32` allowlist only for bootstrap or incident response steps that need public Key Vault access.
- Restore the hardened `firewall` / `bypass = None` posture as soon as the incident is closed.
