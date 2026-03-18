variable "project" {
  type        = string
  description = "Project name used for naming and tags."
  default     = "taskapi"
}

variable "location" {
  type        = string
  description = "Azure region for shared ops resources."
  default     = "uksouth"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group used for shared ops artifacts and metadata."
  default     = "taskapi-shared-ops-rg-uks"
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to shared ops resources."
  default     = {}
}

variable "monthly_budget_amount" {
  type        = number
  description = "Monthly budget amount in the subscription billing currency."
  default     = 150
  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "monthly_budget_amount must be greater than zero."
  }
}

variable "budget_contact_emails" {
  type        = list(string)
  description = "Email contacts that receive budget notifications."
  default     = ["platform-owner@example.com", "billing-owner@example.com"]
}

variable "budget_start_date" {
  type        = string
  description = "RFC3339 UTC timestamp used as the start date for the monthly budget."
  default     = "2026-04-01T00:00:00Z"
}

variable "runner_resource_group_name" {
  type        = string
  description = "Resource group that hosts the shared runner VM."
  default     = "taskapi-dev-rg-uks"
}

variable "runner_vm_name" {
  type        = string
  description = "Shared runner VM name."
  default     = "taskapi-shared-cd-runner-01"
}

variable "runner_schedule_timezone" {
  type        = string
  description = "Timezone for runner office-hours automation metadata."
  default     = "Europe/Paris"
}

variable "runner_weekday_start_time" {
  type        = string
  description = "Weekday runner start time in HH:MM format."
  default     = "07:00"
}

variable "runner_weekday_stop_time" {
  type        = string
  description = "Weekday runner stop time in HH:MM format."
  default     = "23:00"
}

variable "runner_patch_day" {
  type        = string
  description = "Day of week for the shared runner patch window."
  default     = "Wednesday"
}

variable "runner_patch_time" {
  type        = string
  description = "Patch window time in HH:MM format."
  default     = "22:00"
}

variable "runner_right_sizing_review_frequency" {
  type        = string
  description = "Human review cadence for runner right-sizing."
  default     = "monthly"
}
