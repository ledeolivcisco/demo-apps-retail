#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export SPLUNK_OTEL_SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

OBI_SCC="$(obi_scc_name)"

if oc get scc "$OBI_SCC" &>/dev/null; then
  echo "SCC ${OBI_SCC} already exists"
  exit 0
fi

cat <<EOF | oc create -f -
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: ${OBI_SCC}
allowPrivilegedContainer: true
allowHostPID: true
allowHostDirVolumePlugin: true
allowHostNetwork: true
allowHostPorts: true
allowPrivilegeEscalation: true
readOnlyRootFilesystem: false
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: RunAsAny
fsGroup:
  type: RunAsAny
supplementalGroups:
  type: RunAsAny
volumes:
  - configMap
  - emptyDir
  - hostPath
  - secret
  - projected
allowedCapabilities:
  - BPF
  - PERFMON
  - SYS_PTRACE
  - DAC_READ_SEARCH
  - NET_ADMIN
  - NET_RAW
  - CHECKPOINT_RESTORE
  - SYS_ADMIN
users: []
EOF

echo "Created SCC ${OBI_SCC}"
