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
DEV_APP_NAME=""
PROD_APP_NAME=""

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
  --dev-app <name>               Dev Container App name (default: <project>-dev-app)
  --prod-app <name>              Prod Container App name (default: <project>-prod-app)
  -h, --help                     Show this help

What it checks (read-only):
  1) GitHub repo Sonar config (SONAR_TOKEN, SONAR_PROJECT, SONAR_ORG)
  2) GitHub environment vars for dev/prod
  3) Azure shared Key Vault existence
  4) Key Vault Secrets User role on Container App managed identities
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
  if [[ -z "${DEV_APP_NAME}" && -n "${PROJECT_NAME}" ]]; then
    DEV_APP_NAME="${PROJECT_NAME}-dev-app"
  fi
  if [[ -z "${PROD_APP_NAME}" && -n "${PROJECT_NAME}" ]]; then
    PROD_APP_NAME="${PROJECT_NAME}-prod-app"
  fi
}

check_gh_secret() {
  local secret_name="$1"
  if gh api "repos/${REPO}/actions/secrets/${secret_name}" >/dev/null 2>&1; then
    pass "GitHub secret '${secret_name}' exists"
  else
    fail "GitHub secret '${secret_name}' is missing in ${REPO}"
  fi
}

check_gh_repo_var() {
  local var_name="$1"
  if gh api "repos/${REPO}/actions/variables/${var_name}" >/dev/null 2>&1; then
    pass "GitHub repo variable '${var_name}' exists"
  else
    fail "GitHub repo variable '${var_name}' is missing in ${REPO}"
  fi
}

check_gh_env_var_required() {
  local env_name="$1"
  local var_name="$2"
  if gh api "repos/${REPO}/environments/${env_name}/variables/${var_name}" >/dev/null 2>&1; then
    pass "GitHub env '${env_name}' variable '${var_name}' exists"
  else
    fail "GitHub env '${env_name}' variable '${var_name}' is missing"
  fi
}

check_gh_env_var_optional() {
  local env_name="$1"
  local var_name="$2"
  if gh api "repos/${REPO}/environments/${env_name}/variables/${var_name}" >/dev/null 2>&1; then
    pass "GitHub env '${env_name}' optional variable '${var_name}' exists"
  else
    warn "GitHub env '${env_name}' optional variable '${var_name}' is not set"
  fi
}

check_key_vault_role_for_app() {
  local app_name="$1"
  local app_rg="$2"
  local kv_id="$3"
  local principal_id
  local assignment_count

  principal_id="$(az containerapp show \
    --name "${app_name}" \
    --resource-group "${app_rg}" \
    --query identity.principalId \
    -o tsv 2>/dev/null || true)"

  if [[ -z "${principal_id}" ]]; then
    warn "Container App '${app_name}' not found in '${app_rg}' (role check skipped)"
    return
  fi

  assignment_count="$(az role assignment list \
    --assignee-object-id "${principal_id}" \
    --scope "${kv_id}" \
    --query "[?roleDefinitionName=='Key Vault Secrets User'] | length(@)" \
    -o tsv 2>/dev/null || echo "0")"

  if [[ "${assignment_count}" =~ ^[0-9]+$ ]] && [[ "${assignment_count}" -ge 1 ]]; then
    pass "Container App '${app_name}' has 'Key Vault Secrets User' on shared Key Vault"
  else
    fail "Container App '${app_name}' is missing 'Key Vault Secrets User' on shared Key Vault"
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
    --dev-app)
      DEV_APP_NAME="${2:-}"
      shift 2
      ;;
    --prod-app)
      PROD_APP_NAME="${2:-}"
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
printf 'Dev app: %s (rg: %s)\n' "${DEV_APP_NAME:-n/a}" "${DEV_RESOURCE_GROUP:-n/a}"
printf 'Prod app: %s (rg: %s)\n' "${PROD_APP_NAME:-n/a}" "${PROD_RESOURCE_GROUP:-n/a}"
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
    pass "GitHub CLI auth is active"
    check_gh_secret "SONAR_TOKEN"
    check_gh_repo_var "SONAR_PROJECT"
    check_gh_repo_var "SONAR_ORG"

    for env_name in dev prod; do
      check_gh_env_var_required "${env_name}" "AZURE_CLIENT_ID"
      check_gh_env_var_required "${env_name}" "AZURE_TENANT_ID"
      check_gh_env_var_required "${env_name}" "AZURE_SUBSCRIPTION_ID"
      check_gh_env_var_required "${env_name}" "ACR_NAME"
      check_gh_env_var_required "${env_name}" "ACR_LOGIN_SERVER"
      check_gh_env_var_optional "${env_name}" "TF_APP_ENV_VARS_JSON"
    done
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

        if [[ -n "${DEV_APP_NAME}" && -n "${DEV_RESOURCE_GROUP}" ]]; then
          check_key_vault_role_for_app "${DEV_APP_NAME}" "${DEV_RESOURCE_GROUP}" "${KV_ID}"
        else
          warn "Dev Container App coordinates are unresolved (role check skipped)"
        fi

        if [[ -n "${PROD_APP_NAME}" && -n "${PROD_RESOURCE_GROUP}" ]]; then
          check_key_vault_role_for_app "${PROD_APP_NAME}" "${PROD_RESOURCE_GROUP}" "${KV_ID}"
        else
          warn "Prod Container App coordinates are unresolved (role check skipped)"
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
