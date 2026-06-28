#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export SPLUNK_OTEL_SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

ROOT="$(skill_root)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "error: .env not found in ${ROOT}. Copy .env.example to .env and set SPLUNK_O11Y_ACCESS_TOKEN and SPLUNK_OPENSHIFT_CLUSTER_NAME (do not commit .env)." >&2
  exit 1
fi

if [[ ! -f values.yaml ]]; then
  echo "error: values.yaml not found in ${ROOT}. Copy a template from templates/ to values.yaml." >&2
  exit 1
fi

load_env

: "${SPLUNK_O11Y_ACCESS_TOKEN:?Set SPLUNK_O11Y_ACCESS_TOKEN in .env}"
: "${SPLUNK_OPENSHIFT_CLUSTER_NAME:?Set SPLUNK_OPENSHIFT_CLUSTER_NAME in .env}"

NAMESPACE="$(install_namespace)"
REALM="${SPLUNK_O11Y_REALM:-us1}"

ensure_namespace "$NAMESPACE"

if obi_enabled_in_values; then
  echo "OBI enabled in values.yaml — running prerequisites before Helm install..."
  bash "${SCRIPT_DIR}/prepare_obi_prerequisites.sh"
  HELM_TIMEOUT="${HELM_TIMEOUT_OBI:-8m}"
else
  HELM_TIMEOUT="${HELM_TIMEOUT:-5m}"
fi

helm upgrade --install splunk-otel-collector \
  --set="distribution=openshift,splunkObservability.accessToken=${SPLUNK_O11Y_ACCESS_TOKEN},clusterName=${SPLUNK_OPENSHIFT_CLUSTER_NAME},splunkObservability.realm=${REALM},gateway.enabled=false,splunkObservability.profilingEnabled=true,environment=${SPLUNK_OPENSHIFT_CLUSTER_NAME},operatorcrds.install=true,operator.enabled=true" \
  -n "${NAMESPACE}" -f ./values.yaml splunk-otel-collector-chart/splunk-otel-collector \
  --wait --timeout "${HELM_TIMEOUT}" > helm_stdout.txt 2> helm_stderr.txt

if [[ -s helm_stderr.txt ]]; then
  echo "error: helm wrote to helm_stderr.txt:" >&2
  cat helm_stderr.txt >&2
  exit 1
fi

# Recover OBI pods if a prior install created the DaemonSet before SCC binding (upgrade path).
if obi_enabled_in_values && oc get daemonset splunk-otel-collector-obi -n "${NAMESPACE}" &>/dev/null; then
  desired="$(oc get daemonset splunk-otel-collector-obi -n "${NAMESPACE}" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
  ready="$(oc get daemonset splunk-otel-collector-obi -n "${NAMESPACE}" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"
  if [[ "${ready:-0}" -lt "${desired:-0}" ]]; then
    echo "OBI DaemonSet not fully ready (${ready}/${desired}); restarting to pick up SCC binding..."
    oc rollout restart "daemonset/splunk-otel-collector-obi" -n "${NAMESPACE}"
    oc rollout status "daemonset/splunk-otel-collector-obi" -n "${NAMESPACE}" --timeout=5m
  fi
fi

echo "Helm release splunk-otel-collector deployed in namespace ${NAMESPACE}."
