#!/usr/bin/env bash
# Uninstall Splunk OpenTelemetry Collector from OpenShift.
#
# Usage (from repository root):
#   ./o11y/openshift/uninstall.sh
#   ./o11y/openshift/uninstall.sh -y
#   ./o11y/openshift/uninstall.sh --delete-secret -y
#   ./o11y/openshift/uninstall.sh --delete-namespace -y
#   ./o11y/openshift/uninstall.sh --dry-run
#
# Does not remove cluster-scoped SCC user-access (see openshift/README.md).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export O11Y_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${O11Y_ROOT}/.env"
SECRET_NAME="splunk-otel-credentials"

RELEASE="${COLLECTOR_RELEASE:-splunk-otel-collector}"
NAMESPACE="${COLLECTOR_NAMESPACE:-splunk-otel}"

ASSUME_YES=false
DRY_RUN=false
DELETE_SECRET=false
DELETE_NAMESPACE=false

usage() {
  sed -n '2,11p' "$0" | sed 's/^# \?//'
}

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "${ENV_FILE}"
  set +a
  RELEASE="${COLLECTOR_RELEASE:-${RELEASE}}"
  NAMESPACE="${COLLECTOR_NAMESPACE:-${NAMESPACE}}"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      ASSUME_YES=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --delete-secret)
      DELETE_SECRET=true
      shift
      ;;
    --delete-namespace)
      DELETE_NAMESPACE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v helm >/dev/null 2>&1; then
  echo "helm is required but not installed (Helm 3)." >&2
  exit 1
fi

release_exists=false
if helm status "${RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  release_exists=true
fi

secret_exists=false
namespace_exists=false
if command -v oc >/dev/null 2>&1; then
  if oc get secret "${SECRET_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    secret_exists=true
  fi
  if oc get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    namespace_exists=true
  fi
fi

echo "Release:   ${RELEASE}"
echo "Namespace: ${NAMESPACE}"
echo

if [[ "${release_exists}" == true ]]; then
  echo "Will uninstall Helm release: ${RELEASE}"
else
  echo "Helm release not found (skipped): ${RELEASE} in ${NAMESPACE}"
fi

if [[ "${DELETE_SECRET}" == true ]]; then
  if [[ "${secret_exists}" == true ]]; then
    echo "Will delete secret: ${SECRET_NAME}"
  else
    echo "Secret not found (skipped): ${SECRET_NAME}"
  fi
fi

if [[ "${DELETE_NAMESPACE}" == true ]]; then
  if [[ "${namespace_exists}" == true ]]; then
    echo "Will delete namespace: ${NAMESPACE}"
  else
    echo "Namespace not found (skipped): ${NAMESPACE}"
  fi
fi

has_work=false
if [[ "${release_exists}" == true ]]; then
  has_work=true
fi
if [[ "${DELETE_SECRET}" == true && "${secret_exists}" == true ]]; then
  has_work=true
fi
if [[ "${DELETE_NAMESPACE}" == true && "${namespace_exists}" == true ]]; then
  has_work=true
fi

if [[ "${has_work}" == false ]]; then
  echo
  echo "Nothing to uninstall or delete."
  exit 0
fi

if [[ "${DRY_RUN}" == true ]]; then
  echo
  echo "Dry run — no changes made."
  exit 0
fi

if [[ "${ASSUME_YES}" != true ]]; then
  echo
  read -r -p "Proceed? [y/N] " reply
  if [[ ! "${reply}" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

if [[ "${release_exists}" == true ]]; then
  echo "==> helm uninstall ${RELEASE} -n ${NAMESPACE}"
  helm uninstall "${RELEASE}" -n "${NAMESPACE}"
fi

if [[ "${DELETE_SECRET}" == true && "${secret_exists}" == true ]]; then
  if ! command -v oc >/dev/null 2>&1; then
    echo "oc is required for --delete-secret." >&2
    exit 1
  fi
  echo "==> oc delete secret ${SECRET_NAME} -n ${NAMESPACE}"
  oc delete secret "${SECRET_NAME}" -n "${NAMESPACE}"
fi

if [[ "${DELETE_NAMESPACE}" == true && "${namespace_exists}" == true ]]; then
  if ! command -v oc >/dev/null 2>&1; then
    echo "oc is required for --delete-namespace." >&2
    exit 1
  fi
  echo "==> oc delete namespace ${NAMESPACE}"
  oc delete namespace "${NAMESPACE}"
fi

echo
echo "Done. SCC user-access was not removed (cluster-scoped)."
