env      = "prod"
location = "uksouth"

use_shared_cae                                        = false
container_app_environment_name                        = "taskapi-prod-cae-vnet-uks"
runtime_virtual_network_name                          = "taskapi-prod-rt-vnet-uks"
runtime_virtual_network_cidrs                         = ["10.44.0.0/16"]
container_app_environment_infrastructure_subnet_name  = "taskapi-prod-cae-snet"
container_app_environment_infrastructure_subnet_cidrs = ["10.44.0.0/23"]
runtime_private_endpoints_subnet_name                 = "taskapi-prod-pe-snet"
runtime_private_endpoints_subnet_cidrs                = ["10.44.10.0/24"]

use_shared_key_vault = false
key_vault_name       = "taskapi-prod-kv-uks"
# Steady-state hardened mode after dedicated CAE + runtime VNet migration.
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
