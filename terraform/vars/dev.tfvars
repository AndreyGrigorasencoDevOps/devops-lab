env      = "dev"
location = "uksouth"

use_shared_cae = false

use_shared_key_vault = false
key_vault_name       = "taskapi-dev-kv-uks"
# Temporary runtime-compat mode until Container Apps Environment is integrated into VNet.
key_vault_network_mode             = "public_allow"
key_vault_private_endpoint_enabled = true
rbac_propagation_wait_seconds      = 45

enable_shared_runner_platform = true
shared_runner_enable_vm       = true
shared_runner_location        = "eastus"
shared_runner_vm_size         = "Standard_DC2s_v3"

app_env_vars = {
  NODE_ENV = "production"
}

tags = {
  project = "taskapi"
  env     = "dev"
  owner   = "andrei"
}
