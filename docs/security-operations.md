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

- No temporary exception for `AZU-0013` / `AVD-AZU-0013` should remain in steady state.
- Expected posture: repo and Azure both converge to Key Vault `default_action = Deny` and `bypass = None`.
- The Terraform default for `key_vault_network_mode` should stay on `firewall`; use `public_allow` only as a short-lived break-glass override.
- If this policy fails again, fix the infrastructure drift or Terraform intent instead of reintroducing a long-lived ignore.

## 5) Runner ops cadence

- Primary cost-control path:
  - CD boots the shared runner only when needed and deallocates it after each run
  - deallocation stops VM compute charges, but OS disk charges continue
- Lightweight reminder:
  - keep the runner OS patched when needed
  - sanity-check runner size only if cost or performance starts looking wrong

Source of truth:

- this runbook
- `docs/ROADMAP.md`

## 6) Break-glass posture

- Run break-glass Terraform from `ubuntu-latest` or a trusted local shell, not from a self-hosted runner that is being replaced.
- Add a temporary `/32` allowlist only for bootstrap or incident response steps that need public Key Vault access.
- Restore the hardened `firewall` / `bypass = None` posture as soon as the incident is closed.
