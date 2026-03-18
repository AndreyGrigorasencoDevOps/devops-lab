#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

REPO="${GITHUB_REPOSITORY:-}"
PROJECT_NAME=""
TARGET_ENV="dev"
STRICT_RUNNER=false

DEV_KV_NAME=""
PROD_KV_NAME=""
DEV_RESOURCE_GROUP=""
PROD_RESOURCE_GROUP=""
DEV_IDENTITY_NAME=""
PROD_IDENTITY_NAME=""

RUNNER_RESOURCE_GROUP=""
RUNNER_VNET_NAME=""
RUNNER_SUBNET_NAME=""
RUNNER_PE_SUBNET_NAME=""
RUNNER_DNS_ZONE_NAME=""
RUNNER_VM_NAME=""
RUNNER_EXPECTED_LOCATION=""

# Defaults aligned with terraform/variables.tf
DEFAULT_RUNNER_VNET_NAME="taskapi-shared-runner-vnet-uks"
DEFAULT_RUNNER_SUBNET_NAME="taskapi-shared-runner-snet"
DEFAULT_RUNNER_PE_SUBNET_NAME="taskapi-shared-pe-snet"
DEFAULT_RUNNER_DNS_ZONE_NAME="privatelink.vaultcore.azure.net"
DEFAULT_RUNNER_VM_NAME="taskapi-shared-cd-runner-01"
DEFAULT_RUNTIME_VNET_SUFFIX="-rt-vnet-uks"
DEFAULT_CAE_SUBNET_SUFFIX="-cae-snet"
DEFAULT_RUNTIME_PE_SUBNET_SUFFIX="-pe-snet"
DEFAULT_CAE_SUFFIX="-cae-uks"

FAILURES=0
WARNINGS=0

ENV_KV_NAME=""
ENV_KV_RG=""
ENV_KV_MODE=""
ENV_KV_PE_ENABLED="true"
ENV_USE_SHARED_KV="false"
ENV_USE_SHARED_CAE="false"
ENV_CAE_NAME=""
ENV_RUNTIME_VNET_NAME=""
ENV_CAE_SUBNET_NAME=""
ENV_RUNTIME_PE_SUBNET_NAME=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/check-post-refactor-prereqs.sh [options]

Options:
  --environment <dev|prod>       Target environment for preflight (default: dev)
  --repo <owner/repo>            GitHub repository (default: infer from env/git remote)
  --project <name>               Terraform project name (default: inferred from terraform/variables.tf)
  --dev-kv-name <name>           Override dev Key Vault name
  --prod-kv-name <name>          Override prod Key Vault name
  --dev-rg <name>                Override dev resource group (default: <project>-dev-rg-uks)
  --prod-rg <name>               Override prod resource group (default: <project>-prod-rg-uks)
  --dev-identity <name>          Override dev runtime identity name (default: <project>-dev-ca-identity)
  --prod-identity <name>         Override prod runtime identity name (default: <project>-prod-ca-identity)
  --runner-rg <name>             Override shared runner resource group
  --runner-vnet <name>           Override shared runner VNet name
  --runner-subnet <name>         Override shared runner subnet name
  --runner-pe-subnet <name>      Override shared private-endpoint subnet name
  --runner-dns-zone <name>       Override shared private DNS zone name
  --runner-vm <name>             Override shared runner VM name
  --strict-runner                Fail when runner readiness checks fail
  -h, --help                     Show this help

Read-only checks:
  1) Terraform intent for target env (dedicated KV + dedicated CAE + approved network mode + private endpoint)
  2) Key Vault existence, network posture, and DB secret contract
  3) Runtime identity role scope (`Key Vault Secrets User` on env KV)
  4) Deploy identity role scope (`Key Vault Secrets Officer` on env KV)
  5) Shared runner network + private DNS prerequisites
  6) Runtime VNet / CAE / peering prerequisites
  7) Optional GitHub runner readiness check for labels `taskapi-cd,vnet`
USAGE
}

pass() {
  printf '[PASS] %s\n' "$1"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  printf '[WARN] %s\n' "$1"
}

fail() {
  FAILURES=$((FAILURES + 1))
  printf '[FAIL] %s\n' "$1"
}

first_line() {
  printf '%s\n' "$1" | head -n 1
}

is_gh_forbidden_error() {
  local msg="$1"
  printf '%s' "${msg}" | grep -qiE 'HTTP 403|forbidden|insufficient|Resource not accessible by integration|requires admin access'
}

extract_default_project() {
  sed -n '/variable "project"/,/}/s/.*default[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
    "${REPO_ROOT}/terraform/variables.tf" | head -n 1
}

extract_tfvar_string() {
  local file="$1"
  local key="$2"
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "${file}" | head -n 1
}

extract_tfvar_bool() {
  local file="$1"
  local key="$2"
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\(true\|false\).*/\1/p" "${file}" | head -n 1
}

coalesce() {
  local value
  for value in "$@"; do
    if [[ -n "${value}" ]]; then
      printf '%s' "${value}"
      return
    fi
  done
  printf ''
}

infer_repo() {
  if [[ -n "${REPO}" ]]; then
    return
  fi

  local origin_url
  origin_url="$(git -C "${REPO_ROOT}" config --get remote.origin.url 2>/dev/null || true)"
  if [[ -n "${origin_url}" ]]; then
    if [[ "${origin_url}" =~ github\.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
      REPO="${BASH_REMATCH[1]}"
      return
    fi
  fi

  REPO=""
}

resolve_env_settings() {
  local tfvars_file
  local dev_tfvars_file
  local use_shared_runner_platform
  local tf_runner_rg

  tfvars_file="${REPO_ROOT}/terraform/vars/${TARGET_ENV}.tfvars"
  dev_tfvars_file="${REPO_ROOT}/terraform/vars/dev.tfvars"
  if [[ ! -f "${tfvars_file}" ]]; then
    fail "Missing tfvars file: ${tfvars_file}"
    return
  fi

  ENV_USE_SHARED_CAE="$(extract_tfvar_bool "${tfvars_file}" "use_shared_cae")"
  if [[ -z "${ENV_USE_SHARED_CAE}" ]]; then
    ENV_USE_SHARED_CAE="false"
  fi

  ENV_USE_SHARED_KV="$(extract_tfvar_bool "${tfvars_file}" "use_shared_key_vault")"
  if [[ -z "${ENV_USE_SHARED_KV}" ]]; then
    ENV_USE_SHARED_KV="false"
  fi

  if [[ "${TARGET_ENV}" == "dev" ]]; then
    DEV_KV_NAME="$(coalesce "${DEV_KV_NAME}" "$(extract_tfvar_string "${tfvars_file}" "key_vault_name")")"
  else
    PROD_KV_NAME="$(coalesce "${PROD_KV_NAME}" "$(extract_tfvar_string "${tfvars_file}" "key_vault_name")")"
  fi

  if [[ "${TARGET_ENV}" == "dev" ]]; then
    ENV_KV_NAME="${DEV_KV_NAME}"
    ENV_KV_RG="${DEV_RESOURCE_GROUP}"
  else
    ENV_KV_NAME="${PROD_KV_NAME}"
    ENV_KV_RG="${PROD_RESOURCE_GROUP}"
  fi

  ENV_KV_MODE="$(extract_tfvar_string "${tfvars_file}" "key_vault_network_mode")"
  if [[ -z "${ENV_KV_MODE}" ]]; then
    ENV_KV_MODE="public_allow"
  fi

  ENV_KV_PE_ENABLED="$(extract_tfvar_bool "${tfvars_file}" "key_vault_private_endpoint_enabled")"
  if [[ -z "${ENV_KV_PE_ENABLED}" ]]; then
    ENV_KV_PE_ENABLED="true"
  fi

  ENV_CAE_NAME="$(extract_tfvar_string "${tfvars_file}" "container_app_environment_name")"
  if [[ -z "${ENV_CAE_NAME}" ]]; then
    ENV_CAE_NAME="${PROJECT_NAME}-${TARGET_ENV}${DEFAULT_CAE_SUFFIX}"
  fi

  ENV_RUNTIME_VNET_NAME="$(extract_tfvar_string "${tfvars_file}" "runtime_virtual_network_name")"
  if [[ -z "${ENV_RUNTIME_VNET_NAME}" ]]; then
    ENV_RUNTIME_VNET_NAME="${PROJECT_NAME}-${TARGET_ENV}${DEFAULT_RUNTIME_VNET_SUFFIX}"
  fi

  ENV_CAE_SUBNET_NAME="$(extract_tfvar_string "${tfvars_file}" "container_app_environment_infrastructure_subnet_name")"
  if [[ -z "${ENV_CAE_SUBNET_NAME}" ]]; then
    ENV_CAE_SUBNET_NAME="${PROJECT_NAME}-${TARGET_ENV}${DEFAULT_CAE_SUBNET_SUFFIX}"
  fi

  ENV_RUNTIME_PE_SUBNET_NAME="$(extract_tfvar_string "${tfvars_file}" "runtime_private_endpoints_subnet_name")"
  if [[ -z "${ENV_RUNTIME_PE_SUBNET_NAME}" ]]; then
    ENV_RUNTIME_PE_SUBNET_NAME="${PROJECT_NAME}-${TARGET_ENV}${DEFAULT_RUNTIME_PE_SUBNET_SUFFIX}"
  fi

  use_shared_runner_platform="$(extract_tfvar_bool "${tfvars_file}" "enable_shared_runner_platform")"
  if [[ -z "${use_shared_runner_platform}" ]]; then
    use_shared_runner_platform="false"
  fi

  tf_runner_rg="$(extract_tfvar_string "${tfvars_file}" "shared_runner_resource_group_name")"

  if [[ "${use_shared_runner_platform}" == "true" ]]; then
    RUNNER_RESOURCE_GROUP="$(coalesce "${RUNNER_RESOURCE_GROUP}" "${DEV_RESOURCE_GROUP}")"
  else
    RUNNER_RESOURCE_GROUP="$(coalesce "${RUNNER_RESOURCE_GROUP}" "${tf_runner_rg}" "${DEV_RESOURCE_GROUP}")"
  fi

  RUNNER_VNET_NAME="$(coalesce "${RUNNER_VNET_NAME}" "$(extract_tfvar_string "${tfvars_file}" "shared_runner_vnet_name")" "${DEFAULT_RUNNER_VNET_NAME}")"
  RUNNER_SUBNET_NAME="$(coalesce "${RUNNER_SUBNET_NAME}" "$(extract_tfvar_string "${tfvars_file}" "shared_runner_subnet_name")" "${DEFAULT_RUNNER_SUBNET_NAME}")"
  RUNNER_PE_SUBNET_NAME="$(coalesce "${RUNNER_PE_SUBNET_NAME}" "$(extract_tfvar_string "${tfvars_file}" "shared_runner_private_endpoints_subnet_name")" "${DEFAULT_RUNNER_PE_SUBNET_NAME}")"
  RUNNER_DNS_ZONE_NAME="$(coalesce "${RUNNER_DNS_ZONE_NAME}" "$(extract_tfvar_string "${tfvars_file}" "shared_runner_private_dns_zone_name")" "${DEFAULT_RUNNER_DNS_ZONE_NAME}")"
  RUNNER_VM_NAME="$(coalesce "${RUNNER_VM_NAME}" "$(extract_tfvar_string "${tfvars_file}" "shared_runner_vm_name")" "${DEFAULT_RUNNER_VM_NAME}")"

  if [[ -f "${dev_tfvars_file}" ]]; then
    RUNNER_EXPECTED_LOCATION="$(coalesce \
      "${RUNNER_EXPECTED_LOCATION}" \
      "$(extract_tfvar_string "${dev_tfvars_file}" "shared_runner_location")" \
      "$(extract_tfvar_string "${dev_tfvars_file}" "location")" \
      "uksouth")"
  else
    RUNNER_EXPECTED_LOCATION="$(coalesce "${RUNNER_EXPECTED_LOCATION}" "uksouth")"
  fi
}

check_key_vault_secret_exists() {
  local kv_name="$1"
  local secret_name="$2"

  if az keyvault secret show --vault-name "${kv_name}" --name "${secret_name}" --query id -o tsv >/dev/null 2>&1; then
    pass "Key Vault secret '${secret_name}' exists in '${kv_name}'"
  else
    fail "Key Vault secret '${secret_name}' is missing in '${kv_name}'"
  fi
}

check_key_vault_secret_optional() {
  local kv_name="$1"
  local secret_name="$2"

  if az keyvault secret show --vault-name "${kv_name}" --name "${secret_name}" --query id -o tsv >/dev/null 2>&1; then
    pass "Key Vault optional secret '${secret_name}' exists in '${kv_name}'"
  else
    warn "Key Vault optional secret '${secret_name}' is missing in '${kv_name}' (Terraform can recreate it during apply)"
  fi
}

check_runtime_identity_role() {
  local identity_name="$1"
  local identity_rg="$2"
  local kv_id="$3"
  local principal_id
  local assignment_count

  principal_id="$(az identity show \
    --name "${identity_name}" \
    --resource-group "${identity_rg}" \
    --query principalId \
    -o tsv 2>/dev/null || true)"

  if [[ -z "${principal_id}" ]]; then
    warn "Runtime identity '${identity_name}' not found in '${identity_rg}' (likely first bootstrap)"
    return
  fi

  assignment_count="$(az role assignment list \
    --assignee-object-id "${principal_id}" \
    --scope "${kv_id}" \
    --query "[?roleDefinitionName=='Key Vault Secrets User'] | length(@)" \
    -o tsv 2>/dev/null || echo "0")"

  if [[ "${assignment_count}" =~ ^[0-9]+$ ]] && [[ "${assignment_count}" -ge 1 ]]; then
    pass "Runtime identity '${identity_name}' has 'Key Vault Secrets User' on env Key Vault"
  else
    fail "Runtime identity '${identity_name}' is missing 'Key Vault Secrets User' on env Key Vault"
  fi
}

check_deploy_identity_role() {
  local deploy_client_id="$1"
  local kv_id="$2"
  local assignment_count

  if [[ -z "${deploy_client_id}" ]]; then
    warn "Deploy identity client id is empty (set ARM_CLIENT_ID or AZURE_CLIENT_ID to validate deploy identity RBAC)"
    return
  fi

  assignment_count="$(az role assignment list \
    --assignee "${deploy_client_id}" \
    --scope "${kv_id}" \
    --query "[?roleDefinitionName=='Key Vault Secrets Officer'] | length(@)" \
    -o tsv 2>/dev/null || echo "0")"

  if [[ "${assignment_count}" =~ ^[0-9]+$ ]] && [[ "${assignment_count}" -ge 1 ]]; then
    pass "Deploy identity has 'Key Vault Secrets Officer' on env Key Vault"
  else
    fail "Deploy identity is missing 'Key Vault Secrets Officer' on env Key Vault"
  fi
}

check_github_runner_readiness() {
  local matching_count
  local online_count
  local api_error

  if ! command -v gh >/dev/null 2>&1; then
    if [[ "${STRICT_RUNNER}" == "true" ]]; then
      fail "GitHub CLI ('gh') is not installed; cannot validate self-hosted runner readiness"
    else
      warn "GitHub CLI ('gh') is not installed; skipping self-hosted runner readiness check"
    fi
    return
  fi

  if [[ -z "${REPO}" ]]; then
    warn "Repository slug is unresolved; skipping self-hosted runner readiness check"
    return
  fi

  if ! gh auth status >/dev/null 2>&1; then
    if [[ "${STRICT_RUNNER}" == "true" ]]; then
      fail "GitHub CLI is not authenticated; cannot validate self-hosted runner readiness"
    else
      warn "GitHub CLI is not authenticated; skipping self-hosted runner readiness check"
    fi
    return
  fi

  api_error=""
  matching_count="$(gh api "/repos/${REPO}/actions/runners" --jq '[.runners[] | select((.labels | map(.name) | index("taskapi-cd")) and (.labels | map(.name) | index("vnet")))] | length' 2>/tmp/cd_preflight_gh_err.log || true)"
  if [[ -s /tmp/cd_preflight_gh_err.log ]]; then
    api_error="$(cat /tmp/cd_preflight_gh_err.log)"
    rm -f /tmp/cd_preflight_gh_err.log
  fi

  if [[ -n "${api_error}" ]]; then
    if is_gh_forbidden_error "${api_error}"; then
      warn "GitHub token cannot read self-hosted runners in ${REPO} (HTTP 403). Skipping GitHub-side runner status check."
    else
      warn "Unable to query self-hosted runners in ${REPO}: $(first_line "${api_error}")"
    fi
    return
  fi

  online_count="$(gh api "/repos/${REPO}/actions/runners" --jq '[.runners[] | select((.labels | map(.name) | index("taskapi-cd")) and (.labels | map(.name) | index("vnet")) and .status == "online")] | length' 2>/dev/null || echo "0")"

  if [[ "${matching_count}" =~ ^[0-9]+$ ]] && [[ "${matching_count}" -ge 1 ]]; then
    pass "Found ${matching_count} self-hosted runner(s) with labels taskapi-cd,vnet"
  else
    if [[ "${STRICT_RUNNER}" == "true" ]]; then
      fail "No self-hosted runners with labels taskapi-cd,vnet are registered in ${REPO}"
    else
      warn "No self-hosted runners with labels taskapi-cd,vnet are registered in ${REPO}"
    fi
  fi

  if [[ "${online_count}" =~ ^[0-9]+$ ]] && [[ "${online_count}" -ge 1 ]]; then
    pass "At least one matching self-hosted runner is online"
  else
    if [[ "${STRICT_RUNNER}" == "true" ]]; then
      fail "No matching self-hosted runner is online"
    else
      warn "No matching self-hosted runner is online"
    fi
  fi
}

check_runner_infra_in_azure() {
  local vnet_id
  local vnet_location
  local vm_power_state
  local vm_public_ip_count
  local vm_location
  local dns_link_count

  if [[ -z "${RUNNER_RESOURCE_GROUP}" || -z "${RUNNER_VNET_NAME}" || -z "${RUNNER_PE_SUBNET_NAME}" || -z "${RUNNER_DNS_ZONE_NAME}" ]]; then
    fail "Runner network settings are unresolved. Verify tfvars and/or pass explicit --runner-* options."
    return
  fi

  vnet_id="$(az network vnet show \
    --resource-group "${RUNNER_RESOURCE_GROUP}" \
    --name "${RUNNER_VNET_NAME}" \
    --query id -o tsv 2>/dev/null || true)"
  if [[ -z "${vnet_id}" ]]; then
    fail "Runner VNet '${RUNNER_VNET_NAME}' was not found in '${RUNNER_RESOURCE_GROUP}'"
    return
  fi
  pass "Runner VNet '${RUNNER_VNET_NAME}' exists"

  vnet_location="$(az network vnet show \
    --resource-group "${RUNNER_RESOURCE_GROUP}" \
    --name "${RUNNER_VNET_NAME}" \
    --query location -o tsv 2>/dev/null || true)"
  if [[ -n "${RUNNER_EXPECTED_LOCATION}" ]]; then
    if [[ "${vnet_location}" == "${RUNNER_EXPECTED_LOCATION}" ]]; then
      pass "Runner VNet is in expected region '${RUNNER_EXPECTED_LOCATION}'"
    else
      fail "Runner VNet location is '${vnet_location}' (expected '${RUNNER_EXPECTED_LOCATION}')"
    fi
  fi

  if az network vnet subnet show \
    --resource-group "${RUNNER_RESOURCE_GROUP}" \
    --vnet-name "${RUNNER_VNET_NAME}" \
    --name "${RUNNER_SUBNET_NAME}" \
    --query id -o tsv >/dev/null 2>&1; then
    pass "Runner subnet '${RUNNER_SUBNET_NAME}' exists"
  else
    fail "Runner subnet '${RUNNER_SUBNET_NAME}' is missing"
  fi

  if az network vnet subnet show \
    --resource-group "${RUNNER_RESOURCE_GROUP}" \
    --vnet-name "${RUNNER_VNET_NAME}" \
    --name "${RUNNER_PE_SUBNET_NAME}" \
    --query id -o tsv >/dev/null 2>&1; then
    pass "Runner private-endpoint subnet '${RUNNER_PE_SUBNET_NAME}' exists"
  else
    fail "Runner private-endpoint subnet '${RUNNER_PE_SUBNET_NAME}' is missing"
  fi

  if az network private-dns zone show \
    --resource-group "${RUNNER_RESOURCE_GROUP}" \
    --name "${RUNNER_DNS_ZONE_NAME}" \
    --query id -o tsv >/dev/null 2>&1; then
    pass "Private DNS zone '${RUNNER_DNS_ZONE_NAME}' exists"
  else
    fail "Private DNS zone '${RUNNER_DNS_ZONE_NAME}' is missing"
  fi

  dns_link_count="$(az network private-dns link vnet list \
    --resource-group "${RUNNER_RESOURCE_GROUP}" \
    --zone-name "${RUNNER_DNS_ZONE_NAME}" \
    --query "[?virtualNetwork.id=='${vnet_id}'] | length(@)" -o tsv 2>/dev/null || echo "0")"
  if [[ "${dns_link_count}" =~ ^[0-9]+$ ]] && [[ "${dns_link_count}" -ge 1 ]]; then
    pass "Private DNS zone '${RUNNER_DNS_ZONE_NAME}' is linked to runner VNet"
  else
    fail "Private DNS zone '${RUNNER_DNS_ZONE_NAME}' is not linked to runner VNet '${RUNNER_VNET_NAME}'"
  fi

  if [[ "${STRICT_RUNNER}" == "true" ]]; then
    vm_power_state="$(az vm get-instance-view \
      --resource-group "${RUNNER_RESOURCE_GROUP}" \
      --name "${RUNNER_VM_NAME}" \
      --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus | [0]" \
      -o tsv 2>/dev/null || true)"

    if [[ -z "${vm_power_state}" ]]; then
      fail "Runner VM '${RUNNER_VM_NAME}' was not found in '${RUNNER_RESOURCE_GROUP}'"
      return
    fi

    if [[ "${vm_power_state}" == "VM running" ]]; then
      pass "Runner VM '${RUNNER_VM_NAME}' is running"
    else
      fail "Runner VM '${RUNNER_VM_NAME}' is not running (state: ${vm_power_state})"
    fi

    vm_location="$(az vm show \
      --resource-group "${RUNNER_RESOURCE_GROUP}" \
      --name "${RUNNER_VM_NAME}" \
      --query location -o tsv 2>/dev/null || true)"
    if [[ -n "${RUNNER_EXPECTED_LOCATION}" ]]; then
      if [[ "${vm_location}" == "${RUNNER_EXPECTED_LOCATION}" ]]; then
        pass "Runner VM is in expected region '${RUNNER_EXPECTED_LOCATION}'"
      else
        fail "Runner VM location is '${vm_location}' (expected '${RUNNER_EXPECTED_LOCATION}')"
      fi
    fi

    vm_public_ip_count="$(az vm list-ip-addresses \
      --resource-group "${RUNNER_RESOURCE_GROUP}" \
      --name "${RUNNER_VM_NAME}" \
      --query "[0].virtualMachine.network.publicIpAddresses | length(@)" -o tsv 2>/dev/null || echo "0")"

    if [[ "${vm_public_ip_count}" =~ ^[0-9]+$ ]] && [[ "${vm_public_ip_count}" -eq 0 ]]; then
      pass "Runner VM '${RUNNER_VM_NAME}' has no public IP (outbound-only posture)"
    else
      fail "Runner VM '${RUNNER_VM_NAME}' has public IPs attached (expected outbound-only posture)"
    fi
  fi
}

check_runtime_network_in_azure() {
  local runtime_vnet_id
  local runner_vnet_id
  local runtime_dns_link_count
  local runtime_to_runner_peering_count
  local runner_to_runtime_peering_count
  local cae_infra_subnet_id
  local runtime_pe_subnet_id
  local key_vault_pe_subnet_id

  if [[ "${ENV_USE_SHARED_CAE}" == "true" ]]; then
    fail "Terraform tfvars for ${TARGET_ENV} still has use_shared_cae=true (paid normalization requires a dedicated CAE per env)"
    return
  fi

  runtime_vnet_id="$(az network vnet show \
    --resource-group "${ENV_KV_RG}" \
    --name "${ENV_RUNTIME_VNET_NAME}" \
    --query id -o tsv 2>/dev/null || true)"
  if [[ -z "${runtime_vnet_id}" ]]; then
    fail "Runtime VNet '${ENV_RUNTIME_VNET_NAME}' was not found in '${ENV_KV_RG}'"
    return
  fi
  pass "Runtime VNet '${ENV_RUNTIME_VNET_NAME}' exists"

  if az network vnet subnet show \
    --resource-group "${ENV_KV_RG}" \
    --vnet-name "${ENV_RUNTIME_VNET_NAME}" \
    --name "${ENV_CAE_SUBNET_NAME}" \
    --query id -o tsv >/dev/null 2>&1; then
    pass "Runtime CAE subnet '${ENV_CAE_SUBNET_NAME}' exists"
  else
    fail "Runtime CAE subnet '${ENV_CAE_SUBNET_NAME}' is missing"
  fi

  runtime_pe_subnet_id="$(az network vnet subnet show \
    --resource-group "${ENV_KV_RG}" \
    --vnet-name "${ENV_RUNTIME_VNET_NAME}" \
    --name "${ENV_RUNTIME_PE_SUBNET_NAME}" \
    --query id -o tsv 2>/dev/null || true)"
  if [[ -n "${runtime_pe_subnet_id}" ]]; then
    pass "Runtime private-endpoints subnet '${ENV_RUNTIME_PE_SUBNET_NAME}' exists"
  else
    fail "Runtime private-endpoints subnet '${ENV_RUNTIME_PE_SUBNET_NAME}' is missing"
  fi

  runtime_dns_link_count="$(az network private-dns link vnet list \
    --resource-group "${RUNNER_RESOURCE_GROUP}" \
    --zone-name "${RUNNER_DNS_ZONE_NAME}" \
    --query "[?virtualNetwork.id=='${runtime_vnet_id}'] | length(@)" -o tsv 2>/dev/null || echo "0")"
  if [[ "${runtime_dns_link_count}" =~ ^[0-9]+$ ]] && [[ "${runtime_dns_link_count}" -ge 1 ]]; then
    pass "Private DNS zone '${RUNNER_DNS_ZONE_NAME}' is linked to runtime VNet"
  else
    fail "Private DNS zone '${RUNNER_DNS_ZONE_NAME}' is not linked to runtime VNet '${ENV_RUNTIME_VNET_NAME}'"
  fi

  runner_vnet_id="$(az network vnet show \
    --resource-group "${RUNNER_RESOURCE_GROUP}" \
    --name "${RUNNER_VNET_NAME}" \
    --query id -o tsv 2>/dev/null || true)"
  if [[ -n "${runner_vnet_id}" ]]; then
    runtime_to_runner_peering_count="$(az network vnet peering list \
      --resource-group "${ENV_KV_RG}" \
      --vnet-name "${ENV_RUNTIME_VNET_NAME}" \
      --query "[?remoteVirtualNetwork.id=='${runner_vnet_id}'] | length(@)" -o tsv 2>/dev/null || echo "0")"
    if [[ "${runtime_to_runner_peering_count}" =~ ^[0-9]+$ ]] && [[ "${runtime_to_runner_peering_count}" -ge 1 ]]; then
      pass "Runtime VNet peering to shared runner VNet exists"
    else
      fail "Runtime VNet peering to shared runner VNet is missing"
    fi

    runner_to_runtime_peering_count="$(az network vnet peering list \
      --resource-group "${RUNNER_RESOURCE_GROUP}" \
      --vnet-name "${RUNNER_VNET_NAME}" \
      --query "[?remoteVirtualNetwork.id=='${runtime_vnet_id}'] | length(@)" -o tsv 2>/dev/null || echo "0")"
    if [[ "${runner_to_runtime_peering_count}" =~ ^[0-9]+$ ]] && [[ "${runner_to_runtime_peering_count}" -ge 1 ]]; then
      pass "Shared runner VNet peering back to runtime VNet exists"
    else
      fail "Shared runner VNet peering back to runtime VNet is missing"
    fi
  fi

  cae_infra_subnet_id="$(az containerapp env show \
    --resource-group "${ENV_KV_RG}" \
    --name "${ENV_CAE_NAME}" \
    --query properties.vnetConfiguration.infrastructureSubnetId -o tsv 2>/dev/null || true)"
  if [[ -n "${cae_infra_subnet_id}" ]]; then
    pass "Container Apps Environment '${ENV_CAE_NAME}' exists and is attached to a VNet subnet"
  else
    fail "Container Apps Environment '${ENV_CAE_NAME}' is missing or has no infrastructure subnet attached"
  fi

  key_vault_pe_subnet_id="$(az network private-endpoint show \
    --resource-group "${ENV_KV_RG}" \
    --name "${PROJECT_NAME}-${TARGET_ENV}-kv-pe-uks" \
    --query subnet.id -o tsv 2>/dev/null || true)"
  if [[ -n "${key_vault_pe_subnet_id}" && "${key_vault_pe_subnet_id}" == "${runtime_pe_subnet_id}" ]]; then
    pass "Key Vault private endpoint is attached to the env runtime private-endpoints subnet"
  else
    fail "Key Vault private endpoint is not attached to the env runtime private-endpoints subnet"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment)
      TARGET_ENV="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --project)
      PROJECT_NAME="${2:-}"
      shift 2
      ;;
    --dev-kv-name)
      DEV_KV_NAME="${2:-}"
      shift 2
      ;;
    --prod-kv-name)
      PROD_KV_NAME="${2:-}"
      shift 2
      ;;
    --dev-rg)
      DEV_RESOURCE_GROUP="${2:-}"
      shift 2
      ;;
    --prod-rg)
      PROD_RESOURCE_GROUP="${2:-}"
      shift 2
      ;;
    --dev-identity)
      DEV_IDENTITY_NAME="${2:-}"
      shift 2
      ;;
    --prod-identity)
      PROD_IDENTITY_NAME="${2:-}"
      shift 2
      ;;
    --runner-rg)
      RUNNER_RESOURCE_GROUP="${2:-}"
      shift 2
      ;;
    --runner-vnet)
      RUNNER_VNET_NAME="${2:-}"
      shift 2
      ;;
    --runner-subnet)
      RUNNER_SUBNET_NAME="${2:-}"
      shift 2
      ;;
    --runner-pe-subnet)
      RUNNER_PE_SUBNET_NAME="${2:-}"
      shift 2
      ;;
    --runner-dns-zone)
      RUNNER_DNS_ZONE_NAME="${2:-}"
      shift 2
      ;;
    --runner-vm)
      RUNNER_VM_NAME="${2:-}"
      shift 2
      ;;
    --strict-runner)
      STRICT_RUNNER=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ "${TARGET_ENV}" != "dev" && "${TARGET_ENV}" != "prod" ]]; then
  fail "--environment must be 'dev' or 'prod'"
  exit 2
fi

if [[ -z "${PROJECT_NAME}" ]]; then
  PROJECT_NAME="$(extract_default_project)"
fi

if [[ -z "${DEV_RESOURCE_GROUP}" && -n "${PROJECT_NAME}" ]]; then
  DEV_RESOURCE_GROUP="${PROJECT_NAME}-dev-rg-uks"
fi
if [[ -z "${PROD_RESOURCE_GROUP}" && -n "${PROJECT_NAME}" ]]; then
  PROD_RESOURCE_GROUP="${PROJECT_NAME}-prod-rg-uks"
fi
if [[ -z "${DEV_IDENTITY_NAME}" && -n "${PROJECT_NAME}" ]]; then
  DEV_IDENTITY_NAME="${PROJECT_NAME}-dev-ca-identity"
fi
if [[ -z "${PROD_IDENTITY_NAME}" && -n "${PROJECT_NAME}" ]]; then
  PROD_IDENTITY_NAME="${PROJECT_NAME}-prod-ca-identity"
fi

infer_repo
resolve_env_settings

printf '\n== Context ==\n'
printf 'Target env: %s\n' "${TARGET_ENV}"
printf 'Repo: %s\n' "${REPO:-n/a}"
printf 'Project: %s\n' "${PROJECT_NAME:-n/a}"
printf 'Env Key Vault: %s (rg: %s)\n' "${ENV_KV_NAME:-n/a}" "${ENV_KV_RG:-n/a}"
printf 'Env CAE / runtime VNet: %s / %s\n' "${ENV_CAE_NAME:-n/a}" "${ENV_RUNTIME_VNET_NAME:-n/a}"
printf 'Runner RG/VNet: %s / %s\n' "${RUNNER_RESOURCE_GROUP:-n/a}" "${RUNNER_VNET_NAME:-n/a}"
printf 'Runner PE subnet: %s\n' "${RUNNER_PE_SUBNET_NAME:-n/a}"
printf 'Runner DNS zone: %s\n' "${RUNNER_DNS_ZONE_NAME:-n/a}"
printf 'Runner expected location: %s\n' "${RUNNER_EXPECTED_LOCATION:-n/a}"
printf 'Strict runner mode: %s\n' "${STRICT_RUNNER}"
printf '\n'

check_github_runner_readiness

printf '== Azure checks ==\n'
if ! command -v az >/dev/null 2>&1; then
  fail "Azure CLI ('az') is not installed"
else
  if az account show >/dev/null 2>&1; then
    pass "Azure CLI auth is active"

    if [[ "${ENV_USE_SHARED_KV}" == "true" ]]; then
      fail "Terraform tfvars for ${TARGET_ENV} still has use_shared_key_vault=true (Phase 2 requires dedicated Key Vault per env)"
    else
      pass "Terraform tfvars for ${TARGET_ENV} uses dedicated Key Vault"
    fi

    if [[ "${ENV_USE_SHARED_CAE}" == "true" ]]; then
      fail "Terraform tfvars for ${TARGET_ENV} still has use_shared_cae=true (paid normalization requires a dedicated CAE per env)"
    else
      pass "Terraform tfvars for ${TARGET_ENV} uses a dedicated CAE"
    fi

    if [[ "${ENV_KV_MODE}" == "firewall" ]]; then
      pass "key_vault_network_mode is 'firewall' for ${TARGET_ENV}"
    elif [[ "${ENV_KV_MODE}" == "public_allow" ]]; then
      pass "key_vault_network_mode is 'public_allow' for ${TARGET_ENV} (runtime compatibility mode)"
    else
      fail "key_vault_network_mode for ${TARGET_ENV} is '${ENV_KV_MODE}' (expected 'public_allow' or 'firewall')"
    fi

    if [[ "${ENV_KV_PE_ENABLED}" == "true" ]]; then
      pass "key_vault_private_endpoint_enabled is true for ${TARGET_ENV}"
    else
      fail "key_vault_private_endpoint_enabled for ${TARGET_ENV} is false (expected true)"
    fi

    if [[ -z "${ENV_KV_NAME}" || -z "${ENV_KV_RG}" ]]; then
      fail "Environment Key Vault coordinates are unresolved"
    else
      KV_ID="$(az keyvault show --name "${ENV_KV_NAME}" --resource-group "${ENV_KV_RG}" --query id -o tsv 2>/dev/null || true)"
      if [[ -z "${KV_ID}" ]]; then
        fail "Key Vault '${ENV_KV_NAME}' in '${ENV_KV_RG}' was not found"
      else
        pass "Key Vault '${ENV_KV_NAME}' exists"

        KV_DEFAULT_ACTION="$(az keyvault show --name "${ENV_KV_NAME}" --resource-group "${ENV_KV_RG}" --query properties.networkAcls.defaultAction -o tsv 2>/dev/null || true)"
        KV_PUBLIC_NETWORK_ACCESS="$(az keyvault show --name "${ENV_KV_NAME}" --resource-group "${ENV_KV_RG}" --query properties.publicNetworkAccess -o tsv 2>/dev/null || true)"
        if [[ "${ENV_KV_MODE}" == "firewall" ]]; then
          if [[ "${KV_DEFAULT_ACTION}" == "Deny" ]]; then
            pass "Key Vault network ACL defaultAction is Deny (firewall mode)"
          else
            fail "Key Vault network ACL defaultAction is '${KV_DEFAULT_ACTION}' (expected Deny in firewall mode)"
          fi
        else
          if [[ "${KV_DEFAULT_ACTION}" == "Allow" ]]; then
            pass "Key Vault network ACL defaultAction is Allow (public_allow mode)"
          elif [[ -z "${KV_DEFAULT_ACTION}" && "${KV_PUBLIC_NETWORK_ACCESS}" == "Enabled" ]]; then
            pass "Key Vault network ACL object is absent and publicNetworkAccess is Enabled (public_allow mode)"
          else
            fail "Key Vault network mode mismatch: defaultAction='${KV_DEFAULT_ACTION}', publicNetworkAccess='${KV_PUBLIC_NETWORK_ACCESS}' (expected Allow/Enabled in public_allow mode)"
          fi
        fi

        KV_BYPASS="$(az keyvault show --name "${ENV_KV_NAME}" --resource-group "${ENV_KV_RG}" --query properties.networkAcls.bypass -o tsv 2>/dev/null || true)"
        if [[ "${ENV_KV_MODE}" == "firewall" ]]; then
          if [[ "${KV_BYPASS}" == "None" ]]; then
            pass "Key Vault bypass is None (firewall mode)"
          else
            fail "Key Vault bypass is '${KV_BYPASS}' (expected None in firewall mode)"
          fi
        elif [[ "${KV_BYPASS}" == "AzureServices" ]]; then
          pass "Key Vault bypass is AzureServices (public_allow mode)"
        elif [[ -z "${KV_BYPASS}" ]]; then
          pass "Key Vault bypass is absent while still in public_allow mode"
        else
          warn "Key Vault bypass is '${KV_BYPASS}' (expected AzureServices in public_allow mode)"
        fi

        KV_PE_COUNT="$(az keyvault show --name "${ENV_KV_NAME}" --resource-group "${ENV_KV_RG}" --query 'length(properties.privateEndpointConnections)' -o tsv 2>/dev/null || echo "0")"
        if [[ "${KV_PE_COUNT}" =~ ^[0-9]+$ ]] && [[ "${KV_PE_COUNT}" -ge 1 ]]; then
          pass "Key Vault has private endpoint connection(s)"
        else
          fail "Key Vault has no private endpoint connections"
        fi

        check_key_vault_secret_exists "${ENV_KV_NAME}" "${TARGET_ENV}-db-password"
        for key_name in host port user name; do
          check_key_vault_secret_optional "${ENV_KV_NAME}" "${TARGET_ENV}-db-${key_name}"
        done

        if [[ "${TARGET_ENV}" == "dev" ]]; then
          check_runtime_identity_role "${DEV_IDENTITY_NAME}" "${DEV_RESOURCE_GROUP}" "${KV_ID}"
        else
          check_runtime_identity_role "${PROD_IDENTITY_NAME}" "${PROD_RESOURCE_GROUP}" "${KV_ID}"
        fi

        DEPLOY_CLIENT_ID="${ARM_CLIENT_ID:-${AZURE_CLIENT_ID:-}}"
        check_deploy_identity_role "${DEPLOY_CLIENT_ID}" "${KV_ID}"
      fi
    fi

    check_runner_infra_in_azure
    check_runtime_network_in_azure
  else
    fail "Azure CLI is not authenticated (run: az login)"
  fi
fi

printf '\n== Result ==\n'
printf 'Failures: %s\n' "${FAILURES}"
printf 'Warnings: %s\n' "${WARNINGS}"

if [[ "${FAILURES}" -gt 0 ]]; then
  exit 1
fi
