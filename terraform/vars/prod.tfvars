env      = "prod"
location = "uksouth"

use_shared_cae                 = true
shared_cae_name                = "taskapi-dev-cae-uks"
shared_cae_resource_group_name = "taskapi-dev-rg-uks"

use_shared_key_vault                 = true
shared_key_vault_name                = "taskapi-shared-kv-uks"
shared_key_vault_resource_group_name = "taskapi-dev-rg-uks"
key_vault_network_mode               = "public_allow"
rbac_propagation_wait_seconds        = 45

app_env_vars = {
  NODE_ENV = "production"
}

tags = {
  project = "taskapi"
  env     = "prod"
  owner   = "andrei"
}
