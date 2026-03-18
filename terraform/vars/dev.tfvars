env      = "dev"
location = "uksouth"

use_shared_cae                                        = false
container_app_environment_name                        = "taskapi-dev-cae-vnet-uks"
runtime_virtual_network_name                          = "taskapi-dev-rt-vnet-uks"
runtime_virtual_network_cidrs                         = ["10.43.0.0/16"]
container_app_environment_infrastructure_subnet_name  = "taskapi-dev-cae-snet"
container_app_environment_infrastructure_subnet_cidrs = ["10.43.0.0/23"]
runtime_private_endpoints_subnet_name                 = "taskapi-dev-pe-snet"
runtime_private_endpoints_subnet_cidrs                = ["10.43.10.0/24"]

use_shared_key_vault = false
key_vault_name       = "taskapi-dev-kv-uks"
# Steady-state hardened mode after dedicated CAE + runtime VNet migration.
key_vault_network_mode             = "firewall"
key_vault_private_endpoint_enabled = true
rbac_propagation_wait_seconds      = 45

enable_shared_runner_platform = true
shared_runner_enable_vm       = true
shared_runner_vm_size         = "Standard_B1s"

app_env_vars = {
  NODE_ENV = "production"
}

tags = {
  project = "taskapi"
  env     = "dev"
  owner   = "andrei"
}
