#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT}/.env"
  set +a
fi
NS="${INSTALL_NAMESPACE:-otel}"
helm delete splunk-otel-collector -n "${NS}"
oc delete scc user-access
rm -f helm_stdout.txt helm_stderr.txt
