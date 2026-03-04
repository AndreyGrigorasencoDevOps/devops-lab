variable "project" {
  type        = string
  description = "Project name used for naming/tagging."
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

variable "shared_cae_name" {
  type        = string
  description = "Name of the shared Container Apps Environment to use for prod."
  default     = "taskapi-dev-cae-uks"
}

variable "shared_cae_resource_group_name" {
  type        = string
  description = "Resource group where the shared Container Apps Environment exists."
  default     = "taskapi-dev-rg-uks"
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources."
  default     = {}
}
