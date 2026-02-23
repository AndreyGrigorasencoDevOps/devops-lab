# Cloud Architecture (Azure)

## Subscription

- **Subscription Name:** <Azure subscription 1>
- **Subscription ID:** <beccabf7-91a3-4c7a-9650-61bfb916ffa8>
- **Tenant ID:** <0435e23c-d8f9-48f2-9c78-ec5d81c1aec7>
- **Type:** <Free Trial>

> Note: Subscription ID and Tenant ID are safe to store in Git.  
> Never commit secrets (client secrets, keys, connection strings, passwords, tokens).

## Account context (optional but useful)

- **Signed-in user:** <marty172000@gmail.com>
- **Default region:** <uksouth>

## Naming convention

### Environments
- **dev**: deployments from `main` (fast path / manual now, automated later)
- **prod**: deployments from release tags (later via Terraform + GitHub Actions)

### Region codes
- `uks` = UK South (`uksouth`)
- `ukw` = UK West (`ukwest`) (optional later)

### Standard format (most resources)
`taskapi-<env>-<resource>-<regionCode>`

Examples:
- `taskapi-dev-rg-uks`
- `taskapi-dev-vnet-uks`
- `taskapi-dev-nsg-uks`
- `taskapi-dev-law-uks` (Log Analytics workspace)
- `taskapi-prod-rg-uks`

### Resource codes
- `rg` = Resource Group
- `vnet` = Virtual Network
- `snet` = Subnet
- `nsg` = Network Security Group
- `acr` = Azure Container Registry
- `aks` = Azure Kubernetes Service
- `law` = Log Analytics Workspace
- `kv` = Key Vault

### Exceptions / constraints
Some resources have stricter naming rules (lowercase, length limits, global uniqueness):
- **ACR name** must be globally unique, lowercase, no dashes.  
  Example: `taskapidevacruks`
- **Key Vault name** must be globally unique and follow Azure naming rules.  
  Example pattern: `taskapi-dev-kv-uks` (may need adjustment)

## Next resources (Stage 3 targets)

- Resource Group
- VNet / Subnets
- NSG
- ACR (Container Registry)
- AKS (Kubernetes)
- Key Vault (later)
- Log Analytics / Monitoring (later)