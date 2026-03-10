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
- Key Vault firewall + private endpoint posture
- required DB password secret in target env vault
- runtime/deploy identity role bindings on target env vault
- shared runner VNet/private DNS prerequisites
- runner VM no-public-IP posture
