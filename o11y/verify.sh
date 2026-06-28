#!/usr/bin/env bash
# Verify Splunk OpenTelemetry Collector and optional Java auto-instrumentation.
#
# Usage (from repository root):
#   ./o11y/verify.sh
#   ./o11y/verify.sh --java
#
# Environment (from o11y/.env if present):
#   COLLECTOR_RELEASE, COLLECTOR_NAMESPACE, WALLMART_NAMESPACE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

RELEASE="${COLLECTOR_RELEASE:-splunk-otel-collector}"
NAMESPACE="${COLLECTOR_NAMESPACE:-splunk-otel}"
WALLMART_NS="${WALLMART_NAMESPACE:-wallmart}"
CHECK_JAVA=false

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \?//'
}

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "${ENV_FILE}"
  set +a
  RELEASE="${COLLECTOR_RELEASE:-${RELEASE}}"
  NAMESPACE="${COLLECTOR_NAMESPACE:-${NAMESPACE}}"
  WALLMART_NS="${WALLMART_NAMESPACE:-${WALLMART_NS}}"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --java)
      CHECK_JAVA=true
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

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required but not installed." >&2
  exit 1
fi

failures=0

check() {
  local label="$1"
  shift
  echo "==> ${label}"
  if "$@"; then
    echo "OK"
  else
    echo "FAIL" >&2
    failures=$((failures + 1))
  fi
  echo
}

check "Helm release status" helm status "${RELEASE}" -n "${NAMESPACE}" --short

check "Collector agent DaemonSet pods" bash -c "
  kubectl get pods -n '${NAMESPACE}' -l app.kubernetes.io/instance=${RELEASE} -o wide | grep -E '${RELEASE}-agent|component=agent' &&
  kubectl wait --for=condition=Ready pod -n '${NAMESPACE}' -l app.kubernetes.io/instance=${RELEASE} --field-selector=status.phase=Running --timeout=120s
"

check "Cluster receiver deployment" bash -c "
  kubectl get deploy -n '${NAMESPACE}' -l app.kubernetes.io/instance=${RELEASE} -o name | grep cluster-receiver &&
  kubectl wait --for=condition=Available deploy -n '${NAMESPACE}' -l app.kubernetes.io/instance=${RELEASE} --timeout=120s
"

check "OpenTelemetry Operator" bash -c "
  kubectl get deploy -n '${NAMESPACE}' -l app.kubernetes.io/instance=${RELEASE} -o name | grep opentelemetry-operator &&
  kubectl get pods -n '${NAMESPACE}' -l app.kubernetes.io/name=opentelemetry-operator --no-headers | grep -q Running
"

check "Admission webhooks" bash -c "
  kubectl get validatingwebhookconfiguration | grep -F '${RELEASE}' &&
  kubectl get mutatingwebhookconfiguration | grep -F '${RELEASE}'
"

check "Instrumentation CR" bash -c "kubectl get otelinst -n '${NAMESPACE}'"

if [[ "${CHECK_JAVA}" == true ]]; then
  java_services=(product-service cart-service payment-service)
  for svc in "${java_services[@]}"; do
    check "Java instrumentation on ${svc}" bash -c "
      pod=\$(kubectl get pods -n '${WALLMART_NS}' -l app.kubernetes.io/name=${svc} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) &&
      [[ -n \"\${pod}\" ]] &&
      kubectl get pod \"\${pod}\" -n '${WALLMART_NS}' -o jsonpath='{.spec.initContainers[*].name}' | grep -q opentelemetry-auto-instrumentation &&
      kubectl get pod \"\${pod}\" -n '${WALLMART_NS}' -o jsonpath='{.spec.containers[?(@.name==\"${svc}\")].env[*].name}' | grep -q OTEL_SERVICE_NAME
    "
  done
fi

if [[ "${failures}" -gt 0 ]]; then
  echo "${failures} check(s) failed." >&2
  exit 1
fi

echo "All checks passed."
