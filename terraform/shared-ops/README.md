# Shared Ops Terraform

This Terraform root now manages one shared, subscription-scoped control only:

- the monthly Azure subscription budget

## Why this exists

The env root under `terraform/` owns runtime infrastructure such as the app, DB, Key Vault, CAE, runtime VNet, and the shared runner VM.

`terraform/shared-ops/` exists so the subscription budget can live in its own Terraform state instead of being awkwardly owned by `dev` or `prod`.

## What it manages

- Monthly Azure subscription budget with alerts at `50%`, `75%`, `90%`, and `100%`

## What it does not manage

- Shared runner VM scheduling
- Azure Start/Stop automation
- Weekly patch execution on the runner VM
- Azure Advisor review workflow

Primary runner cost control now comes from workflow-driven VM deallocation after each CD run, not from a separate Azure schedule.

## Usage

Before the first apply:

1. Delete the old manual budget `taskapi-dev-budget`.
2. Replace `replace-before-apply@example.com` in `vars/shared.tfvars` with real alert recipients.

Then run:

```bash
terraform -chdir=terraform/shared-ops init -backend-config=backend/shared.hcl -reconfigure
terraform -chdir=terraform/shared-ops plan -var-file=vars/shared.tfvars
terraform -chdir=terraform/shared-ops apply -var-file=vars/shared.tfvars
```

## Notes

- The Terraform-managed budget is named `taskapi-shared-monthly-budget`.
- The configured monthly amount is `15` in the subscription billing currency.
- The budget starts on `2026-04-01T00:00:00Z` because Azure monthly budgets must begin on the first day of a month.
- Budget alerts are informational only; they do not stop resources automatically.
