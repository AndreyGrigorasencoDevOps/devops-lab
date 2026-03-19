# Archived: Post-Refactor Rollout Reference

This document is historical reference from the paid-normalization rollout period.

It is no longer the active operational baseline.

Use these files instead:

- `docs/ROADMAP.md`
  - current platform status and next milestones
- `docs/security-operations.md`
  - recurring operational and security tasks
- `docs/local-development.md`
  - local environment workflow

## Final baseline after rollout

- Dedicated Key Vault per environment
- Dedicated CAE and runtime VNet per environment
- Key Vault runtime access over private networking
- Shared runner in `uksouth` with on-demand CD boot/deallocate flow
- Shared-ops Terraform root limited to the subscription budget

## Historical scope

This file is kept only as a reference marker for the completed refactor/normalization phase.
