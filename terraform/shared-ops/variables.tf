variable "project" {
  type        = string
  description = "Project name used for naming and tags."
  default     = "taskapi"
}

variable "budget_name" {
  type        = string
  description = "Subscription budget name."
  default     = "taskapi-shared-monthly-budget"
}

variable "monthly_budget_amount" {
  type        = number
  description = "Monthly budget amount in the subscription billing currency."
  default     = 15
  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "monthly_budget_amount must be greater than zero."
  }
}

variable "budget_contact_emails" {
  type        = list(string)
  description = "Email contacts that receive budget notifications."
  default     = ["replace-before-apply@example.com"]
  validation {
    condition     = length(var.budget_contact_emails) > 0
    error_message = "budget_contact_emails must include at least one alert recipient."
  }
}

variable "budget_start_date" {
  type        = string
  description = "RFC3339 UTC timestamp used as the start date for the monthly budget."
  default     = "2026-04-01T00:00:00Z"
}
