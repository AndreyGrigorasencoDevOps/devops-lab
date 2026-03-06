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

variable "app_env_vars" {
  type        = map(string)
  description = "Non-sensitive environment variables passed to Container App."
  default     = {}
}

variable "app_secrets" {
  type        = map(string)
  description = "Sensitive values written to Key Vault and referenced by Container App."
  default     = {}
  sensitive   = true
}
