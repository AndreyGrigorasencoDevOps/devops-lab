variable "project" {
  type        = string
  description = "Project name used for naming and tags."
  default     = "taskapi"
}

variable "env" {
  type        = string
  description = "Environment name."
  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be one of: dev, prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region."
  default     = "uksouth"
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources."
  default     = {}
}

variable "use_shared_cae" {
  type        = bool
  description = "If true, use an existing shared Container Apps Environment."
  default     = false
}

variable "shared_cae_name" {
  type        = string
  description = "Shared Container Apps Environment name when use_shared_cae is true."
  default     = null
  nullable    = true
  validation {
    condition     = !var.use_shared_cae || var.shared_cae_name != null
    error_message = "shared_cae_name is required when use_shared_cae is true."
  }
}

variable "shared_cae_resource_group_name" {
  type        = string
  description = "Resource group of shared Container Apps Environment when use_shared_cae is true."
  default     = null
  nullable    = true
  validation {
    condition     = !var.use_shared_cae || var.shared_cae_resource_group_name != null
    error_message = "shared_cae_resource_group_name is required when use_shared_cae is true."
  }
}

variable "use_shared_key_vault" {
  type        = bool
  description = "If true, use an existing shared Key Vault."
  default     = false
}

variable "key_vault_name" {
  type        = string
  description = "Key Vault name to create when use_shared_key_vault is false."
  default     = null
  nullable    = true
}

variable "shared_key_vault_name" {
  type        = string
  description = "Shared Key Vault name when use_shared_key_vault is true."
  default     = null
  nullable    = true
  validation {
    condition     = !var.use_shared_key_vault || var.shared_key_vault_name != null
    error_message = "shared_key_vault_name is required when use_shared_key_vault is true."
  }
}

variable "shared_key_vault_resource_group_name" {
  type        = string
  description = "Resource group of shared Key Vault when use_shared_key_vault is true."
  default     = null
  nullable    = true
  validation {
    condition     = !var.use_shared_key_vault || var.shared_key_vault_resource_group_name != null
    error_message = "shared_key_vault_resource_group_name is required when use_shared_key_vault is true."
  }
}

variable "enable_shared_runner_platform" {
  type        = bool
  description = "If true, create shared self-hosted runner infrastructure (VNet, subnets, private DNS, runner VM)."
  default     = false
}

variable "shared_runner_resource_group_name" {
  type        = string
  description = "Resource group where shared runner network assets already exist when enable_shared_runner_platform is false."
  default     = null
  nullable    = true
  validation {
    condition = (
      var.enable_shared_runner_platform ||
      !var.key_vault_private_endpoint_enabled ||
      var.shared_runner_resource_group_name != null
    )
    error_message = "shared_runner_resource_group_name is required when key_vault_private_endpoint_enabled is true and enable_shared_runner_platform is false."
  }
}

variable "shared_runner_vnet_name" {
  type        = string
  description = "Shared runner VNet name."
  default     = "taskapi-shared-runner-vnet-uks"
}

variable "shared_runner_subnet_name" {
  type        = string
  description = "Runner VM subnet name inside shared runner VNet."
  default     = "taskapi-shared-runner-snet"
}

variable "shared_runner_private_endpoints_subnet_name" {
  type        = string
  description = "Private Endpoint subnet name inside shared runner VNet."
  default     = "taskapi-shared-pe-snet"
}

variable "shared_runner_nsg_name" {
  type        = string
  description = "Network Security Group name attached to shared runner subnets."
  default     = "taskapi-shared-runner-nsg-uks"
}

variable "shared_runner_private_dns_zone_name" {
  type        = string
  description = "Private DNS zone used for Key Vault private endpoint resolution."
  default     = "privatelink.vaultcore.azure.net"
}

variable "shared_runner_vnet_cidrs" {
  type        = list(string)
  description = "Address spaces for shared runner VNet when enable_shared_runner_platform is true."
  default     = ["10.42.0.0/16"]
}

variable "shared_runner_subnet_cidrs" {
  type        = list(string)
  description = "Address prefixes for runner VM subnet."
  default     = ["10.42.1.0/24"]
}

variable "shared_runner_private_endpoints_subnet_cidrs" {
  type        = list(string)
  description = "Address prefixes for private endpoint subnet."
  default     = ["10.42.2.0/24"]
}

variable "shared_runner_enable_vm" {
  type        = bool
  description = "If true, create a single Linux VM for GitHub self-hosted runner in shared runner subnet."
  default     = true
}

variable "shared_runner_vm_name" {
  type        = string
  description = "Name of self-hosted runner VM."
  default     = "taskapi-shared-cd-runner-01"
}

variable "shared_runner_vm_size" {
  type        = string
  description = "Size of self-hosted runner VM."
  default     = "Standard_B2s"
}

variable "shared_runner_admin_username" {
  type        = string
  description = "Admin username for self-hosted runner VM."
  default     = "runneradmin"
}

variable "shared_runner_admin_ssh_public_key" {
  type        = string
  description = "SSH public key for self-hosted runner VM admin user."
  default     = null
  nullable    = true
  validation {
    condition = (
      !var.enable_shared_runner_platform ||
      !var.shared_runner_enable_vm ||
      var.shared_runner_admin_ssh_public_key != null
    )
    error_message = "shared_runner_admin_ssh_public_key is required when enable_shared_runner_platform and shared_runner_enable_vm are true."
  }
}

variable "shared_runner_labels" {
  type        = list(string)
  description = "Expected labels for self-hosted runner registration."
  default     = ["self-hosted", "linux", "x64", "taskapi-cd", "vnet"]
}

variable "container_image_tag" {
  type        = string
  description = "Container image tag deployed to Container App."
  default     = "dev"
}

variable "container_cpu" {
  type        = number
  description = "Container CPU limit."
  default     = 0.5
}

variable "container_memory" {
  type        = string
  description = "Container memory limit."
  default     = "1Gi"
}

variable "postgres_server_version" {
  type        = string
  description = "PostgreSQL flexible server major version."
  default     = "16"
}

variable "postgres_sku_name" {
  type        = string
  description = "SKU for PostgreSQL flexible server."
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  type        = number
  description = "Storage size for PostgreSQL flexible server in MB."
  default     = 32768
}

variable "postgres_backup_retention_days" {
  type        = number
  description = "Backup retention window for PostgreSQL flexible server."
  default     = 7
}

variable "postgres_public_network_access_enabled" {
  type        = bool
  description = "Enable public access for PostgreSQL flexible server."
  default     = true
}

variable "postgres_admin_username" {
  type        = string
  description = "Administrator username for PostgreSQL flexible server."
  default     = "taskapipg"
}

variable "postgres_database_name" {
  type        = string
  description = "Application database name in PostgreSQL."
  default     = "taskdb"
}

variable "app_env_vars" {
  type        = map(string)
  description = "Non-sensitive environment variables passed to Container App."
  default     = {}
}

variable "key_vault_allowed_ip_cidrs" {
  type        = list(string)
  description = "Public CIDRs allowed to reach Key Vault when firewall is enabled."
  default     = []
}

variable "key_vault_allowed_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs allowed to reach Key Vault when firewall is enabled."
  default     = []
}

variable "key_vault_network_mode" {
  type        = string
  description = "Key Vault network mode: public_allow (Phase 1) or firewall (Phase 2 hardening)."
  default     = "public_allow"
  validation {
    condition     = contains(["public_allow", "firewall"], var.key_vault_network_mode)
    error_message = "key_vault_network_mode must be one of: public_allow, firewall."
  }
}

variable "key_vault_private_endpoint_enabled" {
  type        = bool
  description = "Create a private endpoint for the active Key Vault and bind it to shared private DNS."
  default     = true
}

variable "rbac_propagation_wait_seconds" {
  type        = number
  description = "Wait time before Container App update to reduce RBAC propagation race conditions."
  default     = 45
  validation {
    condition = (
      var.rbac_propagation_wait_seconds >= 0 &&
      var.rbac_propagation_wait_seconds <= 600 &&
      var.rbac_propagation_wait_seconds == floor(var.rbac_propagation_wait_seconds)
    )
    error_message = "rbac_propagation_wait_seconds must be an integer between 0 and 600."
  }
}
