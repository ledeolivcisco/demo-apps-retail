#!/usr/bin/env bash
# Start/stop in-cluster inventory demo lock loop (HTTP chaos scenario).
#
# Usage (from repository root):
#   ./k8s/demo-lock-loop.sh start
#   ./k8s/demo-lock-loop.sh stop
#   ./k8s/demo-lock-loop.sh status
#   ./k8s/demo-lock-loop.sh logs
#
# Requires:
#   - wallmart Helm release deployed (product-service in namespace)
#   - appConfig.demoChaosEnabled=true (WALLMART_DEMO_CHAOS_ENABLED on product-service)
#
# Environment:
#   HELM_NAMESPACE / K8S_NAMESPACE   target namespace (default: wallmart)
#   HELM_RELEASE                   Helm release name (default: wallmart)
#   PRODUCT_SERVICE                product-service name (default: product-service)
#   PRODUCT_PORT                   product-service port (default: 8081)
#   DEMO_LOCK_SECONDS              lock duration query param (default: 60)
#   DEMO_LOCK_INTERVAL_SECONDS     sleep between requests (default: 60)
#   DEMO_LOCK_URL                  override full URL if needed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST_TEMPLATE="${SCRIPT_DIR}/manifests/demo-lock-loop.yaml"
DEPLOYMENT_NAME="demo-lock-loop"

NAMESPACE="${K8S_NAMESPACE:-${HELM_NAMESPACE:-wallmart}}"
RELEASE="${HELM_RELEASE:-wallmart}"
PRODUCT_SERVICE="${PRODUCT_SERVICE:-product-service}"
PRODUCT_PORT="${PRODUCT_PORT:-8081}"
LOCK_SECONDS="${DEMO_LOCK_SECONDS:-60}"
INTERVAL="${DEMO_LOCK_INTERVAL_SECONDS:-60}"
LOCK_URL="${DEMO_LOCK_URL:-}"
DEFAULT_LOCK_URL="http://${PRODUCT_SERVICE}:${PRODUCT_PORT}/internal/demo/db-lock/inventory?seconds=${LOCK_SECONDS}"

kubectl_bin="kubectl"
if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
  kubectl_bin="oc"
fi

read_env_var() {
  local file="$1" key="$2"
  local line val
  [[ -f "${file}" ]] || return 1
  line="$(grep -E "^${key}=" "${file}" 2>/dev/null | tail -1)" || return 1
  val="${line#*=}"
  val="${val%\"}"
  val="${val#\"}"
  val="${val%\'}"
  val="${val#\'}"
  [[ -n "${val}" ]] || return 1
  printf '%s' "${val}"
}

load_env_files() {
  for candidate in "${ROOT}/docker/.env" "${ROOT}/docker-standalone/.env"; do
    if [[ -f "${candidate}" ]]; then
      local ns
      ns="$(read_env_var "${candidate}" K8S_NAMESPACE)" \
        || ns="$(read_env_var "${candidate}" HELM_NAMESPACE)" \
        || true
      if [[ -n "${ns}" ]]; then
        NAMESPACE="${ns}"
      fi
      return 0
    fi
  done
}

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \?//'
}

configmap_name() {
  echo "${RELEASE}-app-config"
}

check_chaos_enabled() {
  local cm chaos
  cm="$(configmap_name)"
  if ! chaos="$("${kubectl_bin}" get configmap "${cm}" -n "${NAMESPACE}" -o jsonpath='{.data.WALLMART_DEMO_CHAOS_ENABLED}' 2>/dev/null)"; then
    echo "Warning: ConfigMap ${cm} not found; cannot verify WALLMART_DEMO_CHAOS_ENABLED." >&2
    return 0
  fi
  if [[ "${chaos}" != "true" ]]; then
    echo "Warning: WALLMART_DEMO_CHAOS_ENABLED is '${chaos:-false}' in ${cm}." >&2
    echo "Enable chaos and restart product-service:" >&2
    echo "  helm upgrade --install ${RELEASE} ${SCRIPT_DIR}/wallmart-ecommerce \\" >&2
    echo "    --namespace ${NAMESPACE} --reuse-values \\" >&2
    echo "    --set appConfig.demoChaosEnabled=true" >&2
    echo "  ${kubectl_bin} rollout restart deployment/${PRODUCT_SERVICE} -n ${NAMESPACE}" >&2
  fi
}

verify_prerequisites() {
  if ! "${kubectl_bin}" get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    echo "Namespace not found: ${NAMESPACE}" >&2
    exit 1
  fi
  if ! "${kubectl_bin}" get deployment "${PRODUCT_SERVICE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo "Deployment not found: ${PRODUCT_SERVICE} in ${NAMESPACE}" >&2
    exit 1
  fi
}

service_account_block() {
  if "${kubectl_bin}" get serviceaccount wallmart-app -n "${NAMESPACE}" >/dev/null 2>&1; then
    printf '      serviceAccountName: wallmart-app\n'
  fi
}

render_manifest() {
  if [[ ! -f "${MANIFEST_TEMPLATE}" ]]; then
    echo "Manifest template not found: ${MANIFEST_TEMPLATE}" >&2
    exit 1
  fi
  export NAMESPACE
  export DEMO_LOCK_SECONDS="${LOCK_SECONDS}"
  export DEMO_LOCK_INTERVAL_SECONDS="${INTERVAL}"
  export SUBST_LOCK_URL="${LOCK_URL}"
  export SUBST_CURL_URL="${DEFAULT_LOCK_URL}"
  export SERVICE_ACCOUNT_BLOCK
  SERVICE_ACCOUNT_BLOCK="$(service_account_block)"
  export SERVICE_ACCOUNT_BLOCK
  envsubst '${NAMESPACE} ${SERVICE_ACCOUNT_BLOCK} ${DEMO_LOCK_SECONDS} ${DEMO_LOCK_INTERVAL_SECONDS} ${SUBST_LOCK_URL} ${SUBST_CURL_URL}' < "${MANIFEST_TEMPLATE}"
}

cmd_start() {
  load_env_files
  verify_prerequisites
  check_chaos_enabled

  local url_display="${LOCK_URL:-${DEFAULT_LOCK_URL}}"
  echo "==> deploy ${DEPLOYMENT_NAME} in ${NAMESPACE}"
  echo "    url=${url_display} interval=${INTERVAL}s"

  render_manifest | "${kubectl_bin}" apply -f -

  echo "==> wait for rollout"
  "${kubectl_bin}" rollout status "deployment/${DEPLOYMENT_NAME}" -n "${NAMESPACE}" --timeout=120s
  echo
  echo "Started. Follow logs: ${SCRIPT_DIR}/demo-lock-loop.sh logs"
  echo "Stop:              ${SCRIPT_DIR}/demo-lock-loop.sh stop"
}

cmd_stop() {
  load_env_files
  echo "==> delete deployment/${DEPLOYMENT_NAME} in ${NAMESPACE}"
  if "${kubectl_bin}" delete deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" --ignore-not-found; then
    echo "Stopped."
  fi
}

cmd_status() {
  load_env_files
  if ! "${kubectl_bin}" get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo "demo-lock-loop: not running in ${NAMESPACE}"
    exit 0
  fi
  echo "==> deployment/${DEPLOYMENT_NAME}"
  "${kubectl_bin}" get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}"
  echo
  "${kubectl_bin}" get pods -n "${NAMESPACE}" -l app.kubernetes.io/component=demo-lock-loop
}

cmd_logs() {
  load_env_files
  local follow="-f"
  if [[ "${1:-}" == "--no-follow" ]]; then
    follow=""
    shift
  fi
  if ! "${kubectl_bin}" get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo "demo-lock-loop is not running in ${NAMESPACE} (try: start)" >&2
    exit 1
  fi
  # shellcheck disable=SC2086
  "${kubectl_bin}" logs "deployment/${DEPLOYMENT_NAME}" -n "${NAMESPACE}" ${follow} "$@"
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

case "$1" in
  start)
    cmd_start
    ;;
  stop)
    cmd_stop
    ;;
  status)
    cmd_status
    ;;
  logs)
    shift
    cmd_logs "$@"
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $1" >&2
    usage >&2
    exit 1
    ;;
esac
