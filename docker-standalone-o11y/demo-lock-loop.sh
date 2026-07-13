#!/usr/bin/env bash
# Trigger product-service inventory demo lock in an infinite loop (HTTP chaos scenario).
#
# Usage (from this directory, stack running on localhost):
#   ./demo-lock-loop.sh
#
# Requires:
#   - product-service reachable (default http://localhost:8081)
#   - WALLMART_DEMO_CHAOS_ENABLED=true on product-service (see .env.example)
#
# Optional env (or set in .env next to this script):
#   PRODUCT_PORT              host port for product-service (default 8081)
#   DEMO_LOCK_SECONDS         lock duration query param (default 60)
#   DEMO_LOCK_INTERVAL_SECONDS sleep between requests (default 60)
#   DEMO_LOCK_URL             override full URL if needed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/.env"
  set +a
fi

PRODUCT_PORT="${PRODUCT_PORT:-8081}"
LOCK_SECONDS="${DEMO_LOCK_SECONDS:-60}"
INTERVAL="${DEMO_LOCK_INTERVAL_SECONDS:-60}"
URL="${DEMO_LOCK_URL:-http://localhost:${PRODUCT_PORT}/internal/demo/db-lock/inventory?seconds=${LOCK_SECONDS}}"

echo "demo-lock-loop: url=${URL} interval=${INTERVAL}s"
echo "Press Ctrl+C to stop."

while true; do
  echo "==== $(date -Iseconds) POST inventory demo lock ===="
  if curl -sS -X POST "${URL}" -w "\nHTTP %{http_code}\n"; then
    echo "==== request sent ===="
  else
    echo "==== curl failed (is product-service up? is WALLMART_DEMO_CHAOS_ENABLED=true?) ====" >&2
  fi
  sleep "${INTERVAL}"
done
