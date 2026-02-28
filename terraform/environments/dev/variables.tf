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

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources."
  default     = {}
}