env      = "dev"
location = "uksouth"

use_shared_cae = false

use_shared_key_vault               = false
key_vault_name                     = "taskapi-dev-kv-uks"
key_vault_network_mode             = "firewall"
key_vault_private_endpoint_enabled = true
rbac_propagation_wait_seconds      = 45

enable_shared_runner_platform = true
shared_runner_enable_vm       = true

app_env_vars = {
  NODE_ENV = "production"
}

tags = {
  project = "taskapi"
  env     = "dev"
  owner   = "andrei"
}
