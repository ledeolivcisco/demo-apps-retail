#!/usr/bin/env bash
# OBI prerequisites: SCC, namespace, OBI service account, and SCC binding — before Helm install.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export SPLUNK_OTEL_SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_env
NS="$(install_namespace)"
OBI_SA="$(obi_service_account)"
OBI_SCC="$(obi_scc_name)"

bash "${SCRIPT_DIR}/apply_obi_scc.sh"
ensure_namespace "$NS"

echo "Ensuring service account ${OBI_SA} exists in ${NS} (with Helm adoption metadata)..."
ensure_obi_service_account

echo "Binding SCC ${OBI_SCC} to serviceaccount ${OBI_SA} in ${NS}..."
oc adm policy add-scc-to-user "$OBI_SCC" -z "$OBI_SA" -n "$NS"

echo "OBI prerequisites ready (SCC, namespace, service account, SCC binding)."
