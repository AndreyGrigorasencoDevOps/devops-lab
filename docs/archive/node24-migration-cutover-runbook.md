# Archived Node 24 Migration Cutover Runbook

Historical notes from the staged Node 24 migration rollout. The platform now runs on Node 24 by default, so this document is kept only as archived implementation context.

## Current State

- App support is widened to Node `>=20 <25`.
- Default local/runtime baseline is still Node 20.
- PR and push CI validate Node 20 and Node 24.
- Docker smoke tests validate `node:20-alpine` and `node:24-alpine`.
- There is a PR-only Node 24 Actions canary workflow.
- CD has an opt-in `actions_node24_canary` input that forces JavaScript Actions onto Node 24 for a manual run.
- The shared runner bootstrap script now pins Actions Runner `2.330.0`.

## Immediate Next Steps

1. Keep the PR title in conventional-commit format.
   Use `type: summary`, not `type/summary`.

2. Use this PR title:
   `ci: stage 1 Node 24 migration readiness`

3. After the PR is updated, rerun the failed checks.

4. Refresh the shared runner VM operationally before trusting self-hosted CD canaries.
   Terraform will not automatically apply the new runner bootstrap script to the existing VM because the VM resource ignores `custom_data` changes.

5. Run a manual DEV CD canary with:
   - `environment=dev`
   - `action=plan`
   - `actions_node24_canary=true`

6. If the DEV plan is clean, run a DEV apply canary with the same flag.

7. Run one manual PROD `plan` with `actions_node24_canary=true`.

## Stage 1

Goal: make Actions and CI ready for the Node 24 runner transition without changing the production runtime baseline.

Expected outcome:

- PR CI is green on Node 20 and Node 24.
- Push CI is green on Node 20 and Node 24.
- Docker smoke passes on Node 20 and Node 24.
- PR-only Node 24 Actions canary is green.
- Manual CD canaries are green after the shared runner VM is refreshed.

Checklist:

- `actions/checkout`, `actions/setup-node`, and `actions/upload-artifact` are on Node 24-ready majors.
- Shared runner bootstrap pin is updated.
- Hosted CI matrix is active.
- CD opt-in Actions canary is active.

## Stage 2

Goal: soak in dual-support mode.

Keep this state for at least a short stabilization window:

- Leave Node 20 as the default local/runtime baseline.
- Keep CI on Node 20 and Node 24.
- Keep the PR-only Node 24 Actions canary enabled.
- Watch for failures in:
  - `azure/login`
  - `hashicorp/setup-terraform`
  - `actions/dependency-review-action`
  - any other JavaScript-based action that GitHub starts forcing onto Node 24

Suggested exit criteria:

- multiple clean PRs
- at least one clean DEV CD canary plan/apply
- at least one clean PROD CD canary plan

## Stage 3

Goal: full Node 24 cutover.

When Stage 2 is stable:

1. Change `.nvmrc` to Node 24.
2. Change the default Docker base image to Node 24.
3. Keep the CI matrix temporarily or simplify CI to Node 24 only.
4. Optionally tighten `package.json` to Node `>=24 <25`.
5. Remove the separate Node 24 Actions canary workflow once normal CI/CD is stable without it.

## PR Title Guidance

Valid examples:

- `ci: stage 1 Node 24 migration readiness`
- `ci: add Node 24 canary coverage`
- `build: prepare workflows for Node 24 actions`

Invalid example:

- `refactor/node-migration-to-v24_stage1`

Why it failed:

- The semantic PR title check expects a conventional-commit prefix followed by a colon.
- The slash form is not parsed as a release type.

## Suggested PR Description

```md
## Summary
- prepare CI and CD for the Node 24 GitHub Actions transition
- validate the app on Node 20 and Node 24 in hosted CI
- add a PR-only Node 24 Actions canary workflow
- bump the shared runner bootstrap to a newer GitHub Actions runner version
- keep the default local and runtime baseline on Node 20 during the staged rollout

## Testing
- PR CI on Node 20 and Node 24
- push CI on Node 20 and Node 24
- Docker smoke on `node:20-alpine` and `node:24-alpine`
- manual CD canary with `actions_node24_canary=true`

## Notes
- this is stage 1 of a staged migration, not the final Node 24 cutover
- the shared runner VM still needs an operational refresh because Terraform ignores runner `custom_data` changes on the existing VM
```
