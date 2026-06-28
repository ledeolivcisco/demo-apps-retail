#!/usr/bin/env bash
# Shared helpers for o11y/openshift scripts.

openshift_o11y_root() {
  if [[ -z "${O11Y_OPENSHIFT_ROOT:-}" ]]; then
    echo "error: O11Y_OPENSHIFT_ROOT is not set" >&2
    return 1
  fi
  echo "${O11Y_OPENSHIFT_ROOT}"
}

o11y_root() {
  if [[ -z "${O11Y_ROOT:-}" ]]; then
    echo "error: O11Y_ROOT is not set" >&2
    return 1
  fi
  echo "${O11Y_ROOT}"
}

load_env() {
  local root
  root="$(o11y_root)"
  if [[ -f "${root}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${root}/.env"
    set +a
  fi
}

collector_namespace() {
  echo "${COLLECTOR_NAMESPACE:-splunk-otel}"
}

collector_release() {
  echo "${COLLECTOR_RELEASE:-splunk-otel-collector}"
}

collector_service_account() {
  echo "${COLLECTOR_SERVICE_ACCOUNT:-splunk-otel-collector}"
}

ensure_namespace() {
  local ns="$1"
  if oc get namespace "$ns" &>/dev/null; then
    echo "namespace ${ns} already exists"
  else
    oc new-project "$ns"
  fi
}

validate_collector_secret() {
  local ns="$1"
  local name="$2"
  local key missing=()

  if ! oc get secret "${name}" -n "${ns}" &>/dev/null; then
    echo "error: secret ${name} not found in namespace ${ns}" >&2
    exit 1
  fi

  for key in splunk_observability_access_token splunk_platform_hec_token; do
    if [[ -z "$(oc get secret "${name}" -n "${ns}" -o "jsonpath={.data.${key}}" 2>/dev/null)" ]]; then
      missing+=("${key}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "error: secret ${name} in ${ns} is missing required keys: ${missing[*]}" >&2
    exit 1
  fi

  echo "secret ${name} in ${ns} has required Splunk token keys"
}
