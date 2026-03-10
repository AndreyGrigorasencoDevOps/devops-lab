env      = "prod"
location = "uksouth"

use_shared_cae                 = true
shared_cae_name                = "taskapi-dev-cae-uks"
shared_cae_resource_group_name = "taskapi-dev-rg-uks"

use_shared_key_vault               = false
key_vault_name                     = "taskapi-prod-kv-uks"
key_vault_network_mode             = "firewall"
key_vault_private_endpoint_enabled = true
rbac_propagation_wait_seconds      = 45

enable_shared_runner_platform               = false
shared_runner_resource_group_name           = "taskapi-dev-rg-uks"
shared_runner_vnet_name                     = "taskapi-shared-runner-vnet-uks"
shared_runner_private_endpoints_subnet_name = "taskapi-shared-pe-snet"
shared_runner_private_dns_zone_name         = "privatelink.vaultcore.azure.net"

app_env_vars = {
  NODE_ENV = "production"
}

tags = {
  project = "taskapi"
  env     = "prod"
  owner   = "andrei"
}
