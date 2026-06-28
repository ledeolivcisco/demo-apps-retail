#!/usr/bin/env bash
# Stop services started by start-all.sh (uses logs/*.pid under ecommerce/).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ECOMMERCE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ECOMMERCE_ROOT}"

for module in product-service cart-service payment-service; do
  pidfile="logs/${module}.pid"
  if [[ ! -f "${pidfile}" ]]; then
    echo "No PID file for ${module} (${pidfile}); skipping."
    continue
  fi
  pid="$(cat "${pidfile}")"
  if kill -0 "${pid}" 2>/dev/null; then
    echo "Stopping ${module} (PID ${pid}) ..."
    kill "${pid}" || true
    sleep 0.5
    if kill -0 "${pid}" 2>/dev/null; then
      echo "Process ${pid} still running; sending SIGKILL."
      kill -9 "${pid}" || true
    fi
  else
    echo "${module} PID ${pid} not running; removing stale pid file."
  fi
  rm -f "${pidfile}"
done
echo "Stop complete."
