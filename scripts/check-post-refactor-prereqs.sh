#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

REPO="${GITHUB_REPOSITORY:-}"
PROJECT_NAME=""
SHARED_KV_NAME=""
SHARED_KV_RG=""
DEV_RESOURCE_GROUP=""
PROD_RESOURCE_GROUP=""
DEV_IDENTITY_NAME=""
PROD_IDENTITY_NAME=""

FAILURES=0
WARNINGS=0

usage() {
  cat <<'EOF'
Usage:
  scripts/check-post-refactor-prereqs.sh [options]

Options:
  --repo <owner/repo>            GitHub repository (default: infer from env/git remote)
  --project <name>               Terraform project name (default: inferred from terraform/variables.tf)
  --kv-name <name>               Shared Key Vault name (default: inferred from terraform/vars/prod.tfvars)
  --kv-rg <name>                 Shared Key Vault resource group (default: inferred from terraform/vars/prod.tfvars)
  --dev-rg <name>                Dev resource group (default: <project>-dev-rg-uks)
  --prod-rg <name>               Prod resource group (default: <project>-prod-rg-uks)
  --dev-identity <name>          Dev User Assigned Identity name (default: <project>-dev-ca-identity)
  --prod-identity <name>         Prod User Assigned Identity name (default: <project>-prod-ca-identity)
  -h, --help                     Show this help

What it checks (read-only):
  1) GitHub repo Sonar config (SONAR_TOKEN, SONAR_PROJECT, SONAR_ORG)
  2) GitHub environment vars for dev/prod
  3) Azure shared Key Vault existence
  4) Required DB secrets in shared Key Vault (<env>-db-password)
  5) Optional DB runtime secrets in shared Key Vault (<env>-db-host/port/user/name)
  6) Key Vault Secrets User role on User Assigned identities used by Container App
EOF
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

extract_default_project() {
  sed -n '/variable "project"/,/}/s/.*default[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
    "${REPO_ROOT}/terraform/variables.tf" | head -n 1
}

extract_tfvar_string() {
  local file="$1"
  local key="$2"
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "${file}" | head -n 1
}

infer_terraform_defaults() {
  local prod_tfvars="${REPO_ROOT}/terraform/vars/prod.tfvars"

  if [[ -z "${PROJECT_NAME}" ]]; then
    PROJECT_NAME="$(extract_default_project)"
  fi
  if [[ -z "${SHARED_KV_NAME}" ]]; then
    SHARED_KV_NAME="$(extract_tfvar_string "${prod_tfvars}" "shared_key_vault_name")"
  fi
  if [[ -z "${SHARED_KV_RG}" ]]; then
    SHARED_KV_RG="$(extract_tfvar_string "${prod_tfvars}" "shared_key_vault_resource_group_name")"
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
}

first_line() {
  printf '%s\n' "$1" | head -n 1
}

is_gh_forbidden_error() {
  local msg="$1"
  printf '%s' "${msg}" | grep -qiE "HTTP 403|forbidden|Resource not accessible by personal access token|insufficient"
}

list_contains_name() {
  local list_value="$1"
  local expected_name="$2"
  printf '%s\n' "${list_value}" | grep -Fxq "${expected_name}"
}

check_name_in_list_required() {
  local list_value="$1"
  local expected_name="$2"
  local pass_msg="$3"
  local fail_msg="$4"
  if list_contains_name "${list_value}" "${expected_name}"; then
    pass "${pass_msg}"
  else
    fail "${fail_msg}"
  fi
}

check_name_in_list_optional() {
  local list_value="$1"
  local expected_name="$2"
  local pass_msg="$3"
  local warn_msg="$4"
  if list_contains_name "${list_value}" "${expected_name}"; then
    pass "${pass_msg}"
  else
    warn "${warn_msg}"
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
    warn "Key Vault optional secret '${secret_name}' is missing in '${kv_name}' (Terraform can create/update it on apply)"
  fi
}

kv_db_secret_name() {
  local env_name="$1"
  local key_name="$2"
  printf "%s-db-%s" "${env_name}" "${key_name}"
}

check_key_vault_role_for_identity() {
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
    warn "User Assigned Identity '${identity_name}' not found in '${identity_rg}' (role check skipped)"
    return
  fi

  assignment_count="$(az role assignment list \
    --assignee-object-id "${principal_id}" \
    --scope "${kv_id}" \
    --query "[?roleDefinitionName=='Key Vault Secrets User'] | length(@)" \
    -o tsv 2>/dev/null || echo "0")"

  if [[ "${assignment_count}" =~ ^[0-9]+$ ]] && [[ "${assignment_count}" -ge 1 ]]; then
    pass "Identity '${identity_name}' has 'Key Vault Secrets User' on shared Key Vault"
  else
    fail "Identity '${identity_name}' is missing 'Key Vault Secrets User' on shared Key Vault"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --project)
      PROJECT_NAME="${2:-}"
      shift 2
      ;;
    --kv-name)
      SHARED_KV_NAME="${2:-}"
      shift 2
      ;;
    --kv-rg)
      SHARED_KV_RG="${2:-}"
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

infer_repo
infer_terraform_defaults

printf '\n== Context ==\n'
printf 'Repo: %s\n' "${REPO:-n/a}"
printf 'Project: %s\n' "${PROJECT_NAME:-n/a}"
printf 'Shared KV: %s (rg: %s)\n' "${SHARED_KV_NAME:-n/a}" "${SHARED_KV_RG:-n/a}"
printf 'Dev identity: %s (rg: %s)\n' "${DEV_IDENTITY_NAME:-n/a}" "${DEV_RESOURCE_GROUP:-n/a}"
printf 'Prod identity: %s (rg: %s)\n' "${PROD_IDENTITY_NAME:-n/a}" "${PROD_RESOURCE_GROUP:-n/a}"
printf '\n'

GH_AVAILABLE=true
AZ_AVAILABLE=true

if ! command -v gh >/dev/null 2>&1; then
  GH_AVAILABLE=false
  fail "GitHub CLI ('gh') is not installed"
fi

if ! command -v az >/dev/null 2>&1; then
  AZ_AVAILABLE=false
  fail "Azure CLI ('az') is not installed"
fi

if [[ "${GH_AVAILABLE}" == "true" ]]; then
  printf '== GitHub checks ==\n'
  if [[ -z "${REPO}" ]]; then
    fail "GitHub repo is unresolved. Pass --repo owner/repo."
  elif gh auth status >/dev/null 2>&1; then
    GH_CHECKS_READABLE=true
    pass "GitHub CLI auth is active"

    if ! REPO_SECRET_NAMES="$(gh secret list -R "${REPO}" --json name --jq '.[].name' 2>&1)"; then
      GH_CHECKS_READABLE=false
      if is_gh_forbidden_error "${REPO_SECRET_NAMES}"; then
        fail "GitHub token cannot read repository secrets in ${REPO} (HTTP 403)."
      else
        fail "Unable to list repository secrets in ${REPO}: $(first_line "${REPO_SECRET_NAMES}")"
      fi
    fi

    if ! REPO_VARIABLE_NAMES="$(gh variable list -R "${REPO}" --json name --jq '.[].name' 2>&1)"; then
      GH_CHECKS_READABLE=false
      if is_gh_forbidden_error "${REPO_VARIABLE_NAMES}"; then
        fail "GitHub token cannot read repository variables in ${REPO} (HTTP 403)."
      else
        fail "Unable to list repository variables in ${REPO}: $(first_line "${REPO_VARIABLE_NAMES}")"
      fi
    fi

    if ! DEV_ENV_VARIABLE_NAMES="$(gh variable list --env dev -R "${REPO}" --json name --jq '.[].name' 2>&1)"; then
      GH_CHECKS_READABLE=false
      if is_gh_forbidden_error "${DEV_ENV_VARIABLE_NAMES}"; then
        fail "GitHub token cannot read 'dev' environment variables in ${REPO} (HTTP 403)."
      else
        fail "Unable to list 'dev' environment variables in ${REPO}: $(first_line "${DEV_ENV_VARIABLE_NAMES}")"
      fi
    fi

    if ! PROD_ENV_VARIABLE_NAMES="$(gh variable list --env prod -R "${REPO}" --json name --jq '.[].name' 2>&1)"; then
      GH_CHECKS_READABLE=false
      if is_gh_forbidden_error "${PROD_ENV_VARIABLE_NAMES}"; then
        fail "GitHub token cannot read 'prod' environment variables in ${REPO} (HTTP 403)."
      else
        fail "Unable to list 'prod' environment variables in ${REPO}: $(first_line "${PROD_ENV_VARIABLE_NAMES}")"
      fi
    fi

    if [[ "${GH_CHECKS_READABLE}" == "true" ]]; then
      check_name_in_list_required "${REPO_SECRET_NAMES}" "SONAR_TOKEN" \
        "GitHub secret 'SONAR_TOKEN' exists" \
        "GitHub secret 'SONAR_TOKEN' is missing in ${REPO}"

      check_name_in_list_required "${REPO_VARIABLE_NAMES}" "SONAR_PROJECT" \
        "GitHub repo variable 'SONAR_PROJECT' exists" \
        "GitHub repo variable 'SONAR_PROJECT' is missing in ${REPO}"

      check_name_in_list_required "${REPO_VARIABLE_NAMES}" "SONAR_ORG" \
        "GitHub repo variable 'SONAR_ORG' exists" \
        "GitHub repo variable 'SONAR_ORG' is missing in ${REPO}"

      for env_name in dev prod; do
        ENV_VAR_NAMES="${DEV_ENV_VARIABLE_NAMES}"
        if [[ "${env_name}" == "prod" ]]; then
          ENV_VAR_NAMES="${PROD_ENV_VARIABLE_NAMES}"
        fi

        check_name_in_list_required "${ENV_VAR_NAMES}" "AZURE_CLIENT_ID" \
          "GitHub env '${env_name}' variable 'AZURE_CLIENT_ID' exists" \
          "GitHub env '${env_name}' variable 'AZURE_CLIENT_ID' is missing"
        check_name_in_list_required "${ENV_VAR_NAMES}" "AZURE_TENANT_ID" \
          "GitHub env '${env_name}' variable 'AZURE_TENANT_ID' exists" \
          "GitHub env '${env_name}' variable 'AZURE_TENANT_ID' is missing"
        check_name_in_list_required "${ENV_VAR_NAMES}" "AZURE_SUBSCRIPTION_ID" \
          "GitHub env '${env_name}' variable 'AZURE_SUBSCRIPTION_ID' exists" \
          "GitHub env '${env_name}' variable 'AZURE_SUBSCRIPTION_ID' is missing"
        check_name_in_list_required "${ENV_VAR_NAMES}" "ACR_NAME" \
          "GitHub env '${env_name}' variable 'ACR_NAME' exists" \
          "GitHub env '${env_name}' variable 'ACR_NAME' is missing"
        check_name_in_list_required "${ENV_VAR_NAMES}" "ACR_LOGIN_SERVER" \
          "GitHub env '${env_name}' variable 'ACR_LOGIN_SERVER' exists" \
          "GitHub env '${env_name}' variable 'ACR_LOGIN_SERVER' is missing"
        check_name_in_list_optional "${ENV_VAR_NAMES}" "TF_APP_ENV_VARS_JSON" \
          "GitHub env '${env_name}' optional variable 'TF_APP_ENV_VARS_JSON' exists" \
          "GitHub env '${env_name}' optional variable 'TF_APP_ENV_VARS_JSON' is not set"
      done
    else
      warn "Skipping GitHub variable/secret presence checks due GitHub API access errors above."
    fi
  else
    fail "GitHub CLI is not authenticated (run: gh auth login)"
  fi
  printf '\n'
fi

if [[ "${AZ_AVAILABLE}" == "true" ]]; then
  printf '== Azure checks ==\n'
  if az account show >/dev/null 2>&1; then
    pass "Azure CLI auth is active"

    if [[ -z "${SHARED_KV_NAME}" || -z "${SHARED_KV_RG}" ]]; then
      fail "Shared Key Vault name/resource-group is unresolved. Pass --kv-name and --kv-rg."
    else
      KV_ID="$(az keyvault show \
        --name "${SHARED_KV_NAME}" \
        --resource-group "${SHARED_KV_RG}" \
        --query id -o tsv 2>/dev/null || true)"

      if [[ -z "${KV_ID}" ]]; then
        fail "Shared Key Vault '${SHARED_KV_NAME}' in '${SHARED_KV_RG}' was not found"
      else
        pass "Shared Key Vault '${SHARED_KV_NAME}' exists"

        for env_name in dev prod; do
          check_key_vault_secret_exists "${SHARED_KV_NAME}" "$(kv_db_secret_name "${env_name}" "password")"
          for key_name in host port user name; do
            check_key_vault_secret_optional "${SHARED_KV_NAME}" "$(kv_db_secret_name "${env_name}" "${key_name}")"
          done
        done

        if [[ -n "${DEV_IDENTITY_NAME}" && -n "${DEV_RESOURCE_GROUP}" ]]; then
          check_key_vault_role_for_identity "${DEV_IDENTITY_NAME}" "${DEV_RESOURCE_GROUP}" "${KV_ID}"
        else
          warn "Dev identity coordinates are unresolved (role check skipped)"
        fi

        if [[ -n "${PROD_IDENTITY_NAME}" && -n "${PROD_RESOURCE_GROUP}" ]]; then
          check_key_vault_role_for_identity "${PROD_IDENTITY_NAME}" "${PROD_RESOURCE_GROUP}" "${KV_ID}"
        else
          warn "Prod identity coordinates are unresolved (role check skipped)"
        fi
      fi
    fi
  else
    fail "Azure CLI is not authenticated (run: az login)"
  fi
  printf '\n'
fi

printf '== Result ==\n'
printf 'Failures: %s\n' "${FAILURES}"
printf 'Warnings: %s\n' "${WARNINGS}"

if [[ "${FAILURES}" -gt 0 ]]; then
  exit 1
fi
