#!/usr/bin/env bash
# Shared helpers for splunk-otel-collector-openshift scripts.

# Set SPLUNK_OTEL_SKILL_ROOT in the calling script before sourcing lib.sh (see install_o11y_oc.sh).

skill_root() {
  if [[ -z "${SPLUNK_OTEL_SKILL_ROOT:-}" ]]; then
    echo "error: SPLUNK_OTEL_SKILL_ROOT is not set; export it before sourcing lib.sh" >&2
    return 1
  fi
  echo "${SPLUNK_OTEL_SKILL_ROOT}"
}

load_env() {
  local root
  root="$(skill_root)"
  if [[ -f "${root}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${root}/.env"
    set +a
  fi
}

install_namespace() {
  echo "${INSTALL_NAMESPACE:-otel}"
}

obi_service_account() {
  echo "${OBI_SERVICE_ACCOUNT:-splunk-otel-collector-obi}"
}

obi_scc_name() {
  echo "${OBI_SCC_NAME:-splunk-otel-obi-scc}"
}

helm_release_name() {
  echo "${HELM_RELEASE_NAME:-splunk-otel-collector}"
}

# Pre-create the OBI SA with Helm ownership metadata so `helm upgrade --install` can adopt it.
ensure_obi_service_account() {
  local ns sa release
  ns="$(install_namespace)"
  sa="$(obi_service_account)"
  release="$(helm_release_name)"

  cat <<EOF | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${sa}
  namespace: ${ns}
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: ${release}
    meta.helm.sh/release-namespace: ${ns}
EOF
}

values_file() {
  local root
  root="$(skill_root)"
  echo "${root}/values.yaml"
}

# Returns 0 when values.yaml has obi.enabled: true under the top-level obi: key.
obi_enabled_in_values() {
  local vf
  vf="$(values_file)"
  [[ -f "$vf" ]] || return 1
  awk '
    /^obi:/ { in_obi=1 }
    in_obi && /^[a-zA-Z0-9_.-]+:/ && !/^obi:/ && !/^  / { in_obi=0 }
    in_obi && /^  enabled:/ {
      gsub(/#.*/, "", $0)
      if ($2 == "true") { found=1 }
    }
    END { exit found ? 0 : 1 }
  ' "$vf"
}

ensure_namespace() {
  local ns="$1"
  if oc get namespace "$ns" &>/dev/null; then
    echo "namespace ${ns} already exists"
  else
    oc new-project "$ns"
  fi
}
