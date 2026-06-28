#!/usr/bin/env bash
# Enable SQL Server blocked-process threshold via product-service, wait, restore, repeat.
#
# Usage (from this directory or repo root via wrapper, stack running on localhost):
#   ./demo-blocked-process-threshold-loop.sh
#   ./demo-blocked-process-threshold-loop.sh 90 30   # active wait 90s, calm 30s
#
# Requires:
#   - product-service reachable (default http://localhost:8081)
#   - WALLMART_DEMO_CHAOS_ENABLED=true on product-service (see .env.example)
#
# Optional env (or set in .env next to this script):
#   PRODUCT_PORT                    host port for product-service (default 8081)
#   DEMO_THRESHOLD_SECONDS          sp_configure threshold value (default 10, range 5–300)
#   DEMO_ACTIVE_WAIT_SECONDS        seconds to keep threshold enabled (default 120)
#   DEMO_INACTIVE_WAIT_SECONDS      calm period between cycles (default 60)
#   DEMO_THRESHOLD_ACTIVATE_URL     override full activate URL
#   DEMO_THRESHOLD_RESTORE_URL      override full restore URL

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/.env"
  set +a
fi

PRODUCT_PORT="${PRODUCT_PORT:-8081}"
THRESHOLD_SECONDS="${DEMO_THRESHOLD_SECONDS:-10}"
ACTIVE_WAIT="${1:-${DEMO_ACTIVE_WAIT_SECONDS:-120}}"
INACTIVE_WAIT="${2:-${DEMO_INACTIVE_WAIT_SECONDS:-60}}"

ACTIVATE_URL="${DEMO_THRESHOLD_ACTIVATE_URL:-http://localhost:${PRODUCT_PORT}/internal/demo/db-config/blocked-process-threshold?seconds=${THRESHOLD_SECONDS}}"
RESTORE_URL="${DEMO_THRESHOLD_RESTORE_URL:-http://localhost:${PRODUCT_PORT}/internal/demo/db-config/blocked-process-threshold/restore}"

if ! [[ "${THRESHOLD_SECONDS}" =~ ^[0-9]+$ ]] || [[ "${THRESHOLD_SECONDS}" -lt 5 ]] || [[ "${THRESHOLD_SECONDS}" -gt 300 ]]; then
  echo "DEMO_THRESHOLD_SECONDS must be an integer between 5 and 300 (got: ${THRESHOLD_SECONDS})" >&2
  exit 1
fi

if ! [[ "${ACTIVE_WAIT}" =~ ^[0-9]+$ ]] || [[ "${ACTIVE_WAIT}" -lt 1 ]]; then
  echo "active wait must be a positive integer (got: ${ACTIVE_WAIT})" >&2
  exit 1
fi

if ! [[ "${INACTIVE_WAIT}" =~ ^[0-9]+$ ]] || [[ "${INACTIVE_WAIT}" -lt 0 ]]; then
  echo "inactive wait must be a non-negative integer (got: ${INACTIVE_WAIT})" >&2
  exit 1
fi

echo "demo-blocked-process-threshold-loop: threshold=${THRESHOLD_SECONDS}s active=${ACTIVE_WAIT}s inactive=${INACTIVE_WAIT}s"
echo "  activate: ${ACTIVATE_URL}"
echo "  restore:  ${RESTORE_URL}"
echo "Press Ctrl+C to stop."

while true; do
  echo "==== $(date -Iseconds) ACTIVATE blocked process threshold ===="
  if curl -sS -X POST "${ACTIVATE_URL}" -w "\nHTTP %{http_code}\n"; then
    echo "==== threshold enabled; waiting ${ACTIVE_WAIT}s ===="
  else
    echo "==== curl activate failed (is product-service up? is WALLMART_DEMO_CHAOS_ENABLED=true?) ====" >&2
  fi
  sleep "${ACTIVE_WAIT}"

  echo "==== $(date -Iseconds) RESTORE blocked process threshold ===="
  if curl -sS -X POST "${RESTORE_URL}" -w "\nHTTP %{http_code}\n"; then
    echo "==== threshold disabled; waiting ${INACTIVE_WAIT}s ===="
  else
    echo "==== curl restore failed ====" >&2
  fi
  sleep "${INACTIVE_WAIT}"
done
