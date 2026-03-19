data "azurerm_subscription" "current" {}

locals {
  budget_notification_thresholds = [50, 75, 90, 100]
}

resource "azurerm_consumption_budget_subscription" "main" {
  name            = var.budget_name
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
