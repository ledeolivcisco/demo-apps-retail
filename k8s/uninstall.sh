#!/usr/bin/env bash
# Uninstall the wallmart-ecommerce Helm release.
#
# Usage (from repository root):
#   ./k8s/uninstall.sh
#   ./k8s/uninstall.sh -y
#   ./k8s/uninstall.sh --delete-pvc -y
#   ./k8s/uninstall.sh --delete-pvc --delete-namespace -y
#   ./k8s/uninstall.sh --dry-run
#
# Environment:
#   HELM_RELEASE     Release name (default: wallmart)
#   HELM_NAMESPACE   Namespace (default: wallmart)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RELEASE="${HELM_RELEASE:-wallmart}"
NAMESPACE="${HELM_NAMESPACE:-wallmart}"

ASSUME_YES=false
DRY_RUN=false
DELETE_PVC=false
DELETE_NAMESPACE=false

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \?//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      ASSUME_YES=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --delete-pvc)
      DELETE_PVC=true
      shift
      ;;
    --delete-namespace)
      DELETE_NAMESPACE=true
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

if ! command -v helm >/dev/null 2>&1; then
  echo "helm is required but not installed (Helm 3)." >&2
  exit 1
fi

release_exists=false
if helm status "${RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  release_exists=true
fi

pvcs=()
if command -v kubectl >/dev/null 2>&1; then
  while IFS= read -r pvc; do
    [[ -z "${pvc}" ]] && continue
    pvcs+=("${pvc}")
  done < <(kubectl get pvc -n "${NAMESPACE}" -l app.kubernetes.io/name=sqlserver -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
fi

namespace_exists=false
if command -v kubectl >/dev/null 2>&1; then
  if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    namespace_exists=true
  fi
fi

echo "Release:   ${RELEASE}"
echo "Namespace: ${NAMESPACE}"
echo

if [[ "${release_exists}" == true ]]; then
  echo "Will uninstall Helm release: ${RELEASE}"
else
  echo "Helm release not found (skipped): ${RELEASE} in ${NAMESPACE}"
fi

if [[ "${DELETE_PVC}" == true ]]; then
  if ((${#pvcs[@]} > 0)); then
    echo "Will delete PVC(s):"
    printf '  %s\n' "${pvcs[@]}"
  else
    echo "No SQL Server PVCs found (skipped)"
  fi
else
  if ((${#pvcs[@]} > 0)); then
    echo "SQL Server PVC(s) retained (use --delete-pvc to remove):"
    printf '  %s\n' "${pvcs[@]}"
  fi
fi

if [[ "${DELETE_NAMESPACE}" == true ]]; then
  if [[ "${namespace_exists}" == true ]]; then
    echo "Will delete namespace: ${NAMESPACE}"
  else
    echo "Namespace not found (skipped): ${NAMESPACE}"
  fi
fi

has_work=false
if [[ "${release_exists}" == true ]]; then
  has_work=true
fi
if [[ "${DELETE_PVC}" == true && ${#pvcs[@]} -gt 0 ]]; then
  has_work=true
fi
if [[ "${DELETE_NAMESPACE}" == true && "${namespace_exists}" == true ]]; then
  has_work=true
fi

if [[ "${has_work}" == false ]]; then
  echo
  echo "Nothing to uninstall or delete."
  exit 0
fi

if [[ "${DRY_RUN}" == true ]]; then
  echo
  echo "Dry run — no changes made."
  exit 0
fi

if [[ "${ASSUME_YES}" != true ]]; then
  echo
  read -r -p "Proceed? [y/N] " reply
  if [[ ! "${reply}" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

if [[ "${release_exists}" == true ]]; then
  echo "==> helm uninstall ${RELEASE} -n ${NAMESPACE}"
  helm uninstall "${RELEASE}" -n "${NAMESPACE}"
fi

if [[ "${DELETE_PVC}" == true && ${#pvcs[@]} -gt 0 ]]; then
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl is required for --delete-pvc." >&2
    exit 1
  fi
  for pvc in "${pvcs[@]}"; do
    echo "==> kubectl delete pvc ${pvc} -n ${NAMESPACE}"
    kubectl delete pvc "${pvc}" -n "${NAMESPACE}"
  done
fi

if [[ "${DELETE_NAMESPACE}" == true && "${namespace_exists}" == true ]]; then
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl is required for --delete-namespace." >&2
    exit 1
  fi
  echo "==> kubectl delete namespace ${NAMESPACE}"
  kubectl delete namespace "${NAMESPACE}"
fi

echo
echo "Done."
