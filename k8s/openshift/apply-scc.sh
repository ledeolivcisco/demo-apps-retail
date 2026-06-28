#!/usr/bin/env bash
# Grant anyuid SCC to wallmart workloads that cannot run under OpenShift restricted UID ranges.
#
# Usage (from repository root):
#   ./k8s/openshift/apply-scc.sh
#
# Env: HELM_NAMESPACE (default: wallmart)
set -euo pipefail

NAMESPACE="${HELM_NAMESPACE:-wallmart}"

if ! command -v oc >/dev/null 2>&1; then
  echo "oc CLI is required for OpenShift SCC binding." >&2
  exit 1
fi

if ! oc whoami >/dev/null 2>&1; then
  echo "Not logged in to OpenShift (oc login)." >&2
  exit 1
fi

bind_anyuid() {
  local sa="$1"
  if ! oc get serviceaccount "${sa}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo "Skip ${sa}: service account not found in ${NAMESPACE}"
    return 0
  fi
  echo "==> bind anyuid SCC to system:serviceaccount:${NAMESPACE}:${sa}"
  oc adm policy add-scc-to-user anyuid -z "${sa}" -n "${NAMESPACE}"
}

bind_anyuid wallmart-app
bind_anyuid sqlserver
bind_anyuid ecommerce-web
bind_anyuid playwright-loop

echo "Done. SCC bindings applied in namespace ${NAMESPACE}."
