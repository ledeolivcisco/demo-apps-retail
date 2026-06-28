#!/usr/bin/env bash
# Build ecommerce-web only (multi-arch). Browser RUM is baked from docker/.env at build time.
#
# Usage:
#   ./docker/scripts/build-web-only.sh           # load into local Docker
#   ./docker/scripts/build-web-only.sh --push    # build and push to registry
#
# Env overrides (same as build-all.sh):
#   REGISTRY_PREFIX   default: leandrovo
#   IMAGE_TAG         default: latest
#   PLATFORMS         default: linux/amd64,linux/arm64
#   BUILDX_NAME       default: wallmart-multiarch
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=image-list.sh
source "${SCRIPT_DIR}/image-list.sh"
cd "${ROOT}"

REGISTRY_PREFIX="${REGISTRY_PREFIX:-leandrovo}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILDX_NAME="${BUILDX_NAME:-wallmart-multiarch}"
PUSH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push)
      PUSH=true
      shift
      ;;
    -h | --help)
      sed -n '2,12p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "${ROOT}/docker/.env" ]]; then
  echo "docker/.env not found. Copy docker/.env.example and set VITE_* before building ecommerce-web." >&2
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "docker buildx is required." >&2
  exit 1
fi

if ! docker buildx inspect "${BUILDX_NAME}" >/dev/null 2>&1; then
  echo "Creating buildx builder: ${BUILDX_NAME}"
  docker buildx create --name "${BUILDX_NAME}" --driver docker-container --use
else
  docker buildx use "${BUILDX_NAME}"
fi

dockerfile_rel="${WALLMART_WEB_IMAGE%%:*}"
image_suffix="${WALLMART_WEB_IMAGE##*:}"
image="${REGISTRY_PREFIX}/${image_suffix}:${IMAGE_TAG}"

echo "Registry prefix: ${REGISTRY_PREFIX}"
echo "Image:           ${image}"
echo "Platforms:       ${PLATFORMS}"
echo "Push:            ${PUSH}"
echo

build_args=(
  --platform "${PLATFORMS}"
  -f "${ROOT}/${dockerfile_rel}"
  -t "${image}"
)

if [[ "${PUSH}" == true ]]; then
  build_args+=(--push)
else
  build_args+=(--load)
fi

echo "=== Building ${image} (${PLATFORMS}) ==="
docker buildx build "${build_args[@]}" "${ROOT}"

if [[ "${PUSH}" == true ]]; then
  echo "Pushed ${image}"
else
  echo "Loaded ${image} into local Docker"
fi
