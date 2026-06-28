#!/usr/bin/env bash
# Install or upgrade the wallmart-ecommerce Helm chart.
#
# Usage (from repository root):
#   ./k8s/install.sh                  # values-local.yaml if present, else env / .env
#   ./k8s/install.sh --cloud          # cloud defaults (LoadBalancer)
#   ./k8s/install.sh --local          # require values-local.yaml
#   ./k8s/install.sh --synthetic      # enable Playwright loop
#   ./k8s/install.sh --dry-run        # render manifests only
#
# Environment (when not using values-local.yaml):
#   MSSQL_SA_PASSWORD   SQL Server SA password (required unless in values file)
#   REGISTRY_PREFIX     Image registry (default: leandrovo)
#   IMAGE_TAG           Image tag (default: latest)
#   HELM_RELEASE        Release name (default: wallmart)
#   HELM_NAMESPACE      Namespace (default: wallmart)
#
# Password is also read from docker/.env or docker-standalone/.env if unset.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHART="${SCRIPT_DIR}/wallmart-ecommerce"
VALUES_LOCAL="${CHART}/values-local.yaml"
VALUES_EXAMPLE="${CHART}/values-local.example.yaml"

RELEASE="${HELM_RELEASE:-wallmart}"
NAMESPACE="${HELM_NAMESPACE:-wallmart}"
REGISTRY_PREFIX="${REGISTRY_PREFIX:-leandrovo}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

MODE="auto"
SYNTHETIC=false
DRY_RUN=false

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \?//'
}

load_env_files() {
  if [[ -n "${MSSQL_SA_PASSWORD:-}" ]]; then
    return 0
  fi
  for candidate in "${ROOT}/docker/.env" "${ROOT}/docker-standalone/.env"; do
    if [[ -f "${candidate}" ]]; then
      # shellcheck disable=SC1090
      set -a
      source "${candidate}"
      set +a
      REGISTRY_PREFIX="${REGISTRY_PREFIX:-leandrovo}"
      IMAGE_TAG="${IMAGE_TAG:-latest}"
      return 0
    fi
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)
      MODE="local"
      shift
      ;;
    --cloud)
      MODE="cloud"
      shift
      ;;
    --synthetic)
      SYNTHETIC=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
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

if [[ ! -d "${CHART}" ]]; then
  echo "Chart not found: ${CHART}" >&2
  exit 1
fi

helm_args=(
  --namespace "${NAMESPACE}"
  --create-namespace
)

use_values_local=false
case "${MODE}" in
  local)
    if [[ ! -f "${VALUES_LOCAL}" ]]; then
      echo "Missing ${VALUES_LOCAL}" >&2
      echo "Copy from example: cp ${VALUES_EXAMPLE} ${VALUES_LOCAL}" >&2
      exit 1
    fi
    use_values_local=true
    ;;
  cloud)
    use_values_local=false
    ;;
  auto)
    if [[ -f "${VALUES_LOCAL}" ]]; then
      use_values_local=true
    fi
    ;;
esac

if [[ "${use_values_local}" == true ]]; then
  if grep -q 'REPLACE_ME' "${VALUES_LOCAL}" 2>/dev/null; then
    echo "Set mssql.password in ${VALUES_LOCAL} (replace REPLACE_ME)." >&2
    exit 1
  fi
  helm_args+=(-f "${VALUES_LOCAL}")
else
  load_env_files
  if [[ -z "${MSSQL_SA_PASSWORD:-}" ]]; then
    echo "Set MSSQL_SA_PASSWORD or create ${VALUES_LOCAL} from ${VALUES_EXAMPLE}." >&2
    exit 1
  fi
  helm_args+=(
    --set "global.imageRegistry=${REGISTRY_PREFIX}"
    --set "global.imageTag=${IMAGE_TAG}"
    --set "mssql.password=${MSSQL_SA_PASSWORD}"
  )
fi

if [[ "${SYNTHETIC}" == true ]]; then
  helm_args+=(--set synthetic.enabled=true)
fi

echo "==> helm lint ${CHART}"
lint_args=(lint "${CHART}")
if [[ "${use_values_local}" == true ]]; then
  lint_args+=(-f "${VALUES_LOCAL}")
else
  lint_args+=(--set "mssql.password=${MSSQL_SA_PASSWORD}")
fi
helm "${lint_args[@]}"

if [[ "${DRY_RUN}" == true ]]; then
  echo "==> helm template ${RELEASE} ${CHART} (dry-run)"
  helm template "${RELEASE}" "${CHART}" "${helm_args[@]}"
  exit 0
fi

echo "==> helm upgrade --install ${RELEASE} ${CHART}"
helm upgrade --install "${RELEASE}" "${CHART}" "${helm_args[@]}"

echo
echo "Installed release '${RELEASE}' in namespace '${NAMESPACE}'."
echo
helm status "${RELEASE}" -n "${NAMESPACE}" --short 2>/dev/null || true
echo
kubectl get pods -n "${NAMESPACE}" 2>/dev/null || echo "(kubectl not available — skip pod status)"
echo
if [[ "${use_values_local}" == true ]] || kubectl get svc ecommerce-web -n "${NAMESPACE}" -o jsonpath='{.spec.type}' 2>/dev/null | grep -qx ClusterIP; then
  echo "Local / ClusterIP access:"
  echo "  kubectl port-forward svc/ecommerce-web 8080:80 -n ${NAMESPACE}"
  echo "  open http://localhost:8080"
else
  echo "LoadBalancer access:"
  echo "  kubectl get svc ecommerce-web -n ${NAMESPACE}"
fi
