# Security Operations Playbook

This playbook defines recurring security operations for Stage 9.

## 1) Secret ownership

- Manual secret ownership:
  - `<env>-db-password` in env Key Vault (`taskapi-dev-kv-uks`, `taskapi-prod-kv-uks`).
- Terraform ownership:
  - `<env>-db-host`
  - `<env>-db-port`
  - `<env>-db-user`
  - `<env>-db-name`

## 2) Rotation runbook

Cadence:

- Prod DB password every 90 days.
- Dev DB password every 90 days or immediately after incidents.

Procedure:

1. Create new secret version for `<env>-db-password` in env Key Vault.
2. Run CD `plan` then `apply` for the same environment.
3. Validate `/ready` and DB connectivity.
4. Record rotation evidence: workflow run URL, timestamp, actor.

## 3) Access review cadence

Quarterly review checklist:

- Deploy identities:
  - confirm only `Key Vault Secrets Officer` on matching env vault scope.
- Runtime identities:
  - confirm only `Key Vault Secrets User` on matching env vault scope.
- Human access:
  - remove stale roles on runner RG, env RGs, Key Vault scopes.
- Runner posture:
  - VM has no public IP, OS patches applied, runner service online.

## 4) Policy checks before deploy

`cd.yml` enforces preflight checks before `plan/apply` via:

```bash
./scripts/check-post-refactor-prereqs.sh --environment <dev|prod> --strict-runner
```

Current gate verifies:

- dedicated env Key Vault model (`use_shared_key_vault=false`)
- Key Vault network mode posture (`public_allow` now, `firewall` after CAE VNet migration) + private endpoint
- required DB password secret in target env vault
- runtime/deploy identity role bindings on target env vault
- shared runner VNet/private DNS prerequisites
- runner VM no-public-IP posture

## 4.1) Temporary Trivy exception policy

- Allowed temporary exception: only `AZU-0013` / `AVD-AZU-0013`.
- Scope: PR + Push `Trivy config scan`; Trivy remains blocking for all other findings.
- Source of truth: repository root `.trivyignore`.
- Removal trigger: complete Phase 3/paid normalization milestone where runtime Key Vault mode returns to `firewall` (`default_action = Deny`) for both environments.

## 5) Prod-ready discipline (current runtime mode)

While `key_vault_network_mode = public_allow` is active:

- enforce GitHub `prod` environment protection rules:
  - required reviewers;
  - restricted users/teams allowed to run deployment.
- keep `prod destroy` for break-glass only (manual + reviewer approval).
- keep ops cadence:
  - quarterly access review evidence;
  - 90-day rotation evidence for `prod-db-password`;
  - runner VM patch and service-status checks.

## 6) Phase 3 transition track (planned)

Target: shared CAE with VNet integration, then return Key Vault mode to `firewall`.

1. Build new shared CAE with VNet integration.
2. Wire runtime private access path from CAE VNet to Key Vault.
3. Cut over `dev`, validate, then cut over `prod`.
4. Set `key_vault_network_mode = firewall` for both environments.

Rollback:

- revert apps to previous shared CAE;
- temporarily restore `key_vault_network_mode = public_allow`.
