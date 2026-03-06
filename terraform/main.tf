locals {
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
  enable_rbac_authorization     = true
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

resource "azurerm_container_app" "main" {
  name                         = "${var.project}-${var.env}-app"
  container_app_environment_id = local.container_app_environment_id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = "SystemAssigned"
  }

  template {
    container {
      name   = "task-api"
      image  = "${azurerm_container_registry.main.login_server}/task-api:${var.container_image_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory

      dynamic "env" {
        for_each = var.app_env_vars
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
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = local.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}
