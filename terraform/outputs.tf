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

output "key_vault_private_endpoint_id" {
  description = "Key Vault private endpoint id when enabled."
  value       = try(azurerm_private_endpoint.key_vault[0].id, null)
}

output "db_key_vault_secret_names" {
  description = "Key Vault secret names used by Container App for DB_* runtime values."
  value       = local.db_kv_secret_name_by_env_var
}

output "postgres_server_name" {
  description = "PostgreSQL flexible server name."
  value       = azurerm_postgresql_flexible_server.main.name
}

output "postgres_fqdn" {
  description = "PostgreSQL flexible server hostname."
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgres_port" {
  description = "PostgreSQL server port."
  value       = 5432
}

output "postgres_admin_username" {
  description = "PostgreSQL flexible server administrator login."
  value       = azurerm_postgresql_flexible_server.main.administrator_login
}

output "postgres_database_name" {
  description = "Application database name."
  value       = azurerm_postgresql_flexible_server_database.main.name
}

output "shared_runner_resource_group_name" {
  description = "Resource group containing shared runner network assets."
  value       = local.shared_runner_resource_group_name
}

output "shared_runner_vnet_name" {
  description = "Shared runner VNet name."
  value = var.enable_shared_runner_platform ? azurerm_virtual_network.shared_runner[0].name : (
    var.key_vault_private_endpoint_enabled ? data.azurerm_virtual_network.shared_runner[0].name : null
  )
}

output "shared_runner_private_endpoints_subnet_id" {
  description = "Subnet id used for Key Vault private endpoints."
  value       = local.shared_runner_private_endpoint_subnet_id
}

output "shared_runner_private_dns_zone_name" {
  description = "Private DNS zone used for Key Vault private endpoint records."
  value = var.enable_shared_runner_platform ? azurerm_private_dns_zone.shared_runner_key_vault[0].name : (
    var.key_vault_private_endpoint_enabled ? data.azurerm_private_dns_zone.shared_runner_key_vault[0].name : null
  )
}

output "shared_runner_vm_name" {
  description = "Name of shared self-hosted runner VM when created."
  value       = try(azurerm_linux_virtual_machine.shared_runner[0].name, null)
}

output "shared_runner_vm_private_ip" {
  description = "Private IP of shared self-hosted runner VM when created."
  value       = try(azurerm_network_interface.shared_runner[0].private_ip_address, null)
}

output "shared_runner_expected_labels" {
  description = "Expected labels for self-hosted CD runner."
  value       = var.shared_runner_labels
}
