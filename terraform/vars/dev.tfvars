env      = "dev"
location = "uksouth"

use_shared_cae = false

use_shared_key_vault = false
key_vault_name       = "taskapi-shared-kv-uks"
key_vault_network_mode = "public_allow"
rbac_propagation_wait_seconds = 45

app_env_vars = {
  NODE_ENV = "production"
}

tags = {
  project = "taskapi"
  env     = "dev"
  owner   = "andrei"
}
