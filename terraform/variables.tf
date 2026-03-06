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
