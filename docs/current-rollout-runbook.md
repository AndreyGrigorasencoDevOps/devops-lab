# Archived: Paid-Normalization Rollout

This rollout is complete.

Do not use this file as the active next-step checklist anymore.

Use these files instead:

- `docs/ROADMAP.md`
  - main learning path and next platform milestones
- `docs/security-operations.md`
  - ongoing operational and security cadence
- `terraform/shared-ops/README.md`
  - subscription budget usage

## Final rollout outcome

- Dedicated CAE per environment in `uksouth`
- Env-local runtime VNets and env-local Key Vault private endpoints
- Key Vault steady-state posture:
  - `default_action = Deny`
  - `bypass = None`
- Shared runner moved to `uksouth` on `Standard_F1als_v7`
- Shared runner CD flow is on-demand:
  - hosted boot
  - self-hosted Terraform
  - hosted deallocate
- Shared-ops reduced to a budget-only Terraform root
- Temporary Trivy rollout exception removed

## Historical note

This file remains in the repo only as a short archive marker for the completed paid-normalization rollout.
