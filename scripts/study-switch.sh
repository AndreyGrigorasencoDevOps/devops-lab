#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/study-switch.sh --environment <dev|prod> --operation <wake|sleep|reset> [options]

Options:
  --environment <name>    Target environment (`dev` or `prod`).
  --operation <name>      Switch action (`wake`, `sleep`, or `reset`).
  --warm-app <bool>       Whether `wake` should poll `https://<fqdn>/ready` afterwards. Default: true.
  --confirm-reset <text>  Required value `RESET` when --operation reset.
  --terraform-dir <path>  Terraform root. Default: <repo>/terraform
  --help                  Show this help text.
EOF
}

log() {
  printf '%s\n' "$*"
}

warn() {
  printf '::warning::%s\n' "$*"
}

fail() {
  printf '::error::%s\n' "$*" >&2
  exit 1
}

coalesce() {
  local candidate
  for candidate in "$@"; do
    if [[ -n "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
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

extract_var_default_string() {
  local file="$1"
  local key="$2"
  sed -n "/variable \"${key}\"/,/}/s/.*default[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" "${file}" | head -n 1
}

extract_var_default_bool() {
  local file="$1"
  local key="$2"
  sed -n "/variable \"${key}\"/,/}/s/.*default[[:space:]]*=[[:space:]]*\(true\|false\).*/\1/p" "${file}" | head -n 1
}

cleanup_break_glass_allowlist() {
  local exit_code="$1"
  trap - EXIT

  if [[ "${BREAK_GLASS_ALLOWLIST_ADDED}" == "true" ]]; then
    if az keyvault show \
      --name "${BREAK_GLASS_KEY_VAULT_NAME}" \
      --resource-group "${BREAK_GLASS_KEY_VAULT_RG}" \
      --query id -o tsv >/dev/null 2>&1; then
      az keyvault network-rule remove \
        --name "${BREAK_GLASS_KEY_VAULT_NAME}" \
        --resource-group "${BREAK_GLASS_KEY_VAULT_RG}" \
        --ip-address "${RUNNER_PUBLIC_IP}" >/dev/null || true
      log "Removed temporary Key Vault allowlist entry for ${ENVIRONMENT}."
    else
      warn "Key Vault '${BREAK_GLASS_KEY_VAULT_NAME}' no longer exists; no temporary allowlist cleanup required."
    fi
  fi

  exit "${exit_code}"
}

ensure_command() {
  local command_name="$1"
  command -v "${command_name}" >/dev/null 2>&1 || fail "Required command '${command_name}' is not installed."
}

is_not_found_error() {
  local error_text="$1"
  printf '%s' "${error_text}" | grep -qiE 'ResourceGroupNotFound|ResourceNotFound|could not be found|was not found|does not exist|HTTP 404|StatusCode: 404'
}

ensure_expected_subscription_context() {
  local expected_subscription_id
  local active_subscription_id
  local error_file
  local error_text

  expected_subscription_id="$(coalesce "${ARM_SUBSCRIPTION_ID:-}" "${AZURE_SUBSCRIPTION_ID:-}")"
  if [[ -z "${expected_subscription_id}" ]]; then
    return 0
  fi

  error_file="$(mktemp)"
  if active_subscription_id="$(az account show --query id -o tsv 2>"${error_file}")"; then
    rm -f "${error_file}"
  else
    error_text="$(tr '\n' ' ' <"${error_file}" | sed 's/[[:space:]]\+/ /g')"
    rm -f "${error_file}"
    fail "Unable to resolve the active Azure subscription context: ${error_text}"
  fi

  if [[ "${active_subscription_id}" != "${expected_subscription_id}" ]]; then
    fail "Active Azure subscription '${active_subscription_id}' does not match expected '${expected_subscription_id}'."
  fi
}

ensure_resource_group_exists() {
  local error_file
  local error_text

  error_file="$(mktemp)"
  if az group show --name "${RESOURCE_GROUP_NAME}" --query id -o tsv >/dev/null 2>"${error_file}"; then
    rm -f "${error_file}"
    return 0
  fi

  error_text="$(tr '\n' ' ' <"${error_file}" | sed 's/[[:space:]]\+/ /g')"
  rm -f "${error_file}"

  if is_not_found_error "${error_text}"; then
    warn "Resource group '${RESOURCE_GROUP_NAME}' does not exist for '${ENVIRONMENT}'. Treating ${OPERATION} as a no-op."
    exit 0
  fi

  fail "Failed to inspect resource group '${RESOURCE_GROUP_NAME}': ${error_text}"
}

ensure_terraform_init() {
  if [[ "${TERRAFORM_INITIALIZED}" == "true" ]]; then
    return 0
  fi

  log "Initializing Terraform for ${ENVIRONMENT}."
  terraform -chdir="${TERRAFORM_DIR}" init -backend-config="backend/${ENVIRONMENT}.hcl" -reconfigure -input=false
  TERRAFORM_INITIALIZED="true"
}

resolve_postgres_server_name() {
  local matches
  local match_count

  matches="$(
    az postgres flexible-server list \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --query "[?starts_with(name, '${POSTGRES_SERVER_NAME_PREFIX}')].name" \
      -o tsv
  )"

  match_count="$(printf '%s\n' "${matches}" | sed '/^$/d' | wc -l | tr -d ' ')"

  if [[ "${match_count}" == "0" ]]; then
    return 0
  fi

  if [[ "${match_count}" != "1" ]]; then
    fail "Expected at most one PostgreSQL server matching '${POSTGRES_SERVER_NAME_PREFIX}*' in '${RESOURCE_GROUP_NAME}', found ${match_count}."
  fi

  printf '%s\n' "${matches}" | sed '/^$/d' | head -n 1
}

resolve_postgres_server_state() {
  local server_name="$1"
  az postgres flexible-server show \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${server_name}" \
    --query state -o tsv
}

postgres_database_exists() {
  local server_name="$1"
  local error_file
  local error_text

  error_file="$(mktemp)"
  if az postgres flexible-server db show \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --server-name "${server_name}" \
    --database-name "${POSTGRES_DATABASE_NAME}" \
    --query name -o tsv >/dev/null 2>"${error_file}"; then
    rm -f "${error_file}"
    return 0
  fi

  error_text="$(tr '\n' ' ' <"${error_file}" | sed 's/[[:space:]]\+/ /g')"
  rm -f "${error_file}"

  if is_not_found_error "${error_text}"; then
    return 1
  fi

  fail "Failed to inspect database '${POSTGRES_DATABASE_NAME}' on '${server_name}': ${error_text}"
}

postgres_firewall_rule_exists() {
  local server_name="$1"
  local error_file
  local error_text

  error_file="$(mktemp)"
  if az postgres flexible-server firewall-rule show \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${server_name}" \
    --rule-name "${POSTGRES_FIREWALL_RULE_NAME}" \
    --query name -o tsv >/dev/null 2>"${error_file}"; then
    rm -f "${error_file}"
    return 0
  fi

  error_text="$(tr '\n' ' ' <"${error_file}" | sed 's/[[:space:]]\+/ /g')"
  rm -f "${error_file}"

  if is_not_found_error "${error_text}"; then
    return 1
  fi

  fail "Failed to inspect firewall rule '${POSTGRES_FIREWALL_RULE_NAME}' on '${server_name}': ${error_text}"
}

database_slice_needs_reconcile() {
  local server_name="$1"

  if ! postgres_database_exists "${server_name}"; then
    warn "Database '${POSTGRES_DATABASE_NAME}' is missing on '${server_name}'. Targeted Terraform apply will reconcile the DB slice."
    return 0
  fi

  if [[ "${POSTGRES_PUBLIC_NETWORK_ACCESS_ENABLED}" == "true" ]] && ! postgres_firewall_rule_exists "${server_name}"; then
    warn "Firewall rule '${POSTGRES_FIREWALL_RULE_NAME}' is missing on '${server_name}'. Targeted Terraform apply will reconcile the DB slice."
    return 0
  fi

  return 1
}

wait_for_postgres_state() {
  local server_name="$1"
  local desired_state="$2"
  local timeout_seconds="${3:-900}"
  local poll_interval_seconds=10
  local max_attempts
  local current_state

  max_attempts="$(( timeout_seconds / poll_interval_seconds ))"

  for _ in $(seq 1 "${max_attempts}"); do
    current_state="$(resolve_postgres_server_state "${server_name}" || true)"
    if [[ "${current_state}" == "${desired_state}" ]]; then
      log "PostgreSQL server '${server_name}' reached state '${desired_state}'."
      return 0
    fi

    sleep "${poll_interval_seconds}"
  done

  fail "Timed out waiting for PostgreSQL server '${server_name}' to reach state '${desired_state}'."
}

ensure_break_glass_key_vault_access() {
  local preexisting_rule_count

  if [[ -n "${RUNNER_PUBLIC_IP}" ]]; then
    return 0
  fi

  if ! az keyvault show \
    --name "${BREAK_GLASS_KEY_VAULT_NAME}" \
    --resource-group "${BREAK_GLASS_KEY_VAULT_RG}" \
    --query id -o tsv >/dev/null 2>&1; then
    fail "Key Vault '${BREAK_GLASS_KEY_VAULT_NAME}' was not found in '${BREAK_GLASS_KEY_VAULT_RG}'."
  fi

  RUNNER_PUBLIC_IP="$(curl -fsS https://api.ipify.org)"
  preexisting_rule_count="$(
    az keyvault network-rule list \
      --name "${BREAK_GLASS_KEY_VAULT_NAME}" \
      --resource-group "${BREAK_GLASS_KEY_VAULT_RG}" \
      --query "ipRules[?value=='${RUNNER_PUBLIC_IP}'] | length(@)" \
      -o tsv
  )"

  if [[ "${preexisting_rule_count}" == "1" ]]; then
    log "Hosted runner IP is already allowlisted on '${BREAK_GLASS_KEY_VAULT_NAME}'."
    return 0
  fi

  log "Temporarily allowlisting hosted runner IP on '${BREAK_GLASS_KEY_VAULT_NAME}'."
  az keyvault network-rule add \
    --name "${BREAK_GLASS_KEY_VAULT_NAME}" \
    --resource-group "${BREAK_GLASS_KEY_VAULT_RG}" \
    --ip-address "${RUNNER_PUBLIC_IP}" >/dev/null

  BREAK_GLASS_ALLOWLIST_ADDED="true"
  sleep 10
}

build_terraform_targets() {
  TERRAFORM_DB_TARGETS=(
    "azurerm_postgresql_flexible_server.main"
    "azurerm_postgresql_flexible_server_database.main"
  )

  if [[ "${POSTGRES_PUBLIC_NETWORK_ACCESS_ENABLED}" == "true" ]]; then
    TERRAFORM_DB_TARGETS+=("azurerm_postgresql_flexible_server_firewall_rule.allow_azure_services[0]")
  fi
}

run_targeted_terraform_apply() {
  local terraform_args
  local target

  ensure_terraform_init
  ensure_break_glass_key_vault_access
  build_terraform_targets

  terraform_args=(
    "-chdir=${TERRAFORM_DIR}"
    "apply"
    "-var-file=vars/${ENVIRONMENT}.tfvars"
    "-auto-approve"
    "-input=false"
  )

  for target in "${TERRAFORM_DB_TARGETS[@]}"; do
    terraform_args+=("-target=${target}")
  done

  log "Recreating the PostgreSQL slice for ${ENVIRONMENT}."
  terraform "${terraform_args[@]}"
}

run_targeted_terraform_destroy() {
  local terraform_args
  local target

  ensure_terraform_init
  ensure_break_glass_key_vault_access
  build_terraform_targets

  terraform_args=(
    "-chdir=${TERRAFORM_DIR}"
    "destroy"
    "-var-file=vars/${ENVIRONMENT}.tfvars"
    "-auto-approve"
    "-input=false"
  )

  for target in "${TERRAFORM_DB_TARGETS[@]}"; do
    terraform_args+=("-target=${target}")
  done

  log "Destroying only the PostgreSQL slice for ${ENVIRONMENT}."
  terraform "${terraform_args[@]}"
}

warm_container_app() {
  local fqdn
  local ready_url
  local attempts=30

  fqdn="$(
    az containerapp show \
      --resource-group "${RESOURCE_GROUP_NAME}" \
      --name "${CONTAINER_APP_NAME}" \
      --query "properties.configuration.ingress.fqdn" \
      -o tsv 2>/dev/null || true
  )"

  if [[ -z "${fqdn}" || "${fqdn}" == "null" ]]; then
    fail "Could not resolve ingress FQDN for Container App '${CONTAINER_APP_NAME}'."
  fi

  ready_url="https://${fqdn}/ready"
  log "Warming '${ready_url}'."

  for _ in $(seq 1 "${attempts}"); do
    if curl -fsS --max-time 10 "${ready_url}" >/dev/null; then
      log "Container App '${CONTAINER_APP_NAME}' is ready."
      return 0
    fi

    sleep 10
  done

  fail "Timed out waiting for '${ready_url}' to become ready."
}

sleep_postgres() {
  local server_name="$1"
  local current_state="$2"

  case "${current_state}" in
    Stopped)
      log "PostgreSQL server '${server_name}' is already stopped."
      return 0
      ;;
    Stopping)
      log "PostgreSQL server '${server_name}' is already stopping."
      wait_for_postgres_state "${server_name}" "Stopped"
      return 0
      ;;
    Ready)
      log "Stopping PostgreSQL server '${server_name}'."
      az postgres flexible-server stop --resource-group "${RESOURCE_GROUP_NAME}" --name "${server_name}" >/dev/null
      wait_for_postgres_state "${server_name}" "Stopped"
      return 0
      ;;
    *)
      fail "PostgreSQL server '${server_name}' is in state '${current_state}', which is not supported for sleep right now."
      ;;
  esac
}

wake_postgres() {
  local server_name="$1"
  local current_state="$2"

  case "${current_state}" in
    Ready)
      log "PostgreSQL server '${server_name}' is already ready."
      ;;
    Starting)
      log "PostgreSQL server '${server_name}' is already starting."
      wait_for_postgres_state "${server_name}" "Ready"
      ;;
    Stopped)
      log "Starting PostgreSQL server '${server_name}'."
      az postgres flexible-server start --resource-group "${RESOURCE_GROUP_NAME}" --name "${server_name}" >/dev/null
      wait_for_postgres_state "${server_name}" "Ready"
      ;;
    *)
      fail "PostgreSQL server '${server_name}' is in state '${current_state}', which is not supported for wake right now."
      ;;
  esac
}

ENVIRONMENT=""
OPERATION=""
WARM_APP="true"
CONFIRM_RESET=""
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/terraform"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment)
      ENVIRONMENT="${2:-}"
      shift 2
      ;;
    --operation)
      OPERATION="${2:-}"
      shift 2
      ;;
    --warm-app)
      WARM_APP="${2:-}"
      shift 2
      ;;
    --confirm-reset)
      CONFIRM_RESET="${2:-}"
      shift 2
      ;;
    --terraform-dir)
      TERRAFORM_DIR="${2:-}"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

case "${ENVIRONMENT}" in
  dev|prod) ;;
  *)
    usage
    fail "--environment must be 'dev' or 'prod'."
    ;;
esac

case "${OPERATION}" in
  wake|sleep|reset) ;;
  *)
    usage
    fail "--operation must be 'wake', 'sleep', or 'reset'."
    ;;
esac

case "${WARM_APP}" in
  true|false) ;;
  *)
    fail "--warm-app must be 'true' or 'false'."
    ;;
esac

if [[ "${OPERATION}" == "reset" && "${CONFIRM_RESET}" != "RESET" ]]; then
  fail "Reset is destructive. Re-run with --confirm-reset RESET."
fi

ensure_command az
ensure_command curl

TERRAFORM_INITIALIZED="false"
BREAK_GLASS_ALLOWLIST_ADDED="false"
RUNNER_PUBLIC_IP=""
TERRAFORM_DB_TARGETS=()

TFVARS_FILE="${TERRAFORM_DIR}/vars/${ENVIRONMENT}.tfvars"
BACKEND_FILE="${TERRAFORM_DIR}/backend/${ENVIRONMENT}.hcl"
VARIABLES_FILE="${TERRAFORM_DIR}/variables.tf"

[[ -f "${TFVARS_FILE}" ]] || fail "Terraform variables file '${TFVARS_FILE}' was not found."
[[ -f "${BACKEND_FILE}" ]] || fail "Terraform backend file '${BACKEND_FILE}' was not found."
[[ -f "${VARIABLES_FILE}" ]] || fail "Terraform variables file '${VARIABLES_FILE}' was not found."

PROJECT_NAME="$(coalesce "$(extract_var_default_string "${VARIABLES_FILE}" "project")" "taskapi")"
ENV_NAME="$(coalesce "$(extract_tfvar_string "${TFVARS_FILE}" "env")" "${ENVIRONMENT}")"
RESOURCE_GROUP_NAME="${PROJECT_NAME}-${ENV_NAME}-rg-uks"
CONTAINER_APP_NAME="${PROJECT_NAME}-${ENV_NAME}-app"
POSTGRES_SERVER_NAME_PREFIX="${PROJECT_NAME}-${ENV_NAME}-psql-"
POSTGRES_DATABASE_NAME="$(coalesce "$(extract_tfvar_string "${TFVARS_FILE}" "postgres_database_name")" "$(extract_var_default_string "${VARIABLES_FILE}" "postgres_database_name")" "taskdb")"
POSTGRES_FIREWALL_RULE_NAME="allow-azure-services"
USE_SHARED_KEY_VAULT="$(coalesce "$(extract_tfvar_bool "${TFVARS_FILE}" "use_shared_key_vault")" "$(extract_var_default_bool "${VARIABLES_FILE}" "use_shared_key_vault")" "false")"
POSTGRES_PUBLIC_NETWORK_ACCESS_ENABLED="$(coalesce "$(extract_tfvar_bool "${TFVARS_FILE}" "postgres_public_network_access_enabled")" "$(extract_var_default_bool "${VARIABLES_FILE}" "postgres_public_network_access_enabled")" "true")"

if [[ "${USE_SHARED_KEY_VAULT}" == "true" ]]; then
  BREAK_GLASS_KEY_VAULT_NAME="$(extract_tfvar_string "${TFVARS_FILE}" "shared_key_vault_name")"
  BREAK_GLASS_KEY_VAULT_RG="$(extract_tfvar_string "${TFVARS_FILE}" "shared_key_vault_resource_group_name")"
else
  BREAK_GLASS_KEY_VAULT_NAME="$(coalesce "$(extract_tfvar_string "${TFVARS_FILE}" "key_vault_name")" "${PROJECT_NAME}-${ENV_NAME}-kv-uks")"
  BREAK_GLASS_KEY_VAULT_RG="${RESOURCE_GROUP_NAME}"
fi

trap 'cleanup_break_glass_allowlist "$?"' EXIT

log "Study switch starting: env=${ENVIRONMENT}, operation=${OPERATION}, warm_app=${WARM_APP}"

ensure_expected_subscription_context
ensure_resource_group_exists

POSTGRES_SERVER_NAME="$(resolve_postgres_server_name)"

case "${OPERATION}" in
  sleep)
    if [[ -z "${POSTGRES_SERVER_NAME}" ]]; then
      warn "No PostgreSQL server is present for '${ENVIRONMENT}'. Treating sleep as a no-op."
      exit 0
    fi

    CURRENT_STATE="$(resolve_postgres_server_state "${POSTGRES_SERVER_NAME}")"
    sleep_postgres "${POSTGRES_SERVER_NAME}" "${CURRENT_STATE}"
    ;;
  wake)
    if [[ -z "${POSTGRES_SERVER_NAME}" ]]; then
      log "No PostgreSQL server exists for '${ENVIRONMENT}'. Recreating only the DB slice."
      ensure_command terraform
      run_targeted_terraform_apply
      POSTGRES_SERVER_NAME="$(resolve_postgres_server_name)"
      [[ -n "${POSTGRES_SERVER_NAME}" ]] || fail "PostgreSQL server creation completed, but no server matching '${POSTGRES_SERVER_NAME_PREFIX}*' was found."
    fi

    CURRENT_STATE="$(resolve_postgres_server_state "${POSTGRES_SERVER_NAME}")"
    wake_postgres "${POSTGRES_SERVER_NAME}" "${CURRENT_STATE}"

    if database_slice_needs_reconcile "${POSTGRES_SERVER_NAME}"; then
      ensure_command terraform
      run_targeted_terraform_apply
      CURRENT_STATE="$(resolve_postgres_server_state "${POSTGRES_SERVER_NAME}")"
      wake_postgres "${POSTGRES_SERVER_NAME}" "${CURRENT_STATE}"
    fi

    if [[ "${WARM_APP}" == "true" ]]; then
      warm_container_app
    fi
    ;;
  reset)
    if [[ -z "${POSTGRES_SERVER_NAME}" ]]; then
      warn "No PostgreSQL server is present for '${ENVIRONMENT}'. Treating reset as a no-op."
      exit 0
    fi

    ensure_command terraform
    run_targeted_terraform_destroy
    log "Reset completed for '${ENVIRONMENT}'. The PostgreSQL slice was removed, but the rest of the platform remains intact."
    ;;
esac

log "Study switch completed successfully for '${ENVIRONMENT}'."
