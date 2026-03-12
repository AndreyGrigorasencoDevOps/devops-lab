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

  container_app_environment_id      = var.use_shared_cae ? data.azurerm_container_app_environment.shared[0].id : azurerm_container_app_environment.main[0].id
  key_vault_id                      = var.use_shared_key_vault ? data.azurerm_key_vault.shared[0].id : azurerm_key_vault.main[0].id
  key_vault_name                    = var.use_shared_key_vault ? data.azurerm_key_vault.shared[0].name : azurerm_key_vault.main[0].name
  key_vault_firewall_enabled        = var.key_vault_network_mode == "firewall"
  shared_runner_resource_group_name = var.enable_shared_runner_platform ? azurerm_resource_group.main.name : var.shared_runner_resource_group_name
  shared_runner_location_effective  = coalesce(var.shared_runner_location, azurerm_resource_group.main.location)
  shared_runner_private_endpoint_subnet_id = var.key_vault_private_endpoint_enabled ? (
    var.enable_shared_runner_platform ? azurerm_subnet.shared_runner_private_endpoints[0].id : data.azurerm_subnet.shared_runner_private_endpoints[0].id
  ) : null
  shared_runner_private_dns_zone_id = var.key_vault_private_endpoint_enabled ? (
    var.enable_shared_runner_platform ? azurerm_private_dns_zone.shared_runner_key_vault[0].id : data.azurerm_private_dns_zone.shared_runner_key_vault[0].id
  ) : null
  shared_runner_bootstrap_script = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release jq unzip

    curl -sL https://aka.ms/InstallAzureCLIDeb | bash

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
    chmod a+r /etc/apt/keyrings/hashicorp.gpg
    echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list

    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list

    apt-get update
    apt-get install -y terraform gh

    RUNNER_VERSION="2.324.0"
    install -d -m 0755 /opt/actions-runner
    cd /opt/actions-runner
    curl -fsSL -o actions-runner.tar.gz "https://github.com/actions/runner/releases/download/v$${RUNNER_VERSION}/actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz"
    tar -xzf actions-runner.tar.gz
    rm -f actions-runner.tar.gz

    cat > /usr/local/bin/register-gh-runner.sh <<'EOS'
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ $# -ne 2 ]]; then
      echo "Usage: register-gh-runner.sh <owner/repo> <registration_token>"
      exit 1
    fi

    REPO="$1"
    TOKEN="$2"
    LABELS="${join(",", var.shared_runner_labels)}"
    export RUNNER_ALLOW_RUNASROOT=1

    cd /opt/actions-runner
    ./config.sh --unattended --url "https://github.com/$${REPO}" --token "$${TOKEN}" --labels "$${LABELS}" --name "$(hostname)" --work "_work" --replace
    ./svc.sh install root
    ./svc.sh start
    EOS
    chmod +x /usr/local/bin/register-gh-runner.sh
  EOT
  reserved_app_env_var_names     = local.db_env_var_names
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

resource "azurerm_network_security_group" "shared_runner" {
  count               = var.enable_shared_runner_platform ? 1 : 0
  name                = var.shared_runner_nsg_name
  location            = local.shared_runner_location_effective
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_virtual_network" "shared_runner" {
  count               = var.enable_shared_runner_platform ? 1 : 0
  name                = var.shared_runner_vnet_name
  location            = local.shared_runner_location_effective
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.shared_runner_vnet_cidrs
  tags                = local.tags
}

resource "azurerm_subnet" "shared_runner" {
  count                = var.enable_shared_runner_platform ? 1 : 0
  name                 = var.shared_runner_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.shared_runner[0].name
  address_prefixes     = var.shared_runner_subnet_cidrs

  lifecycle {
    replace_triggered_by = [azurerm_virtual_network.shared_runner[0]]
  }
}

resource "azurerm_subnet" "shared_runner_private_endpoints" {
  count                             = var.enable_shared_runner_platform ? 1 : 0
  name                              = var.shared_runner_private_endpoints_subnet_name
  resource_group_name               = azurerm_resource_group.main.name
  virtual_network_name              = azurerm_virtual_network.shared_runner[0].name
  address_prefixes                  = var.shared_runner_private_endpoints_subnet_cidrs
  private_endpoint_network_policies = "Disabled"

  lifecycle {
    replace_triggered_by = [azurerm_virtual_network.shared_runner[0]]
  }
}

resource "azurerm_subnet_network_security_group_association" "shared_runner" {
  count                     = var.enable_shared_runner_platform ? 1 : 0
  subnet_id                 = azurerm_subnet.shared_runner[0].id
  network_security_group_id = azurerm_network_security_group.shared_runner[0].id
}

resource "azurerm_subnet_network_security_group_association" "shared_runner_private_endpoints" {
  count                     = var.enable_shared_runner_platform ? 1 : 0
  subnet_id                 = azurerm_subnet.shared_runner_private_endpoints[0].id
  network_security_group_id = azurerm_network_security_group.shared_runner[0].id
}

resource "azurerm_network_interface" "shared_runner" {
  count               = var.enable_shared_runner_platform && var.shared_runner_enable_vm ? 1 : 0
  name                = "${var.shared_runner_vm_name}-nic"
  location            = local.shared_runner_location_effective
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.shared_runner[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "shared_runner" {
  count               = var.enable_shared_runner_platform && var.shared_runner_enable_vm ? 1 : 0
  name                = var.shared_runner_vm_name
  resource_group_name = azurerm_resource_group.main.name
  location            = local.shared_runner_location_effective
  size                = var.shared_runner_vm_size
  admin_username      = var.shared_runner_admin_username
  network_interface_ids = [
    azurerm_network_interface.shared_runner[0].id
  ]
  disable_password_authentication = true
  custom_data                     = base64encode(local.shared_runner_bootstrap_script)
  tags                            = local.tags

  # Runner bootstrap updates are applied operationally (run-command) to avoid forced VM replacement on script tweaks.
  lifecycle {
    ignore_changes = [custom_data]
  }

  admin_ssh_key {
    username   = var.shared_runner_admin_username
    public_key = var.shared_runner_admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_private_dns_zone" "shared_runner_key_vault" {
  count               = var.enable_shared_runner_platform ? 1 : 0
  name                = var.shared_runner_private_dns_zone_name
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "shared_runner_key_vault" {
  count                 = var.enable_shared_runner_platform ? 1 : 0
  name                  = "${var.project}-${var.env}-kv-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.shared_runner_key_vault[0].name
  virtual_network_id    = azurerm_virtual_network.shared_runner[0].id
  registration_enabled  = false
  tags                  = local.tags
}

data "azurerm_virtual_network" "shared_runner" {
  count               = var.enable_shared_runner_platform || !var.key_vault_private_endpoint_enabled ? 0 : 1
  name                = var.shared_runner_vnet_name
  resource_group_name = local.shared_runner_resource_group_name
}

data "azurerm_subnet" "shared_runner_private_endpoints" {
  count                = var.enable_shared_runner_platform || !var.key_vault_private_endpoint_enabled ? 0 : 1
  name                 = var.shared_runner_private_endpoints_subnet_name
  virtual_network_name = data.azurerm_virtual_network.shared_runner[0].name
  resource_group_name  = local.shared_runner_resource_group_name
}

data "azurerm_private_dns_zone" "shared_runner_key_vault" {
  count               = var.enable_shared_runner_platform || !var.key_vault_private_endpoint_enabled ? 0 : 1
  name                = var.shared_runner_private_dns_zone_name
  resource_group_name = local.shared_runner_resource_group_name
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
    default_action             = local.key_vault_firewall_enabled ? "Deny" : "Allow"
    ip_rules                   = local.key_vault_firewall_enabled ? var.key_vault_allowed_ip_cidrs : []
    virtual_network_subnet_ids = local.key_vault_firewall_enabled ? var.key_vault_allowed_subnet_ids : []
  }
}

data "azurerm_key_vault" "shared" {
  count               = var.use_shared_key_vault ? 1 : 0
  name                = var.shared_key_vault_name
  resource_group_name = var.shared_key_vault_resource_group_name
}

resource "azurerm_private_endpoint" "key_vault" {
  count               = var.key_vault_private_endpoint_enabled ? 1 : 0
  name                = "${var.project}-${var.env}-kv-pe-uks"
  location            = local.shared_runner_location_effective
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = local.shared_runner_private_endpoint_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "${var.project}-${var.env}-kv-psc"
    private_connection_resource_id = local.key_vault_id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [local.shared_runner_private_dns_zone_id]
  }
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
    terraform_data.rbac_propagation
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

resource "terraform_data" "rbac_propagation" {
  triggers_replace = [
    azurerm_role_assignment.acr_pull.id,
    azurerm_role_assignment.key_vault_secrets_user.id
  ]

  provisioner "local-exec" {
    command = "sleep ${var.rbac_propagation_wait_seconds}"
  }
}
