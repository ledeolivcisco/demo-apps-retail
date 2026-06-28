#!/usr/bin/env bash
# Push locally tagged images to the registry (expects tags produced by build-all.sh).
# Pushes exactly the images defined in image-list.sh (same catalog as build-all.sh).
# For linux/amd64 + linux/arm64 manifest lists in the registry, use build-push-all.sh instead.
# Requires: docker login.
#
# Env overrides:
#   REGISTRY_PREFIX   default: leandrovo
#   IMAGE_TAG         default: latest
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=image-list.sh
source "${SCRIPT_DIR}/image-list.sh"

REGISTRY_PREFIX="${REGISTRY_PREFIX:-leandrovo}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

missing=()
for entry in "${WALLMART_IMAGES[@]}"; do
  image_suffix="${entry##*:}"
  image="${REGISTRY_PREFIX}/${image_suffix}:${IMAGE_TAG}"
  if ! docker image inspect "${image}" >/dev/null 2>&1; then
    missing+=("${image}")
  fi
done

if ((${#missing[@]} > 0)); then
  echo "Missing local images (run ./docker/scripts/build-all.sh first):" >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi

for entry in "${WALLMART_IMAGES[@]}"; do
  image_suffix="${entry##*:}"
  image="${REGISTRY_PREFIX}/${image_suffix}:${IMAGE_TAG}"
  echo "Pushing ${image}"
  docker push "${image}"
done

echo "Push complete (${#WALLMART_IMAGES[@]} images)."
