output "resource_group_name" {
  description = "Resource group name for current environment."
  value       = azurerm_resource_group.main.name
}

output "acr_name" {
  description = "Azure Container Registry name."
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Azure Container Registry login server."
  value       = azurerm_container_registry.main.login_server
}

output "container_app_name" {
  description = "Container App name."
  value       = azurerm_container_app.main.name
}

output "container_app_fqdn" {
  description = "Container App ingress FQDN."
  value       = try(azurerm_container_app.main.ingress[0].fqdn, null)
}

output "container_app_environment_id" {
  description = "Container App Environment id in use."
  value       = local.container_app_environment_id
}

output "key_vault_name" {
  description = "Key Vault name in use."
  value       = local.key_vault_name
}
