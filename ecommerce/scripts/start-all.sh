#!/usr/bin/env bash
# Start product (8081), cart (8082), and payment (8083) services in the background.
# Requires a prior successful build (see build.sh). Override VERSION if your POMs differ.
#
# SQL Server must be reachable (defaults: localhost:1433, database wallmart, user sa).
# Start only the database from the repo root, e.g.:
#   docker compose -f docker/docker-compose.yml up -d sqlserver
# Set WALLMART_DB_* / MSSQL_SA_PASSWORD in the environment if not using defaults.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ECOMMERCE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION="${VERSION:-1.0.0-SNAPSHOT}"

cd "${ECOMMERCE_ROOT}"
mkdir -p logs

start_one() {
  local module="$1"
  local port="$2"
  local jar="${ECOMMERCE_ROOT}/${module}/target/${module}-${VERSION}.jar"
  local pidfile="logs/${module}.pid"
  local logfile="logs/${module}.log"

  if [[ ! -f "${jar}" ]]; then
    echo "Missing JAR: ${jar}" >&2
    echo "Run: ${SCRIPT_DIR}/build.sh" >&2
    exit 1
  fi

  if [[ -f "${pidfile}" ]] && kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
    echo "${module} already running (PID $(cat "${pidfile}")). Stop it first: ${SCRIPT_DIR}/stop-all.sh" >&2
    exit 1
  fi

  nohup java -jar "${jar}" >>"${logfile}" 2>&1 &
  echo $! >"${pidfile}"
  echo "Started ${module} PID $(cat "${pidfile}") — http://localhost:${port} — log: ${logfile}"
}

start_one product-service 8081
start_one cart-service 8082
start_one payment-service 8083
echo "All three services are running."
