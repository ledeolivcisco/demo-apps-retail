#!/usr/bin/env bash
# Verify Splunk OpenTelemetry Collector on OpenShift (HEC + operator + optional Java).
#
# Usage (from repository root):
#   ./o11y/openshift/verify.sh
#   ./o11y/openshift/verify.sh --java
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export O11Y_OPENSHIFT_ROOT="${SCRIPT_DIR}"
export O11Y_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${O11Y_ROOT}/.env"

RELEASE="${COLLECTOR_RELEASE:-splunk-otel-collector}"
NAMESPACE="${COLLECTOR_NAMESPACE:-splunk-otel}"
WALLMART_NS="${WALLMART_NAMESPACE:-wallmart}"
CHECK_JAVA=false

usage() {
  sed -n '2,7p' "$0" | sed 's/^# \?//'
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

if ! command -v oc >/dev/null 2>&1; then
  echo "oc is required but not installed." >&2
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

check "Instrumentation CR (splunk-otel-collector)" bash -c "
  raw=\$(oc get instrumentation -n '${NAMESPACE}' -o jsonpath='{.items[*].metadata.name}' 2>/dev/null) &&
  [[ \"\${raw}\" == '${RELEASE}' ]]
"

check "Ready worker nodes vs agent pods" bash -c "
  ready_workers=\$(oc get nodes -l node-role.kubernetes.io/worker --no-headers 2>/dev/null | awk '\$2==\"Ready\"{c++} END{print c+0}') &&
  [[ \"\${ready_workers}\" -gt 0 ]] &&
  agent_count=\$(oc get pods -n '${NAMESPACE}' -o jsonpath='{range .items[*]}{.metadata.name}{\"\\n\"}{end}' | grep -c agent || true) &&
  [[ \"\${agent_count}\" -eq \"\${ready_workers}\" ]]
"

check "Cluster receiver deployment" bash -c "
  oc get deploy -n '${NAMESPACE}' -o name | grep -q cluster-receiver &&
  oc get pods -n '${NAMESPACE}' -o name | grep cluster-receiver | xargs -I{} oc get {} -n '${NAMESPACE}' -o jsonpath='{.status.phase}' | grep -q Running
"

check "OpenTelemetry Operator" bash -c "
  oc get deploy -n '${NAMESPACE}' -o name | grep -q operator &&
  oc get pods -n '${NAMESPACE}' -l app.kubernetes.io/name=opentelemetry-operator --no-headers | grep -q Running
"

check "Admission webhooks" bash -c "
  oc get validatingwebhookconfiguration 2>/dev/null | grep -F '${RELEASE}' &&
  oc get mutatingwebhookconfiguration 2>/dev/null | grep -F '${RELEASE}'
"

check "HEC credentials secret" bash -c "
  oc get secret splunk-otel-credentials -n '${NAMESPACE}' -o jsonpath='{.data}' | grep -q splunk_platform_hec_token
"

check "Container log collection enabled in Helm values" bash -c "
  helm get values '${RELEASE}' -n '${NAMESPACE}' -o yaml 2>/dev/null | grep -A2 'logsCollection:' | grep -q 'enabled: true'
"

if [[ "${CHECK_JAVA}" == true ]]; then
  java_services=(product-service cart-service payment-service)
  for svc in "${java_services[@]}"; do
    check "Java instrumentation on ${svc}" bash -c "
      pod=\$(oc get pods -n '${WALLMART_NS}' -l app.kubernetes.io/name=${svc} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) &&
      [[ -n \"\${pod}\" ]] &&
      oc get pod \"\${pod}\" -n '${WALLMART_NS}' -o jsonpath='{.spec.initContainers[*].name}' | grep -q opentelemetry-auto-instrumentation &&
      oc get pod \"\${pod}\" -n '${WALLMART_NS}' -o jsonpath='{.spec.containers[?(@.name==\"${svc}\")].env[*].name}' | grep -q OTEL_SERVICE_NAME
    "
  done
fi

if [[ "${failures}" -gt 0 ]]; then
  echo "${failures} check(s) failed." >&2
  exit 1
fi

echo "All checks passed."
echo
echo "HEC validation: search Splunk for payment.confirmed after checkout."
echo "  Raw pod logs may still show fake PII: oc logs -n ${WALLMART_NS} deploy/payment-service"
