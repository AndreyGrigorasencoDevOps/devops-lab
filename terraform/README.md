# Terraform (Azure) — Infrastructure as Code

This folder contains Terraform configuration split by environment, each with its own variables, state, and outputs.

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── terraform.tfvars
└── modules/
```

---

## Requirements

| Tool | Version |
|------|---------|
| Terraform | `>= 1.6` |
| Azure CLI | latest stable |
| Git | any |

You also need **Contributor** (or higher) access on the target Azure subscription/resource group.

### Verify versions

```bash
terraform -version
az version
```

---

## Azure Login

```bash
az login
# or
az login --use-device-code
```

Check current account/subscription context:

```bash
az account show
az account list -o table
```

---

## Choose Environment (dev / prod)

**Option A (recommended)** — run commands inside the env folder:

```bash
cd terraform/environments/dev
# or
cd terraform/environments/prod
```

**Option B** — run from repo root using `-chdir`:

```bash
terraform -chdir=terraform/environments/dev init
terraform -chdir=terraform/environments/prod init
```

---

## Terraform Workflow Commands

> Examples below use **dev**. Replace `dev` with `prod` when needed.

### 1. Init

Initializes providers and remote backend state.

```bash
cd terraform/environments/dev
terraform init
```

### 2. Validate

Quick syntax/config sanity check.

```bash
terraform validate
```

### 3. Format

```bash
terraform fmt -recursive
```

### 4. Plan

Creates an execution plan — shows what Terraform will change.

Using `terraform.tfvars` in the env folder (recommended):

```bash
terraform plan
```

Explicitly pointing to a tfvars file:

```bash
terraform plan -var-file="terraform.tfvars"
```

Save the plan to a file (optional):

```bash
terraform plan -out tfplan
```

### 5. Apply

```bash
terraform apply
```

From a saved plan:

```bash
terraform apply tfplan
```

### 6. Outputs

```bash
terraform output
```

### 7. Destroy

Destroys everything managed by the current environment state.

```bash
terraform destroy
```

With explicit vars file:

```bash
terraform destroy -var-file="terraform.tfvars"
```

---

## Remote State (Azure Storage Backend)

Production-ready Terraform must use remote state — local state is **not** allowed for real environments.

We use an **Azure Storage Account + Blob Container** as the backend.

### Create backend resources (one-time setup)

These resources are created once, manually via CLI:

```bash
RG_NAME="taskapi-tfstate-rg"
LOCATION="uksouth"
STORAGE_ACCOUNT="taskapitfstateuks"
CONTAINER_NAME="tfstate"

az group create \
  --name "$RG_NAME" \
  --location "$LOCATION"

az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --encryption-services blob

az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login
```

> Storage account name must be **globally unique** across all of Azure.

### Configure backend in each environment

Add a `backend` block inside the `terraform` block in each environment's `main.tf`:

**`terraform/environments/dev/main.tf`**

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "taskapi-tfstate-rg"
    storage_account_name = "taskapitfstateuks"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
```

**`terraform/environments/prod/main.tf`** — same block, different key:

```hcl
key = "prod.terraform.tfstate"
```

### Initialize with backend

After the backend block is added:

```bash
terraform init
```

If migrating from local state:

```bash
terraform init -migrate-state
```

### State isolation model

| Environment | State Key |
|-------------|-----------|
| dev | `dev.terraform.tfstate` |
| prod | `prod.terraform.tfstate` |

Each environment is fully isolated — its own state file in the same storage container.

---

## Notes & Conventions

- **Never commit state files** — `.gitignore` already covers:
  - `.terraform/`
  - `*.tfstate` / `*.tfstate.*`
  - `crash.log`
- Keep environment-specific config in `terraform/environments/<env>/terraform.tfvars`
- Follow the project's naming conventions (resource naming, region codes, etc.) from `docs/cloud-architecture.md`

---

## Security Best Practices

- Use **Azure RBAC** for access control to the storage account
- Enable **soft delete** and **versioning** on the state blob container
- Consider **private endpoints** for the storage account (later stage)
- Consider a **separate subscription** for prod (future improvement)

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Not logged in / unauthorized | `az account show` then `az login --use-device-code` |
| Wrong subscription | `az account list -o table` then `az account set --subscription "<ID>"` |
| Provider or init issues | `terraform init -upgrade` |