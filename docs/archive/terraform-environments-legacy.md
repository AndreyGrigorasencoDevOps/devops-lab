# Archive: Legacy Terraform Environment Layout

## Why this is archived

The project previously used a split layout under `terraform/environments/*`.
This was deprecated in favor of the single-root Terraform stack:

- `terraform/main.tf`
- `terraform/variables.tf`
- `terraform/outputs.tf`
- `terraform/vars/dev.tfvars`
- `terraform/vars/prod.tfvars`

This archive note preserves historical context without keeping stale local state artifacts.

## Current source of truth

Use only the root Terraform stack in `terraform/`.
Do not use `terraform/environments/*` for plan/apply operations.

## Legacy cleanup policy

- `terraform/environments/*` local artifacts are removed.
- `terraform/modules/` is intentionally kept for future reusable module work.
- Roadmap marks old environments layout as deprecated and replaced.
