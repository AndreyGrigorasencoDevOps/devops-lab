#!/usr/bin/env bash
set -euo pipefail

require_command() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "::error::Required command '${name}' is not available."
    exit 1
  fi
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "::error::Required environment variable '${name}' is not set."
    exit 1
  fi
}

print_list() {
  local label="$1"
  shift

  if [[ "$#" -eq 0 ]]; then
    echo "${label}: none"
    return
  fi

  printf '%s: %s\n' "${label}" "$*"
}

array_contains() {
  local needle="$1"
  shift

  local item
  for item in "$@"; do
    if [[ "${item}" == "${needle}" ]]; then
      return 0
    fi
  done

  return 1
}

append_summary_list() {
  local label="$1"
  shift

  if [[ -z "${GITHUB_STEP_SUMMARY:-}" ]]; then
    return
  fi

  if [[ "$#" -eq 0 ]]; then
    printf -- "- %s: none\n" "${label}" >> "${GITHUB_STEP_SUMMARY}"
    return
  fi

  printf -- "- %s: \`%s\`\n" "${label}" "$(printf '%s, ' "$@" | sed 's/, $//')" >> "${GITHUB_STEP_SUMMARY}"
}

require_command az
require_command jq
require_command python3

require_env CLEANUP_ENV_LABEL
require_env ACR_NAME
require_env RESOURCE_GROUP
require_env CONTAINER_APP_NAME
require_env IMAGE_REPOSITORY
require_env KEEP_LATEST
require_env MIN_AGE_DAYS

DRY_RUN="${DRY_RUN:-true}"

if [[ "${DRY_RUN}" != "true" && "${DRY_RUN}" != "false" ]]; then
  echo "::error::DRY_RUN must be 'true' or 'false'."
  exit 1
fi

ACTIVE_IMAGE="$(
  az containerapp show \
    --name "${CONTAINER_APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query 'properties.template.containers[0].image' \
    -o tsv
)"

if [[ -z "${ACTIVE_IMAGE}" ]]; then
  echo "::error::Unable to resolve the active image for ${CONTAINER_APP_NAME}."
  exit 1
fi

if [[ "${ACTIVE_IMAGE}" != *:* ]]; then
  echo "::error::Active image '${ACTIVE_IMAGE}' does not contain a tag reference."
  exit 1
fi

ACTIVE_TAG="${ACTIVE_IMAGE##*:}"
TAG_DETAILS_JSON="$(
  az acr repository show-tags \
    --name "${ACR_NAME}" \
    --repository "${IMAGE_REPOSITORY}" \
    --detail \
    --orderby time_desc \
    -o json
)"

if ! jq -e --arg active_tag "${ACTIVE_TAG}" '.[] | select(.name == $active_tag)' >/dev/null <<<"${TAG_DETAILS_JSON}"; then
  echo "::error::Active tag '${ACTIVE_TAG}' is not present in ${ACR_NAME}/${IMAGE_REPOSITORY}. Aborting cleanup."
  exit 1
fi

SHA_TAGS=()
while IFS= read -r tag; do
  SHA_TAGS+=("${tag}")
done < <(
  jq -r '
    sort_by(.lastUpdateTime) | reverse |
    .[] |
    select(.name | test("^sha-")) |
    .name
  ' <<<"${TAG_DETAILS_JSON}"
)

KEEP_LATEST_INT="${KEEP_LATEST}"
MIN_AGE_DAYS_INT="${MIN_AGE_DAYS}"
CUTOFF_EPOCH="$(
  MIN_AGE_DAYS="${MIN_AGE_DAYS_INT}" python3 - <<'PY'
from datetime import datetime, timedelta, timezone
import os

cutoff = datetime.now(timezone.utc) - timedelta(days=int(os.environ["MIN_AGE_DAYS"]))
print(int(cutoff.timestamp()))
PY
)"

KEEP_TAGS=("${ACTIVE_TAG}")

KEPT_RECENT_COUNT=0
for tag in "${SHA_TAGS[@]}"; do
  if [[ "${tag}" == "${ACTIVE_TAG}" ]]; then
    continue
  fi

  if (( KEPT_RECENT_COUNT < KEEP_LATEST_INT )); then
    KEEP_TAGS+=("${tag}")
    KEPT_RECENT_COUNT=$((KEPT_RECENT_COUNT + 1))
  fi
done

OLD_SHA_TAGS=()
while IFS= read -r tag; do
  OLD_SHA_TAGS+=("${tag}")
done < <(
  jq -r --argjson cutoff "${CUTOFF_EPOCH}" '
    sort_by(.lastUpdateTime) | reverse |
    .[] |
    select(.name | test("^sha-")) |
    select((.lastUpdateTime | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) < $cutoff) |
    .name
  ' <<<"${TAG_DETAILS_JSON}"
)

DELETE_TAGS=()
for tag in "${OLD_SHA_TAGS[@]-}"; do
  if [[ -z "${tag}" ]]; then
    continue
  fi

  if ! array_contains "${tag}" "${KEEP_TAGS[@]}"; then
    DELETE_TAGS+=("${tag}")
  fi
done

DELETED_TAGS=()
if [[ "${DRY_RUN}" == "false" ]]; then
  for tag in "${DELETE_TAGS[@]-}"; do
    if [[ -z "${tag}" ]]; then
      continue
    fi

    az acr repository delete \
      --name "${ACR_NAME}" \
      --image "${IMAGE_REPOSITORY}:${tag}" \
      --yes
    DELETED_TAGS+=("${tag}")
  done
fi

echo "Environment: ${CLEANUP_ENV_LABEL}"
echo "ACR: ${ACR_NAME}"
echo "Container App: ${CONTAINER_APP_NAME}"
echo "Mode: $( [[ "${DRY_RUN}" == "true" ]] && echo "dry-run" || echo "live" )"
echo "Active image: ${ACTIVE_IMAGE}"
echo "Active tag: ${ACTIVE_TAG}"
print_list "Protected tags" "${KEEP_TAGS[@]-}"
print_list "Delete candidates" "${DELETE_TAGS[@]-}"
if [[ "${DRY_RUN}" == "true" ]]; then
  print_list "Deleted tags" "dry-run only"
else
  print_list "Deleted tags" "${DELETED_TAGS[@]-}"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### ${CLEANUP_ENV_LABEL} ACR Cleanup"
    echo
    echo "| Item | Value |"
    echo "| --- | --- |"
    echo "| Mode | \`$( [[ "${DRY_RUN}" == "true" ]] && echo "dry-run" || echo "live" )\` |"
    echo "| Registry | \`${ACR_NAME}\` |"
    echo "| Repository | \`${IMAGE_REPOSITORY}\` |"
    echo "| Container App | \`${CONTAINER_APP_NAME}\` |"
    echo "| Active image | \`${ACTIVE_IMAGE}\` |"
    echo "| Active tag | \`${ACTIVE_TAG}\` |"
    echo "| Retained recent SHA tags | \`${KEEP_LATEST_INT}\` |"
    echo "| Minimum age for deletion | \`${MIN_AGE_DAYS_INT}d\` |"
    echo
  } >> "${GITHUB_STEP_SUMMARY}"

  append_summary_list "Protected tags" "${KEEP_TAGS[@]-}"
  append_summary_list "Delete candidates" "${DELETE_TAGS[@]-}"
  if [[ "${DRY_RUN}" == "true" ]]; then
    append_summary_list "Deleted tags" "dry-run only"
  else
    append_summary_list "Deleted tags" "${DELETED_TAGS[@]-}"
  fi
fi
