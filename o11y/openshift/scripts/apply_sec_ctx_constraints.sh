#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export O11Y_OPENSHIFT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export O11Y_ROOT="$(cd "${O11Y_OPENSHIFT_ROOT}/.." && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_env
NS="$(collector_namespace)"
SA="$(collector_service_account)"

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
  - system:serviceaccount:${NS}:${SA}
EOF

echo "Created SCC user-access for serviceaccount ${SA} in ${NS}"
