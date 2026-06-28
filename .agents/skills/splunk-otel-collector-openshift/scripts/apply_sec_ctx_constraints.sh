#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export SPLUNK_OTEL_SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_env
NS="$(install_namespace)"

if oc get scc user-access &>/dev/null; then
  echo "SCC user-access already exists"
  exit 0
fi

cat <<EOF | oc create -f -
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: user-access
allowPrivilegedContainer: true
allowHostDirVolumePlugin: true
allowHostNetwork: true
allowHostPorts: true
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: RunAsAny
fsGroup:
  type: RunAsAny
users:
  - system:serviceaccount:${NS}:splunk-otel-collector
EOF

echo "Created SCC user-access for serviceaccount splunk-otel-collector in ${NS}"
