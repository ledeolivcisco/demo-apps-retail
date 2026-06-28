#!/usr/bin/env bash
# Build and push all service images for linux/amd64 and linux/arm64 (Apple Silicon, ARM servers).
# Uses the same image catalog as build-all.sh / push-all.sh (image-list.sh).
# Requires: Docker Buildx, `docker login` to your registry (e.g. Docker Hub as user `leandrovo`).
#
# Env overrides:
#   REGISTRY_PREFIX   default: leandrovo  (images: ${REGISTRY_PREFIX}/product-service:tag)
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

echo "Registry prefix: ${REGISTRY_PREFIX}"
echo "Image tag:       ${IMAGE_TAG}"
echo "Platforms:       ${PLATFORMS}"
echo "Context root:    ${ROOT}"
echo

for entry in "${WALLMART_IMAGES[@]}"; do
  dockerfile_rel="${entry%%:*}"
  image_suffix="${entry##*:}"
  image="${REGISTRY_PREFIX}/${image_suffix}:${IMAGE_TAG}"
  echo "=== Building & pushing ${image} (${PLATFORMS}) ==="
  docker buildx build \
    --platform "${PLATFORMS}" \
    -f "${ROOT}/${dockerfile_rel}" \
    -t "${image}" \
    --push \
    "${ROOT}"
  echo
done

echo "All images pushed (${#WALLMART_IMAGES[@]})."
echo "Example: docker pull ${REGISTRY_PREFIX}/ecommerce-web:${IMAGE_TAG}"
echo "Synthetic: docker pull ${REGISTRY_PREFIX}/playwright-loop:${IMAGE_TAG}"
