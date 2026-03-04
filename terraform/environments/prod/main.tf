locals {
  tags = var.tags
}

resource "azurerm_resource_group" "main" {
  name     = "taskapi-${var.env}-rg-uks"
  location = var.location
  tags     = local.tags
}

data "azurerm_container_app_environment" "shared" {
  name                = var.shared_cae_name
  resource_group_name = var.shared_cae_resource_group_name
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_container_registry" "main" {
  name                = "taskapi${var.env}acr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_container_app" "main" {
  name                         = "taskapi-${var.env}-app"
  container_app_environment_id = data.azurerm_container_app_environment.shared.id
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
      image  = "${azurerm_container_registry.main.login_server}/task-api:${var.env}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "NODE_ENV"
        value = "production"
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

  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
    ]
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}
