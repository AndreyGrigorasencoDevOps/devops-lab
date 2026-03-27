#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/resolve-workflow-vars.sh --context-label <label> [options]

Options:
  --context-label <label>             Human-readable label for error messages.
  --require-acr-name                  Fail when ACR_NAME is missing.
  --require-acr-login-server          Fail when ACR_LOGIN_SERVER is missing.
  --export-arm-env                    Export ARM_* variables for later steps.
  --export-tf-env                     Export TF_VAR_* variables for later steps.
  --rbac-propagation-wait-seconds <n> Optional TF_VAR_rbac_propagation_wait_seconds value.
  --container-image-tag <tag>         Optional TF_VAR_container_image_tag value.
  --help                              Show this help text.
EOF
}

fail() {
  printf '::error::%s\n' "$*" >&2
  exit 1
}

require_command() {
  local name="$1"
  command -v "${name}" >/dev/null 2>&1 || fail "Required command '${name}' is not installed."
}

write_file_command() {
  local target_file="$1"
  local key="$2"
  local value="$3"
  local delimiter="EOF_${RANDOM}_${RANDOM}_$$"

  {
    printf '%s<<%s\n' "${key}" "${delimiter}"
    printf '%s\n' "${value}"
    printf '%s\n' "${delimiter}"
  } >> "${target_file}"
}

read_workflow_var() {
  local key="$1"
  printf '%s' "${WORKFLOW_VARS_JSON}" | jq -r --arg key "${key}" '.[$key] // empty'
}

context_label=""
require_acr_name="false"
require_acr_login_server="false"
export_arm_env="false"
export_tf_env="false"
rbac_propagation_wait_seconds=""
container_image_tag=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context-label)
      [[ $# -ge 2 ]] || fail "--context-label requires a value."
      context_label="$2"
      shift 2
      ;;
    --require-acr-name)
      require_acr_name="true"
      shift
      ;;
    --require-acr-login-server)
      require_acr_login_server="true"
      shift
      ;;
    --export-arm-env)
      export_arm_env="true"
      shift
      ;;
    --export-tf-env)
      export_tf_env="true"
      shift
      ;;
    --rbac-propagation-wait-seconds)
      [[ $# -ge 2 ]] || fail "--rbac-propagation-wait-seconds requires a value."
      rbac_propagation_wait_seconds="$2"
      shift 2
      ;;
    --container-image-tag)
      [[ $# -ge 2 ]] || fail "--container-image-tag requires a value."
      container_image_tag="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

[[ -n "${context_label}" ]] || fail "--context-label is required."
[[ -n "${WORKFLOW_VARS_JSON:-}" ]] || fail "WORKFLOW_VARS_JSON is required."
[[ -n "${GITHUB_OUTPUT:-}" ]] || fail "GITHUB_OUTPUT is required."

if [[ "${export_arm_env}" == "true" || "${export_tf_env}" == "true" ]]; then
  [[ -n "${GITHUB_ENV:-}" ]] || fail "GITHUB_ENV is required when exporting environment variables."
fi

require_command jq

azure_client_id="$(read_workflow_var "AZURE_CLIENT_ID")"
azure_tenant_id="$(read_workflow_var "AZURE_TENANT_ID")"
azure_subscription_id="$(read_workflow_var "AZURE_SUBSCRIPTION_ID")"
acr_name="$(read_workflow_var "ACR_NAME")"
acr_login_server="$(read_workflow_var "ACR_LOGIN_SERVER")"
app_env_vars_json="$(read_workflow_var "TF_APP_ENV_VARS_JSON")"
shared_runner_admin_ssh_public_key="$(read_workflow_var "TF_SHARED_RUNNER_ADMIN_SSH_PUBLIC_KEY")"

missing=()

[[ -n "${azure_client_id}" ]] || missing+=("AZURE_CLIENT_ID")
[[ -n "${azure_tenant_id}" ]] || missing+=("AZURE_TENANT_ID")
[[ -n "${azure_subscription_id}" ]] || missing+=("AZURE_SUBSCRIPTION_ID")

if [[ "${require_acr_name}" == "true" && -z "${acr_name}" ]]; then
  missing+=("ACR_NAME")
fi

if [[ "${require_acr_login_server}" == "true" && -z "${acr_login_server}" ]]; then
  missing+=("ACR_LOGIN_SERVER")
fi

if (( ${#missing[@]} > 0 )); then
  fail "Missing required workflow variables for ${context_label}: ${missing[*]}"
fi

write_file_command "${GITHUB_OUTPUT}" "azure_client_id" "${azure_client_id}"
write_file_command "${GITHUB_OUTPUT}" "azure_tenant_id" "${azure_tenant_id}"
write_file_command "${GITHUB_OUTPUT}" "azure_subscription_id" "${azure_subscription_id}"
write_file_command "${GITHUB_OUTPUT}" "acr_name" "${acr_name}"
write_file_command "${GITHUB_OUTPUT}" "acr_login_server" "${acr_login_server}"

if [[ "${export_arm_env}" == "true" ]]; then
  write_file_command "${GITHUB_ENV}" "ARM_USE_OIDC" "true"
  write_file_command "${GITHUB_ENV}" "ARM_CLIENT_ID" "${azure_client_id}"
  write_file_command "${GITHUB_ENV}" "ARM_TENANT_ID" "${azure_tenant_id}"
  write_file_command "${GITHUB_ENV}" "ARM_SUBSCRIPTION_ID" "${azure_subscription_id}"
fi

if [[ "${export_tf_env}" == "true" ]]; then
  if [[ -n "${rbac_propagation_wait_seconds}" ]]; then
    write_file_command "${GITHUB_ENV}" "TF_VAR_rbac_propagation_wait_seconds" "${rbac_propagation_wait_seconds}"
  fi

  if [[ -n "${container_image_tag}" ]]; then
    write_file_command "${GITHUB_ENV}" "TF_VAR_container_image_tag" "${container_image_tag}"
  fi

  if [[ -n "${app_env_vars_json}" ]]; then
    write_file_command "${GITHUB_ENV}" "TF_VAR_app_env_vars" "${app_env_vars_json}"
  fi

  if [[ -n "${shared_runner_admin_ssh_public_key}" ]]; then
    write_file_command "${GITHUB_ENV}" "TF_VAR_shared_runner_admin_ssh_public_key" "${shared_runner_admin_ssh_public_key}"
  fi
fi
