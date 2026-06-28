#!/usr/bin/env bash
# Build and push images with scenario-specific IMAGE_TAG (appd | splunk).
#
# JVM backend images are identical for both scenarios; only ecommerce-web differs
# (VITE_OBSERVABILITY_BACKEND baked at build time). Use --web-only to push only the web image.
#
# Usage:
#   ./docker/scripts/build-push-scenario.sh appd
#   ./docker/scripts/build-push-scenario.sh splunk
#   ./docker/scripts/build-push-scenario.sh appd --web-only
#   ./docker/scripts/build-push-scenario.sh splunk --web-only
#
# Prerequisites:
#   docker/.env with VITE_OBSERVABILITY_BACKEND matching the scenario:
#     appd   → appdynamics
#     splunk → splunk
#
# Env overrides: REGISTRY_PREFIX, PLATFORMS, BUILDX_NAME (passed to child scripts).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=image-list.sh
source "${SCRIPT_DIR}/image-list.sh"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \?//'
}

read_vite_backend_from_env() {
  local env_file="${ROOT}/docker/.env"
  if [[ ! -f "${env_file}" ]]; then
    echo "docker/.env not found. Copy docker/.env.example and configure VITE_* for your scenario." >&2
    exit 1
  fi
  local line
  line="$(grep -E '^[[:space:]]*VITE_OBSERVABILITY_BACKEND=' "${env_file}" | head -1 || true)"
  if [[ -z "${line}" ]]; then
    # Legacy: VITE_APPDYNAMICS_ENABLED=true implies appdynamics
    if grep -qE '^[[:space:]]*VITE_APPDYNAMICS_ENABLED=true' "${env_file}"; then
      echo appdynamics
      return 0
    fi
    echo "VITE_OBSERVABILITY_BACKEND is not set in docker/.env" >&2
    exit 1
  fi
  echo "${line#*=}" | tr -d ' "'\'''
}

SCENARIO=""
WEB_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    'appd' | 'appdynamics' | 'splunk' | 'o11y')
      SCENARIO="$1"
      shift
      ;;
    --web-only)
      WEB_ONLY=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${SCENARIO}" ]]; then
  echo "Scenario required: appd or splunk" >&2
  usage >&2
  exit 1
fi

IMAGE_TAG="$(wallmart_scenario_image_tag "${SCENARIO}")"
expected_backend="$(wallmart_scenario_vite_backend "${SCENARIO}")"
actual_backend="$(read_vite_backend_from_env)"

if [[ "${actual_backend}" != "${expected_backend}" ]]; then
  echo "docker/.env mismatch for scenario '${SCENARIO}':" >&2
  echo "  expected VITE_OBSERVABILITY_BACKEND=${expected_backend}" >&2
  echo "  found    VITE_OBSERVABILITY_BACKEND=${actual_backend}" >&2
  echo "Update docker/.env, then re-run." >&2
  exit 1
fi

export IMAGE_TAG
echo "Scenario:  ${SCENARIO}"
echo "Image tag: ${IMAGE_TAG}"
echo "Web only:  ${WEB_ONLY}"
echo

if [[ "${WEB_ONLY}" == true ]]; then
  exec "${SCRIPT_DIR}/build-web-only.sh" --push
else
  exec "${SCRIPT_DIR}/build-push-all.sh"
fi
