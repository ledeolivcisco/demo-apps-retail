#!/usr/bin/env bash
# Build all images for linux/amd64 and linux/arm64 (no registry push).
# Uses Docker Buildx. If multi-platform --load fails on your Docker version, use build-push-all.sh.
#
# Env overrides:
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

echo "Building (${PLATFORMS}) with prefix ${REGISTRY_PREFIX} tag ${IMAGE_TAG}"

for entry in "${WALLMART_IMAGES[@]}"; do
  dockerfile_rel="${entry%%:*}"
  image_suffix="${entry##*:}"
  image="${REGISTRY_PREFIX}/${image_suffix}:${IMAGE_TAG}"
  echo "=== Building ${image} (${PLATFORMS}) ==="
  docker buildx build \
    --platform "${PLATFORMS}" \
    -f "${ROOT}/${dockerfile_rel}" \
    -t "${image}" \
    --load \
    "${ROOT}"
  echo
done

echo "Done. Images loaded locally as ${REGISTRY_PREFIX}/*:${IMAGE_TAG}"
