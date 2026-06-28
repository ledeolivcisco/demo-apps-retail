#!/usr/bin/env bash
# Install Splunk OpenTelemetry Collector on OpenShift (HEC logs + operator instrumentation).
#
# Usage (from repository root):
#   ./o11y/openshift/install.sh
#   ./o11y/openshift/install.sh --with-redaction
#   ./o11y/openshift/install.sh --dry-run
#
# Prerequisites:
#   cp o11y/.env.example o11y/.env   # fill SPLUNK_* tokens including HEC
#   helm 3, oc CLI, cluster-admin for SCC
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export O11Y_OPENSHIFT_ROOT="${SCRIPT_DIR}"
export O11Y_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${O11Y_ROOT}/.env"
VALUES_BASE="${SCRIPT_DIR}/values.example.yaml"
VALUES_LOCAL="${SCRIPT_DIR}/values-local.yaml"
VALUES_REDACTION="${SCRIPT_DIR}/values-redaction.example.yaml"
HELM_REPO_NAME="splunk-otel-collector-chart"
HELM_REPO_URL="https://signalfx.github.io/splunk-otel-collector-chart"
SECRET_NAME="splunk-otel-credentials"
HELM_STDERR="${SCRIPT_DIR}/helm_stderr.txt"

DRY_RUN=false
WITH_REDACTION=false

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \?//'
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

if ! command -v oc >/dev/null 2>&1; then
  echo "oc is required but not installed." >&2
  exit 1
fi

if ! oc whoami &>/dev/null; then
  echo "oc is not logged in. Run 'oc login' first." >&2
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}" >&2
  echo "Copy from example: cp ${O11Y_ROOT}/.env.example ${ENV_FILE}" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

RELEASE="${COLLECTOR_RELEASE:-splunk-otel-collector}"
NAMESPACE="${COLLECTOR_NAMESPACE:-splunk-otel}"
SPLUNK_HEC_INDEX="${SPLUNK_HEC_INDEX:-main}"
HELM_TIMEOUT="${HELM_TIMEOUT:-5m}"

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
  --set "secret.validateSecret=false"
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

echo "==> apply OpenShift SCC for collector agent"
if [[ "${DRY_RUN}" == true ]]; then
  echo "    (dry-run: would run ${SCRIPT_DIR}/scripts/apply_sec_ctx_constraints.sh)"
else
  bash "${SCRIPT_DIR}/scripts/apply_sec_ctx_constraints.sh"
fi

echo "==> helm repo add ${HELM_REPO_NAME} (if needed)"
helm repo add "${HELM_REPO_NAME}" "${HELM_REPO_URL}" 2>/dev/null || true
helm repo update "${HELM_REPO_NAME}"

echo "==> ensure namespace ${NAMESPACE}"
if [[ "${DRY_RUN}" == true ]]; then
  echo "    (dry-run: would create namespace ${NAMESPACE})"
else
  # shellcheck source=scripts/lib.sh
  source "${SCRIPT_DIR}/scripts/lib.sh"
  ensure_namespace "${NAMESPACE}"
fi

if [[ "${DRY_RUN}" == true ]]; then
  echo "==> dry-run: would create secret ${SECRET_NAME} in ${NAMESPACE}"
else
  echo "==> oc apply secret ${SECRET_NAME} in ${NAMESPACE}"
  oc create secret generic "${SECRET_NAME}" \
    --namespace "${NAMESPACE}" \
    --from-literal=splunk_observability_access_token="${SPLUNK_ACCESS_TOKEN}" \
    --from-literal=splunk_platform_hec_token="${SPLUNK_HEC_TOKEN}" \
    --dry-run=client -o yaml | oc apply -f -
  # shellcheck source=scripts/lib.sh
  source "${SCRIPT_DIR}/scripts/lib.sh"
  validate_collector_secret "${NAMESPACE}" "${SECRET_NAME}"
fi

validate_args=(
  template "${RELEASE}" "${HELM_REPO_NAME}/splunk-otel-collector"
  --namespace "${NAMESPACE}"
  -f "${VALUES_BASE}"
)
if [[ -f "${VALUES_LOCAL}" ]]; then
  validate_args+=(-f "${VALUES_LOCAL}")
fi
if [[ "${WITH_REDACTION}" == true ]]; then
  validate_args+=(-f "${VALUES_REDACTION}")
fi
validate_args+=(
  --set "clusterName=${CLUSTER_NAME}"
  --set "environment=${DEPLOYMENT_ENV}"
  --set "splunkObservability.realm=${SPLUNK_REALM}"
  --set "splunkPlatform.endpoint=${SPLUNK_HEC_ENDPOINT}"
  --set "splunkPlatform.index=${SPLUNK_HEC_INDEX}"
  --set "secret.create=false"
  --set "secret.name=${SECRET_NAME}"
  --set "secret.validateSecret=false"
)

echo "==> helm template (validate)"
helm "${validate_args[@]}" > /dev/null

if [[ "${DRY_RUN}" == true ]]; then
  echo "==> helm template ${RELEASE} (dry-run)"
  helm "${validate_args[@]}"
  exit 0
fi

echo "==> helm upgrade --install ${RELEASE} (timeout ${HELM_TIMEOUT})"
: > "${HELM_STDERR}"
helm "${helm_args[@]}" --wait --timeout "${HELM_TIMEOUT}" > "${SCRIPT_DIR}/helm_stdout.txt" 2> "${HELM_STDERR}"

if [[ -s "${HELM_STDERR}" ]]; then
  echo "error: helm wrote to ${HELM_STDERR}:" >&2
  cat "${HELM_STDERR}" >&2
  exit 1
fi

echo
echo "Installed release '${RELEASE}' in namespace '${NAMESPACE}' (OpenShift)."
echo
echo "Next steps:"
echo "  ./o11y/openshift/verify.sh"
echo "  ./k8s/install.sh                    # if the wallmart app is not deployed yet"
echo "  ./o11y/enable-java-instrumentation.sh"
if [[ "${WITH_REDACTION}" != true ]]; then
  echo "  ./o11y/openshift/install.sh --with-redaction    # mask credit card / SSN in HEC logs"
fi
echo
