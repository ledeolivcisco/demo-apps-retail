#!/usr/bin/env bash
# Install or upgrade the Splunk OpenTelemetry Collector (cluster monitoring + operator).
#
# Usage (from repository root):
#   ./o11y/install.sh
#   ./o11y/install.sh --with-redaction
#   ./o11y/install.sh --dry-run
#
# Prerequisites:
#   cp o11y/.env.example o11y/.env   # fill SPLUNK_* tokens
#   helm 3, kubectl, cluster access
#
# Environment (from o11y/.env or shell):
#   SPLUNK_REALM, SPLUNK_ACCESS_TOKEN, SPLUNK_HEC_TOKEN, SPLUNK_HEC_ENDPOINT
#   CLUSTER_NAME, DEPLOYMENT_ENV, COLLECTOR_NAMESPACE, COLLECTOR_RELEASE
#   SPLUNK_HEC_INDEX (optional, default: main)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
VALUES_BASE="${SCRIPT_DIR}/values.example.yaml"
VALUES_LOCAL="${SCRIPT_DIR}/values-local.yaml"
VALUES_REDACTION="${SCRIPT_DIR}/values-redaction.example.yaml"
HELM_REPO_NAME="splunk-otel-collector-chart"
HELM_REPO_URL="https://signalfx.github.io/splunk-otel-collector-chart"
SECRET_NAME="splunk-otel-credentials"

DRY_RUN=false
WITH_REDACTION=false

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \?//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --with-redaction)
      WITH_REDACTION=true
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

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required but not installed." >&2
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}" >&2
  echo "Copy from example: cp ${SCRIPT_DIR}/.env.example ${ENV_FILE}" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

RELEASE="${COLLECTOR_RELEASE:-splunk-otel-collector}"
NAMESPACE="${COLLECTOR_NAMESPACE:-splunk-otel}"
SPLUNK_HEC_INDEX="${SPLUNK_HEC_INDEX:-main}"

require_var() {
  local name="$1"
  local value="$2"
  if [[ -z "${value}" ]]; then
    echo "Set ${name} in ${ENV_FILE}." >&2
    exit 1
  fi
}

require_var "SPLUNK_REALM" "${SPLUNK_REALM:-}"
require_var "SPLUNK_ACCESS_TOKEN" "${SPLUNK_ACCESS_TOKEN:-}"
require_var "SPLUNK_HEC_TOKEN" "${SPLUNK_HEC_TOKEN:-}"
require_var "SPLUNK_HEC_ENDPOINT" "${SPLUNK_HEC_ENDPOINT:-}"
require_var "CLUSTER_NAME" "${CLUSTER_NAME:-}"
require_var "DEPLOYMENT_ENV" "${DEPLOYMENT_ENV:-}"

helm_args=(
  upgrade --install "${RELEASE}" "${HELM_REPO_NAME}/splunk-otel-collector"
  --namespace "${NAMESPACE}"
  --create-namespace
  -f "${VALUES_BASE}"
  --set "clusterName=${CLUSTER_NAME}"
  --set "environment=${DEPLOYMENT_ENV}"
  --set "splunkObservability.realm=${SPLUNK_REALM}"
  --set "splunkPlatform.endpoint=${SPLUNK_HEC_ENDPOINT}"
  --set "splunkPlatform.index=${SPLUNK_HEC_INDEX}"
  --set "secret.create=false"
  --set "secret.name=${SECRET_NAME}"
)

if [[ -f "${VALUES_LOCAL}" ]]; then
  helm_args+=(-f "${VALUES_LOCAL}")
fi

if [[ "${WITH_REDACTION}" == true ]]; then
  if [[ ! -f "${VALUES_REDACTION}" ]]; then
    echo "Missing ${VALUES_REDACTION}" >&2
    exit 1
  fi
  helm_args+=(-f "${VALUES_REDACTION}")
fi

echo "==> helm repo add ${HELM_REPO_NAME} (if needed)"
helm repo add "${HELM_REPO_NAME}" "${HELM_REPO_URL}" 2>/dev/null || true
helm repo update "${HELM_REPO_NAME}"

echo "==> kubectl create namespace ${NAMESPACE} (if needed)"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

if [[ "${DRY_RUN}" == true ]]; then
  echo "==> dry-run: would create secret ${SECRET_NAME} in ${NAMESPACE}"
else
  echo "==> kubectl apply secret ${SECRET_NAME} in ${NAMESPACE}"
  kubectl create secret generic "${SECRET_NAME}" \
    --namespace "${NAMESPACE}" \
    --from-literal=splunk_observability_access_token="${SPLUNK_ACCESS_TOKEN}" \
    --from-literal=splunk_platform_hec_token="${SPLUNK_HEC_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "==> helm lint"
lint_args=(lint "${HELM_REPO_NAME}/splunk-otel-collector" -f "${VALUES_BASE}")
if [[ -f "${VALUES_LOCAL}" ]]; then
  lint_args+=(-f "${VALUES_LOCAL}")
fi
if [[ "${WITH_REDACTION}" == true ]]; then
  lint_args+=(-f "${VALUES_REDACTION}")
fi
helm "${lint_args[@]}" \
  --set "clusterName=${CLUSTER_NAME}" \
  --set "environment=${DEPLOYMENT_ENV}" \
  --set "splunkObservability.realm=${SPLUNK_REALM}" \
  --set "splunkPlatform.endpoint=${SPLUNK_HEC_ENDPOINT}" \
  --set "splunkPlatform.index=${SPLUNK_HEC_INDEX}" \
  --set "secret.create=false" \
  --set "secret.name=${SECRET_NAME}"

if [[ "${DRY_RUN}" == true ]]; then
  echo "==> helm template ${RELEASE} (dry-run)"
  helm template "${RELEASE}" "${helm_args[@]}"
  exit 0
fi

echo "==> helm upgrade --install ${RELEASE}"
helm "${helm_args[@]}"

echo
echo "Installed release '${RELEASE}' in namespace '${NAMESPACE}'."
echo
echo "Next steps:"
echo "  ./o11y/verify.sh"
echo "  ./k8s/install.sh                    # if the wallmart app is not deployed yet"
echo "  ./o11y/enable-java-instrumentation.sh"
if [[ "${WITH_REDACTION}" != true ]]; then
  echo "  ./o11y/install.sh --with-redaction    # mask credit card / SSN in logs and traces"
fi
echo
