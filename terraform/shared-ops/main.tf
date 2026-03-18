data "azurerm_subscription" "current" {}

locals {
  budget_notification_thresholds = [50, 75, 90, 100]
  tags = merge(
    {
      project                       = var.project
      scope                         = "shared-ops"
      runner_resource_group_name    = var.runner_resource_group_name
      runner_vm_name                = var.runner_vm_name
      runner_schedule_timezone      = var.runner_schedule_timezone
      runner_weekday_start_time     = var.runner_weekday_start_time
      runner_weekday_stop_time      = var.runner_weekday_stop_time
      runner_patch_day              = var.runner_patch_day
      runner_patch_time             = var.runner_patch_time
      runner_right_sizing_frequency = var.runner_right_sizing_review_frequency
    },
    var.tags
  )
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_consumption_budget_subscription" "main" {
  name            = "${var.project}-shared-monthly-budget"
  subscription_id = data.azurerm_subscription.current.id
  amount          = var.monthly_budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  dynamic "notification" {
    for_each = local.budget_notification_thresholds
    content {
      enabled        = true
      operator       = "GreaterThan"
      threshold      = notification.value
      contact_emails = var.budget_contact_emails
      contact_groups = []
      contact_roles  = []
    }
  }
}
