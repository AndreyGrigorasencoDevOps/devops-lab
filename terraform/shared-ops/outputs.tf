output "budget_name" {
  description = "Subscription budget name."
  value       = azurerm_consumption_budget_subscription.main.name
}

output "budget_amount" {
  description = "Configured monthly budget amount."
  value       = azurerm_consumption_budget_subscription.main.amount
}
