# Shared Ops Terraform

This Terraform root manages shared, subscription-scoped cost-control artifacts that do not belong to the env-specific `dev` or `prod` states.

## Why this exists

Before paid normalization, most operational concerns lived alongside the env stacks because the repo only needed `dev` and `prod` runtime state.

Now there is a small set of shared operational controls that are not environment-specific:

- subscription budget
- budget alert contacts
- runner office-hours metadata
- runner patch/right-sizing metadata

Keeping those controls in `terraform/shared-ops/` gives them a separate Terraform state and avoids coupling subscription-wide operations to the `dev` or `prod` runtime plans.

## What it manages

- Shared ops resource group (`taskapi-shared-ops-rg-uks` by default)
- Monthly Azure subscription budget with alerts at `50%`, `75%`, `90%`, and `100%`
- Runner office-hours metadata stored in Terraform variables/outputs and mirrored into RG tags

## What is different from the older env files

- `terraform/` remains the env infrastructure root for app/runtime resources.
- `terraform/shared-ops/` is not another environment; it is a separate root for shared subscription-scope operations.
- The older env files create or reference the runner VM, networks, CAEs, Key Vaults, and app stack.
- The shared-ops files do not manage the app stack or the runner VM itself; they manage cost-control and operational metadata around that stack.

## What it does not yet automate

- Start/Stop VMs during off-hours deployment itself
- Weekly patch execution on the runner VM
- Azure Advisor review workflow

Those steps remain operational, but the metadata in `vars/shared.tfvars` is now the source of truth the runbook should follow.

## Usage

```bash
terraform -chdir=terraform/shared-ops init -backend-config=backend/shared.hcl -reconfigure
terraform -chdir=terraform/shared-ops plan -var-file=vars/shared.tfvars
terraform -chdir=terraform/shared-ops apply -var-file=vars/shared.tfvars
```

## Required follow-up after apply

1. Deploy Azure Start/Stop VMs during off-hours using the runner schedule values from `vars/shared.tfvars`.
2. Point the schedule at `runner_resource_group_name` / `runner_vm_name`.
3. Record patch evidence every Wednesday at `runner_patch_time` in the timezone from `runner_schedule_timezone`.
4. Record monthly Azure Advisor right-sizing review evidence.
