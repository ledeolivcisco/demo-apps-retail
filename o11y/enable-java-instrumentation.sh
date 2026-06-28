#!/usr/bin/env bash
# Enable Splunk zero-code Java auto-instrumentation on wallmart Java backends.
#
# Usage (from repository root):
#   ./o11y/enable-java-instrumentation.sh
#   ./o11y/enable-java-instrumentation.sh --dry-run
#
# Adds cross-namespace annotation referencing the Instrumentation CR in splunk-otel,
# then restarts product-service, cart-service, and payment-service.
#
# Environment (from o11y/.env if present):
#   COLLECTOR_RELEASE, COLLECTOR_NAMESPACE, WALLMART_NAMESPACE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

RELEASE="${COLLECTOR_RELEASE:-splunk-otel-collector}"
COLLECTOR_NS="${COLLECTOR_NAMESPACE:-splunk-otel}"
WALLMART_NS="${WALLMART_NAMESPACE:-wallmart}"
ANNOTATION_KEY="instrumentation.opentelemetry.io/inject-java"

DRY_RUN=false

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \?//'
}

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "${ENV_FILE}"
  set +a
  RELEASE="${COLLECTOR_RELEASE:-${RELEASE}}"
  COLLECTOR_NS="${COLLECTOR_NAMESPACE:-${COLLECTOR_NS}}"
  WALLMART_NS="${WALLMART_NAMESPACE:-${WALLMART_NS}}"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required but not installed." >&2
  exit 1
fi

INJECT_VALUE="${COLLECTOR_NS}/${RELEASE}"

echo "Instrumentation reference: ${INJECT_VALUE}"
echo "Target namespace: ${WALLMART_NS}"
echo

echo "==> verify Instrumentation CR exists"
if ! kubectl get otelinst "${RELEASE}" -n "${COLLECTOR_NS}" >/dev/null 2>&1; then
  echo "Instrumentation CR '${RELEASE}' not found in namespace '${COLLECTOR_NS}'." >&2
  echo "Run ./o11y/install.sh first and wait for the operator to be ready." >&2
  exit 1
fi

java_deployments=(product-service cart-service payment-service)

for deploy in "${java_deployments[@]}"; do
  if ! kubectl get deployment "${deploy}" -n "${WALLMART_NS}" >/dev/null 2>&1; then
    echo "Deployment '${deploy}' not found in namespace '${WALLMART_NS}' (skipped)." >&2
    continue
  fi

  patch_payload=$(cat <<EOF
{"spec":{"template":{"metadata":{"annotations":{"${ANNOTATION_KEY}":"${INJECT_VALUE}"}}}}}
EOF
)

  if [[ "${DRY_RUN}" == true ]]; then
    echo "==> dry-run: would patch deployment/${deploy} with ${ANNOTATION_KEY}=${INJECT_VALUE}"
  else
    echo "==> patch deployment/${deploy}"
    kubectl patch deployment "${deploy}" -n "${WALLMART_NS}" -p "${patch_payload}"
    echo "==> rollout restart deployment/${deploy}"
    kubectl rollout restart "deployment/${deploy}" -n "${WALLMART_NS}"
    kubectl rollout status "deployment/${deploy}" -n "${WALLMART_NS}" --timeout=180s
  fi
done

echo
if [[ "${DRY_RUN}" == true ]]; then
  echo "Dry run complete."
else
  echo "Java auto-instrumentation enabled. Verify with:"
  echo "  ./o11y/verify.sh --java"
fi
