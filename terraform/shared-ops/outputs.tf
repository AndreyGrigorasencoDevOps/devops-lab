output "resource_group_name" {
  description = "Shared ops resource group name."
  value       = azurerm_resource_group.main.name
}

output "budget_name" {
  description = "Subscription budget name."
  value       = azurerm_consumption_budget_subscription.main.name
}

output "budget_amount" {
  description = "Configured monthly budget amount."
  value       = azurerm_consumption_budget_subscription.main.amount
}

output "runner_schedule_metadata" {
  description = "Runner schedule metadata for optional office-hours automation and ops runbooks."
  value = {
    resource_group_name           = var.runner_resource_group_name
    vm_name                       = var.runner_vm_name
    timezone                      = var.runner_schedule_timezone
    weekday_start_time            = var.runner_weekday_start_time
    weekday_stop_time             = var.runner_weekday_stop_time
    patch_day                     = var.runner_patch_day
    patch_time                    = var.runner_patch_time
    right_sizing_review_frequency = var.runner_right_sizing_review_frequency
  }
}
