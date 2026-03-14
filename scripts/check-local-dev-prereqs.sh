#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
NVMRC_FILE="${REPO_ROOT}/.nvmrc"

FAILURES=0
WARNINGS=0

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

check_command() {
  local name="$1"
  local version_cmd="$2"
  local importance="${3:-required}"

  if command -v "${name}" >/dev/null 2>&1; then
    local version
    version="$(eval "${version_cmd}" 2>/dev/null | head -n 1 || true)"
    if [[ -n "${version}" ]]; then
      pass "${name} is available (${version})"
    else
      pass "${name} is available"
    fi
  else
    if [[ "${importance}" == "required" ]]; then
      fail "${name} is not available in PATH"
    else
      warn "${name} is not available in PATH"
    fi
  fi
}

if [[ -f "${NVMRC_FILE}" ]]; then
  pass ".nvmrc found ($(tr -d '\n' < "${NVMRC_FILE}"))"
else
  fail ".nvmrc is missing"
fi

check_command node "node -v"
check_command npm "npm -v"
check_command docker "docker --version"
check_command gh "gh --version" recommended
check_command az "az version --query '\"azure-cli\"' -o tsv" recommended
check_command terraform "terraform version" recommended

if command -v node >/dev/null 2>&1; then
  node_major="$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || true)"
  if [[ "${node_major}" == "20" ]]; then
    pass "Node major version matches repo expectation (20.x)"
  else
    fail "Node major version must be 20.x for this repo"
  fi
fi

if command -v npm >/dev/null 2>&1; then
  npm_major="$(npm -v 2>/dev/null | cut -d. -f1 || true)"
  if [[ -n "${npm_major}" && "${npm_major}" -ge 10 ]]; then
    pass "npm major version matches repo expectation (>=10)"
  else
    fail "npm major version must be >=10 for this repo"
  fi
fi

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    pass "Docker daemon is running"
  else
    fail "Docker daemon is not running"
  fi

  if docker compose version >/dev/null 2>&1; then
    pass "docker compose plugin is available"
  else
    fail "docker compose plugin is not available"
  fi
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    pass "GitHub CLI authentication looks ready"
  else
    warn "GitHub CLI is installed but not authenticated"
  fi
fi

if command -v az >/dev/null 2>&1; then
  if az account show >/dev/null 2>&1; then
    pass "Azure CLI authentication looks ready"
  else
    warn "Azure CLI is installed but no active login/subscription was found"
  fi
fi

if [[ -f "${ENV_FILE}" ]]; then
  pass ".env file exists"

  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a

  for key in DB_HOST DB_PORT DB_USER DB_PASSWORD DB_NAME; do
    if [[ -n "${!key:-}" ]]; then
      pass ".env contains ${key}"
    else
      fail ".env is missing a value for ${key}"
    fi
  done

  if [[ "${DB_HOST:-}" == "127.0.0.1" || "${DB_HOST:-}" == "localhost" ]]; then
    if [[ -n "${LOCAL_DB_PORT:-}" && "${DB_PORT:-}" != "${LOCAL_DB_PORT:-}" ]]; then
      warn "DB_PORT (${DB_PORT:-}) and LOCAL_DB_PORT (${LOCAL_DB_PORT:-}) differ; keep them aligned for host-run mode"
    fi
  fi

  if command -v nc >/dev/null 2>&1 && [[ -n "${DB_HOST:-}" && -n "${DB_PORT:-}" ]]; then
    if nc -z "${DB_HOST}" "${DB_PORT}" >/dev/null 2>&1; then
      pass "PostgreSQL appears reachable at ${DB_HOST}:${DB_PORT}"
    else
      warn "PostgreSQL is not reachable at ${DB_HOST}:${DB_PORT}"
    fi
  fi
else
  fail ".env file is missing (copy from .env.example first)"
fi

autocrlf="$(git -C "${REPO_ROOT}" config --get core.autocrlf || true)"
filemode="$(git -C "${REPO_ROOT}" config --get core.filemode || true)"

if [[ -z "${autocrlf}" || "${autocrlf}" == "input" || "${autocrlf}" == "false" ]]; then
  pass "git core.autocrlf is compatible with LF-first repo settings"
else
  warn "git core.autocrlf=${autocrlf}; this can create CRLF/LF churn when switching between Windows and macOS"
fi

if [[ -z "${filemode}" || "${filemode}" == "false" ]]; then
  pass "git core.filemode will not create chmod-only diff noise"
else
  warn "git core.filemode=${filemode}; chmod-only diffs may appear across workstations"
fi

printf '\nSummary: %s failure(s), %s warning(s)\n' "${FAILURES}" "${WARNINGS}"

if [[ "${FAILURES}" -gt 0 ]]; then
  exit 1
fi
