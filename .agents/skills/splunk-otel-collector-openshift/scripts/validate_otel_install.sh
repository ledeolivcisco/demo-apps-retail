#!/usr/bin/env bash
# Validates Splunk OpenTelemetry Collector installation on OpenShift (namespace: otel).
# Exits 0 if checks pass; exits 1 with an explanation if the installation failed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export SPLUNK_OTEL_SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_env
NAMESPACE="${NAMESPACE:-$(install_namespace)}"
EXPECTED_INSTRUMENTATION_NAME="splunk-otel-collector"

fail() {
  echo "INSTALLATION FAILED: $*" >&2
  exit 1
}

need_oc() {
  if ! command -v oc >/dev/null 2>&1; then
    fail "The oc CLI is not installed or not on PATH."
  fi
}

# --- 1) Instrumentation: exactly one object named splunk-otel-collector ---
check_instrumentation() {
  local raw err names_array name count
  if ! raw=$(oc get instrumentation -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>&1); then
    fail "Could not list Instrumentation in namespace ${NAMESPACE}. oc said: ${raw}"
  fi

  # shellcheck disable=SC2206
  names_array=(${raw})
  count=${#names_array[@]}

  if [[ -z "$raw" || "$count" -eq 0 ]]; then
    fail "Instrumentation check: expected exactly one Instrumentation named \"${EXPECTED_INSTRUMENTATION_NAME}\", but none were found in namespace ${NAMESPACE}."
  fi

  if [[ "$count" -ne 1 ]]; then
    fail "Instrumentation check: expected exactly one Instrumentation object, found ${count} (${raw}). Only \"${EXPECTED_INSTRUMENTATION_NAME}\" is allowed."
  fi

  name="${names_array[0]}"
  if [[ "$name" != "$EXPECTED_INSTRUMENTATION_NAME" ]]; then
    fail "Instrumentation check: the single Instrumentation must be named \"${EXPECTED_INSTRUMENTATION_NAME}\", but got \"${name}\"."
  fi

  echo "OK: Instrumentation \"${EXPECTED_INSTRUMENTATION_NAME}\" exists (1 object)."
}

# --- 2) Worker nodes in Ready state (OpenShift: node-role.kubernetes.io/worker) ---
count_ready_workers() {
  local out count
  if ! out=$(oc get nodes -l node-role.kubernetes.io/worker --no-headers 2>&1); then
    fail "Could not list worker nodes (label node-role.kubernetes.io/worker). oc said: ${out}"
  fi

  if [[ -z "${out// }" ]]; then
    fail "No nodes matched worker label node-role.kubernetes.io/worker. Cannot compare agent pod count to ready workers."
  fi

  # NAME  STATUS  ROLES  ... — count lines where worker-tagged node is Ready
  count=$(awk '$2=="Ready"{c++} END{print c+0}' <<< "$out")

  if [[ "$count" -eq 0 ]]; then
    fail "Found worker-labeled nodes but none have STATUS Ready. Raw output:\n${out}"
  fi

  echo "$count"
}

# --- 3) Pods in otel: operator x1, cluster-receiver x1, agent count == ready workers ---
check_pods() {
  local ready_workers="$1"
  local pod_lines operator_count receiver_count agent_count total_pods msg

  if ! pod_lines=$(oc get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>&1); then
    fail "Could not list pods in namespace ${NAMESPACE}. oc said: ${pod_lines}"
  fi

  if [[ -z "${pod_lines// }" ]]; then
    fail "Pods check: no pods found in namespace ${NAMESPACE}."
  fi

  operator_count=$(grep -c 'operator' <<< "$pod_lines" || true)
  receiver_count=$(grep -c 'cluster-receiver' <<< "$pod_lines" || true)
  agent_count=$(grep -c 'agent' <<< "$pod_lines" || true)
  total_pods=$(grep -c . <<< "$pod_lines" || true)

  msg="Pods in ${NAMESPACE}: expected 1 name containing \"operator\", 1 containing \"cluster-receiver\", and ${ready_workers} names containing \"agent\" (matching Ready worker nodes). "

  if [[ "$operator_count" -ne 1 ]]; then
    fail "${msg}Found ${operator_count} pod name(s) containing \"operator\". Listing:\n${pod_lines}"
  fi

  if [[ "$receiver_count" -ne 1 ]]; then
    fail "${msg}Found ${receiver_count} pod name(s) containing \"cluster-receiver\". Listing:\n${pod_lines}"
  fi

  if [[ "$agent_count" -ne "$ready_workers" ]]; then
    fail "${msg}Found ${agent_count} pod name(s) containing \"agent\", but Ready worker count is ${ready_workers}. Listing:\n${pod_lines}"
  fi

  echo "OK: Pods — operator: 1, cluster-receiver: 1, agent: ${agent_count} (matches ${ready_workers} Ready worker(s)); ${total_pods} pod name(s) total."
}

# --- 4) OBI DaemonSet (when obi.enabled: true in values.yaml) ---
check_obi() {
  if ! obi_enabled_in_values; then
    return 0
  fi

  local desired ready
  if ! oc get daemonset splunk-otel-collector-obi -n "$NAMESPACE" &>/dev/null; then
    fail "OBI check: obi.enabled is true in values.yaml but DaemonSet splunk-otel-collector-obi was not found in namespace ${NAMESPACE}."
  fi

  desired="$(oc get daemonset splunk-otel-collector-obi -n "$NAMESPACE" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)"
  ready="$(oc get daemonset splunk-otel-collector-obi -n "$NAMESPACE" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)"

  if [[ "${desired:-0}" -eq 0 ]]; then
    fail "OBI check: DaemonSet splunk-otel-collector-obi has desiredNumberScheduled=0."
  fi

  if [[ "${ready:-0}" -ne "${desired}" ]]; then
    fail "OBI check: DaemonSet splunk-otel-collector-obi has ${ready}/${desired} pods ready. Check SCC binding (splunk-otel-obi-scc → $(obi_service_account)) and events in ${NAMESPACE}."
  fi

  echo "OK: OBI DaemonSet splunk-otel-collector-obi — ${ready}/${desired} pods ready."
}

main() {
  need_oc
  check_instrumentation

  local ready_workers
  ready_workers=$(count_ready_workers)
  echo "OK: Ready worker nodes (label node-role.kubernetes.io/worker, STATUS Ready, ROLES containing worker): ${ready_workers}."

  check_pods "$ready_workers"
  check_obi

  echo "All validation checks passed."
}

main "$@"
