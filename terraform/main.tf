locals {
  db_env_var_names = toset(["DB_HOST", "DB_PORT", "DB_USER", "DB_PASSWORD", "DB_NAME"])
  db_container_app_secret_name_by_env_var = {
    DB_HOST     = "db-host"
    DB_PORT     = "db-port"
    DB_USER     = "db-user"
    DB_PASSWORD = "db-password"
    DB_NAME     = "db-name"
  }
  db_kv_secret_name_by_env_var = {
    DB_HOST     = "${var.env}-db-host"
    DB_PORT     = "${var.env}-db-port"
    DB_USER     = "${var.env}-db-user"
    DB_PASSWORD = "${var.env}-db-password"
    DB_NAME     = "${var.env}-db-name"
  }

  tags = merge(
    {
      project = var.project
      env     = var.env
    },
    var.tags
  )

  container_app_environment_id = var.use_shared_cae ? data.azurerm_container_app_environment.shared[0].id : azurerm_container_app_environment.main[0].id
  key_vault_id                 = var.use_shared_key_vault ? data.azurerm_key_vault.shared[0].id : azurerm_key_vault.main[0].id
  key_vault_name               = var.use_shared_key_vault ? data.azurerm_key_vault.shared[0].name : azurerm_key_vault.main[0].name
  reserved_app_env_var_names   = local.db_env_var_names
  db_secret_id_by_env_var = merge(
    { for env_var_name, secret in azurerm_key_vault_secret.db_runtime : env_var_name => secret.versionless_id },
    { DB_PASSWORD = data.azurerm_key_vault_secret.db_password.versionless_id }
  )
  sanitized_app_env_vars = {
    for key, value in var.app_env_vars : key => value
    if !contains(local.reserved_app_env_var_names, key)
  }
}

moved {
  from = azurerm_log_analytics_workspace.main
  to   = azurerm_log_analytics_workspace.main[0]
}

moved {
  from = azurerm_container_app_environment.main
  to   = azurerm_container_app_environment.main[0]
}

resource "azurerm_resource_group" "main" {
  name     = "${var.project}-${var.env}-rg-uks"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  count               = var.use_shared_cae ? 0 : 1
  name                = "${var.project}-${var.env}-law-uks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_container_app_environment" "main" {
  count                      = var.use_shared_cae ? 0 : 1
  name                       = "${var.project}-${var.env}-cae-uks"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id
  tags                       = local.tags
}

data "azurerm_container_app_environment" "shared" {
  count               = var.use_shared_cae ? 1 : 0
  name                = var.shared_cae_name
  resource_group_name = var.shared_cae_resource_group_name
}

resource "azurerm_key_vault" "main" {
  count                         = var.use_shared_key_vault ? 0 : 1
  name                          = coalesce(var.key_vault_name, "${var.project}-${var.env}-kv-uks")
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  public_network_access_enabled = true
  tags                          = local.tags

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = var.key_vault_allowed_ip_cidrs
    virtual_network_subnet_ids = var.key_vault_allowed_subnet_ids
  }
}

data "azurerm_key_vault" "shared" {
  count               = var.use_shared_key_vault ? 1 : 0
  name                = var.shared_key_vault_name
  resource_group_name = var.shared_key_vault_resource_group_name
}

data "azurerm_key_vault_secret" "db_password" {
  name         = local.db_kv_secret_name_by_env_var["DB_PASSWORD"]
  key_vault_id = local.key_vault_id
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_container_registry" "main" {
  name                = "${var.project}${var.env}acr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "container_app" {
  name                = "${var.project}-${var.env}-ca-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                          = "${var.project}-${var.env}-psql-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = var.postgres_server_version
  administrator_login           = var.postgres_admin_username
  administrator_password        = data.azurerm_key_vault_secret.db_password.value
  sku_name                      = var.postgres_sku_name
  storage_mb                    = var.postgres_storage_mb
  backup_retention_days         = var.postgres_backup_retention_days
  public_network_access_enabled = var.postgres_public_network_access_enabled
  tags                          = local.tags

  # Existing servers may have an auto-selected zone; Azure doesn't allow arbitrary zone updates in-place.
  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  count            = var.postgres_public_network_access_enabled ? 1 : 0
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.postgres_database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_key_vault_secret" "db_runtime" {
  for_each = {
    DB_HOST = azurerm_postgresql_flexible_server.main.fqdn
    DB_PORT = "5432"
    DB_USER = azurerm_postgresql_flexible_server.main.administrator_login
    DB_NAME = azurerm_postgresql_flexible_server_database.main.name
  }

  name         = local.db_kv_secret_name_by_env_var[each.key]
  value        = each.value
  key_vault_id = local.key_vault_id
}

resource "azurerm_container_app" "main" {
  name                         = "${var.project}-${var.env}-app"
  container_app_environment_id = local.container_app_environment_id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.key_vault_secrets_user
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.container_app.id
  }

  dynamic "secret" {
    for_each = local.db_secret_id_by_env_var
    iterator = db_secret
    content {
      name                = local.db_container_app_secret_name_by_env_var[db_secret.key]
      key_vault_secret_id = db_secret.value
      identity            = azurerm_user_assigned_identity.container_app.id
    }
  }

  template {
    container {
      name   = "task-api"
      image  = "${azurerm_container_registry.main.login_server}/task-api:${var.container_image_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory

      dynamic "env" {
        for_each = local.db_env_var_names
        iterator = db_env
        content {
          name        = db_env.value
          secret_name = local.db_container_app_secret_name_by_env_var[db_env.value]
        }
      }

      dynamic "env" {
        for_each = local.sanitized_app_env_vars
        iterator = app_env
        content {
          name  = app_env.key
          value = app_env.value
        }
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 3000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                            = azurerm_container_registry.main.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_user_assigned_identity.container_app.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                            = local.key_vault_id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = azurerm_user_assigned_identity.container_app.principal_id
  skip_service_principal_aad_check = true
}
