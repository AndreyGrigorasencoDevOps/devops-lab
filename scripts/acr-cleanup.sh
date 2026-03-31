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

warn() {
  printf '::warning::%s\n' "$*" >&2
}

fail() {
  printf '::error::%s\n' "$*" >&2
  exit 1
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

json_array_from_array() {
  local array_name="$1"
  local restore_nounset="false"

  case "$-" in
    *u*)
      restore_nounset="true"
      set +u
      ;;
  esac

  # shellcheck disable=SC2294
  eval "set -- \"\${${array_name}[@]}\""

  if [[ "${restore_nounset}" == "true" ]]; then
    set -u
  fi

  if [[ "$#" -eq 0 ]]; then
    jq -nc '[]'
    return
  fi

  jq -nc '$ARGS.positional | map(select(length > 0))' --args "$@"
}

print_array_list() {
  local label="$1"
  local array_name="$2"
  local restore_nounset="false"

  case "$-" in
    *u*)
      restore_nounset="true"
      set +u
      ;;
  esac

  # shellcheck disable=SC2294
  eval "set -- \"\${${array_name}[@]}\""

  if [[ "${restore_nounset}" == "true" ]]; then
    set -u
  fi

  print_list "${label}" "$@"
}

append_summary_array_list() {
  local label="$1"
  local array_name="$2"
  local restore_nounset="false"

  case "$-" in
    *u*)
      restore_nounset="true"
      set +u
      ;;
  esac

  # shellcheck disable=SC2294
  eval "set -- \"\${${array_name}[@]}\""

  if [[ "${restore_nounset}" == "true" ]]; then
    set -u
  fi

  append_summary_list "${label}" "$@"
}

normalize_cli_output() {
  local file_path="$1"
  tr '\n' ' ' <"${file_path}" | sed 's/[[:space:]]\+/ /g'
}

is_retryable_azure_error() {
  local error_text="$1"
  printf '%s' "${error_text}" | grep -qiE 'HTTP Error: 5[0-9][0-9]|StatusCode: 5[0-9][0-9]|MsalServiceError|TooManyRequests|HTTP Error: 429|StatusCode: 429|timed out|timeout|temporarily unavailable|Temporary failure|connection reset|connection aborted|EOF|try again'
}

run_with_retry() {
  local description="$1"
  shift

  local max_attempts="${AZURE_CLI_RETRY_ATTEMPTS:-4}"
  local delay_seconds="${AZURE_CLI_RETRY_INITIAL_DELAY_SECONDS:-5}"
  local attempt
  local status
  local stdout_file
  local stderr_file
  local stdout_text
  local stderr_text
  local combined_text
  local attempt_context

  for attempt in $(seq 1 "${max_attempts}"); do
    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"

    if "$@" >"${stdout_file}" 2>"${stderr_file}"; then
      cat "${stdout_file}"
      if [[ -s "${stderr_file}" ]]; then
        cat "${stderr_file}" >&2
      fi
      rm -f "${stdout_file}" "${stderr_file}"
      return 0
    else
      status=$?
    fi

    stdout_text="$(normalize_cli_output "${stdout_file}")"
    stderr_text="$(normalize_cli_output "${stderr_file}")"
    combined_text="$(printf '%s %s' "${stderr_text}" "${stdout_text}" | sed 's/[[:space:]]\+/ /g' | sed 's/^ //; s/ $//')"
    rm -f "${stdout_file}" "${stderr_file}"

    if (( attempt > 1 )); then
      attempt_context=" after ${attempt} attempts"
    else
      attempt_context=""
    fi

    if (( attempt == max_attempts )) || ! is_retryable_azure_error "${combined_text}"; then
      fail "${description} failed${attempt_context} (exit ${status}): ${combined_text:-no diagnostic output}"
    fi

    warn "${description} failed on attempt ${attempt}/${max_attempts} (exit ${status}): ${combined_text:-no diagnostic output}. Retrying in ${delay_seconds}s."
    sleep "${delay_seconds}"
    delay_seconds=$(( delay_seconds * 2 ))
  done
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
  fail "DRY_RUN must be 'true' or 'false'."
fi

ACTIVE_IMAGE="$(
  az containerapp show \
    --name "${CONTAINER_APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query 'properties.template.containers[0].image' \
    -o tsv
)"

if [[ -z "${ACTIVE_IMAGE}" ]]; then
  fail "Unable to resolve the active image for ${CONTAINER_APP_NAME}."
fi

if [[ "${ACTIVE_IMAGE}" != *:* ]]; then
  fail "Active image '${ACTIVE_IMAGE}' does not contain a tag reference."
fi

ACTIVE_TAG="${ACTIVE_IMAGE##*:}"
MANIFEST_METADATA_JSON="$(
  run_with_retry \
    "Listing ACR manifest metadata for ${ACR_NAME}/${IMAGE_REPOSITORY}" \
    az acr manifest list-metadata \
      --registry "${ACR_NAME}" \
      --name "${IMAGE_REPOSITORY}" \
      --orderby time_desc \
      -o json
)"

TAG_DETAILS_JSON="$(
  jq -c '
    [
      .[] |
      select(.digest != null) |
      . as $manifest |
      ($manifest.tags // [])[] |
      {
        name: .,
        digest: $manifest.digest,
        lastUpdateTime: $manifest.lastUpdateTime
      }
    ]
  ' <<<"${MANIFEST_METADATA_JSON}"
)"

if ! jq -e --arg active_tag "${ACTIVE_TAG}" '.[] | select(.name == $active_tag)' >/dev/null <<<"${TAG_DETAILS_JSON}"; then
  fail "Active tag '${ACTIVE_TAG}' is not present in ${ACR_NAME}/${IMAGE_REPOSITORY}. Aborting cleanup."
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
if (( ${#SHA_TAGS[@]} > 0 )); then
  for tag in "${SHA_TAGS[@]}"; do
    if [[ "${tag}" == "${ACTIVE_TAG}" ]]; then
      continue
    fi

    if (( KEPT_RECENT_COUNT < KEEP_LATEST_INT )); then
      KEEP_TAGS+=("${tag}")
      KEPT_RECENT_COUNT=$(( KEPT_RECENT_COUNT + 1 ))
    fi
  done
fi

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
if (( ${#OLD_SHA_TAGS[@]} > 0 )); then
  for tag in "${OLD_SHA_TAGS[@]}"; do
    if [[ -z "${tag}" ]]; then
      continue
    fi

    if ! array_contains "${tag}" "${KEEP_TAGS[@]}"; then
      DELETE_TAGS+=("${tag}")
    fi
  done
fi

PROTECTED_TAGS_JSON="$(json_array_from_array KEEP_TAGS)"
DELETE_TAGS_JSON="$(json_array_from_array DELETE_TAGS)"

PROTECTED_DIGESTS=()
PROTECTED_DIGESTS_RAW="$(
  jq -r --argjson protected_tags "${PROTECTED_TAGS_JSON}" '
    .[] |
    select(.digest != null) |
    select((.tags // []) | any(. as $tag | ($protected_tags | index($tag)) != null)) |
    .digest
  ' <<<"${MANIFEST_METADATA_JSON}"
)"
while IFS= read -r digest; do
  if [[ -z "${digest}" ]]; then
    continue
  fi
  PROTECTED_DIGESTS+=("${digest}")
done <<<"${PROTECTED_DIGESTS_RAW}"

PROTECTED_DIGESTS_JSON="$(json_array_from_array PROTECTED_DIGESTS)"

DELETE_DIGESTS=()
DELETE_DIGESTS_RAW="$(
  jq -r \
    --argjson delete_tags "${DELETE_TAGS_JSON}" \
    --argjson protected_digests "${PROTECTED_DIGESTS_JSON}" '
      .[] as $manifest |
      select($manifest.digest != null) |
      select(($manifest.tags // []) | length > 0) |
      select(($protected_digests | index($manifest.digest)) == null) |
      select(($manifest.tags // []) | map(test("^sha-")) | all) |
      select((((($manifest.tags // []) - $delete_tags) | length) == 0)) |
      $manifest.digest
    ' <<<"${MANIFEST_METADATA_JSON}"
)"
while IFS= read -r digest; do
  if [[ -z "${digest}" ]]; then
    continue
  fi
  DELETE_DIGESTS+=("${digest}")
done <<<"${DELETE_DIGESTS_RAW}"

DELETED_TAGS=()
DELETED_TAGS_RAW="$(
  jq -r \
    --argjson delete_digests "$(json_array_from_array DELETE_DIGESTS)" '
      .[] as $manifest |
      select($manifest.digest != null) |
      select(($delete_digests | index($manifest.digest)) != null) |
      ($manifest.tags // [])[]
    ' <<<"${MANIFEST_METADATA_JSON}" | sort -u
)"
while IFS= read -r tag; do
  if [[ -z "${tag}" ]]; then
    continue
  fi
  DELETED_TAGS+=("${tag}")
done <<<"${DELETED_TAGS_RAW}"

DELETED_DIGESTS=()
if [[ "${DRY_RUN}" == "false" ]]; then
  if (( ${#DELETE_DIGESTS[@]} > 0 )); then
    for digest in "${DELETE_DIGESTS[@]}"; do
      if [[ -z "${digest}" ]]; then
        continue
      fi

      run_with_retry \
        "Deleting ACR manifest ${IMAGE_REPOSITORY}@${digest}" \
        az acr manifest delete \
          --registry "${ACR_NAME}" \
          --name "${IMAGE_REPOSITORY}@${digest}" \
          --yes >/dev/null
      DELETED_DIGESTS+=("${digest}")
    done
  fi
fi

echo "Environment: ${CLEANUP_ENV_LABEL}"
echo "ACR: ${ACR_NAME}"
echo "Container App: ${CONTAINER_APP_NAME}"
echo "Mode: $( [[ "${DRY_RUN}" == "true" ]] && echo "dry-run" || echo "live" )"
echo "Active image: ${ACTIVE_IMAGE}"
echo "Active tag: ${ACTIVE_TAG}"
print_array_list "Protected tags" KEEP_TAGS
print_array_list "Protected digests" PROTECTED_DIGESTS
print_array_list "Delete candidate tags" DELETE_TAGS
print_array_list "Delete candidate digests" DELETE_DIGESTS
if [[ "${DRY_RUN}" == "true" ]]; then
  print_list "Deleted tags" "dry-run only"
  print_list "Deleted digests" "dry-run only"
else
  print_array_list "Deleted tags" DELETED_TAGS
  print_array_list "Deleted digests" DELETED_DIGESTS
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

  append_summary_array_list "Protected tags" KEEP_TAGS
  append_summary_array_list "Protected digests" PROTECTED_DIGESTS
  append_summary_array_list "Delete candidate tags" DELETE_TAGS
  append_summary_array_list "Delete candidate digests" DELETE_DIGESTS
  if [[ "${DRY_RUN}" == "true" ]]; then
    append_summary_list "Deleted tags" "dry-run only"
    append_summary_list "Deleted digests" "dry-run only"
  else
    append_summary_array_list "Deleted tags" DELETED_TAGS
    append_summary_array_list "Deleted digests" DELETED_DIGESTS
  fi
fi
