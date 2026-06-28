#!/usr/bin/env bash
# Remove locally tagged FreshMart app images (same catalog as build-all.sh).
#
# Usage:
#   ./docker/scripts/delete-all-images.sh
#   ./docker/scripts/delete-all-images.sh --dry-run
#   REGISTRY_PREFIX=youruser IMAGE_TAG=dev ./docker/scripts/delete-all-images.sh -y
#   ./docker/scripts/delete-all-images.sh --all-tags
#   ./docker/scripts/delete-all-images.sh --prune-buildx -y
#
# Env overrides:
#   REGISTRY_PREFIX   default: leandrovo
#   IMAGE_TAG         default: latest
#   BUILDX_NAME       default: wallmart-multiarch
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=image-list.sh
source "${SCRIPT_DIR}/image-list.sh"

REGISTRY_PREFIX="${REGISTRY_PREFIX:-leandrovo}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
BUILDX_NAME="${BUILDX_NAME:-wallmart-multiarch}"

DRY_RUN=false
ASSUME_YES=false
ALL_TAGS=false
PRUNE_BUILDX=false

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \?//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -y|--yes)
      ASSUME_YES=true
      shift
      ;;
    --all-tags)
      ALL_TAGS=true
      shift
      ;;
    --prune-buildx)
      PRUNE_BUILDX=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! docker info >/dev/null 2>&1; then
  echo "Docker is required but not available." >&2
  exit 1
fi

targets=()
seen=()

add_target() {
  local ref="$1"
  local existing
  for existing in "${seen[@]:-}"; do
    if [[ "${existing}" == "${ref}" ]]; then
      return 0
    fi
  done
  seen+=("${ref}")
  targets+=("${ref}")
}

for entry in "${WALLMART_IMAGES[@]}"; do
  image_suffix="${entry##*:}"
  repo="${REGISTRY_PREFIX}/${image_suffix}"

  if [[ "${ALL_TAGS}" == true ]]; then
    while IFS= read -r ref; do
      [[ -z "${ref}" ]] && continue
      [[ "${ref}" == *":<none>" ]] && continue
      add_target "${ref}"
    done < <(docker images "${repo}" --format '{{.Repository}}:{{.Tag}}' 2>/dev/null || true)
  else
    add_target "${repo}:${IMAGE_TAG}"
  fi
done

existing=()
missing=()
for ref in "${targets[@]}"; do
  if docker image inspect "${ref}" >/dev/null 2>&1; then
    existing+=("${ref}")
  else
    missing+=("${ref}")
  fi
done

buildx_exists=false
if [[ "${PRUNE_BUILDX}" == true ]] && docker buildx inspect "${BUILDX_NAME}" >/dev/null 2>&1; then
  buildx_exists=true
fi

echo "Registry prefix: ${REGISTRY_PREFIX}"
if [[ "${ALL_TAGS}" == true ]]; then
  echo "Mode: all local tags for project image repos"
else
  echo "Image tag:       ${IMAGE_TAG}"
fi
echo

if ((${#existing[@]} == 0)); then
  echo "No matching local images to delete."
  if ((${#missing[@]} > 0)); then
    echo "Not found:"
    printf '  %s\n' "${missing[@]}"
  fi
else
  echo "Will remove (${#existing[@]}):"
  printf '  %s\n' "${existing[@]}"
fi

if ((${#missing[@]} > 0 && ${#existing[@]} > 0)); then
  echo
  echo "Not found (skipped):"
  printf '  %s\n' "${missing[@]}"
fi

if [[ "${PRUNE_BUILDX}" == true ]]; then
  echo
  if [[ "${buildx_exists}" == true ]]; then
    echo "Will remove buildx builder: ${BUILDX_NAME}"
  else
    echo "Buildx builder not found (skipped): ${BUILDX_NAME}"
  fi
fi

has_work=false
if ((${#existing[@]} > 0)); then
  has_work=true
fi
if [[ "${buildx_exists}" == true ]]; then
  has_work=true
fi

if [[ "${has_work}" == false ]]; then
  exit 0
fi

if [[ "${DRY_RUN}" == true ]]; then
  echo
  echo "Dry run — no images or builders removed."
  exit 0
fi

if [[ "${ASSUME_YES}" != true ]]; then
  echo
  read -r -p "Delete the image(s) above? [y/N] " reply
  if [[ ! "${reply}" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

failed=()
for ref in "${existing[@]}"; do
  echo "Removing ${ref}"
  if ! docker rmi "${ref}"; then
    failed+=("${ref}")
  fi
done

if [[ "${buildx_exists}" == true ]]; then
  echo "Removing buildx builder ${BUILDX_NAME}"
  if ! docker buildx rm "${BUILDX_NAME}"; then
    failed+=("buildx:${BUILDX_NAME}")
  fi
fi

if ((${#failed[@]} > 0)); then
  echo "Failed to remove:" >&2
  printf '  %s\n' "${failed[@]}" >&2
  echo "Tip: stop containers using these images, then retry." >&2
  exit 1
fi

echo "Done."
