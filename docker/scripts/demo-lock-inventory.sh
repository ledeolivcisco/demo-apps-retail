#!/usr/bin/env bash
# Hold an exclusive lock on the inventory table for demo / chaos scenarios.
#
# Usage:
#   ./docker/scripts/demo-lock-inventory.sh [seconds] [mode]
#
#   seconds  Duration to hold the lock (default: 60, max: 300)
#   mode     table — exclusive table lock (TABLOCKX); blocks product search + checkout
#            row   — row lock on product_id '1' only (narrower blast radius)
#
# Requires:
#   - Running stack with container wallmart-sqlserver
#   - MSSQL_SA_PASSWORD in the environment, or in docker/.env / docker-standalone/.env
#
# Early release: find the blocking session and kill it, e.g.
#   docker exec -it wallmart-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q \
#     "SELECT session_id, status FROM sys.dm_exec_sessions WHERE program_name LIKE '%sqlcmd%'"
#   docker exec -it wallmart-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "KILL <session_id>"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SECONDS_ARG="${1:-60}"
MODE="${2:-table}"
CONTAINER="${SQLSERVER_CONTAINER:-wallmart-sqlserver}"
DB_NAME="${WALLMART_DB_NAME:-wallmart}"

if ! [[ "${SECONDS_ARG}" =~ ^[0-9]+$ ]] || [[ "${SECONDS_ARG}" -lt 1 ]] || [[ "${SECONDS_ARG}" -gt 300 ]]; then
  echo "seconds must be an integer between 1 and 300 (got: ${SECONDS_ARG})" >&2
  exit 1
fi

if [[ "${MODE}" != "table" && "${MODE}" != "row" ]]; then
  echo "mode must be 'table' or 'row' (got: ${MODE})" >&2
  exit 1
fi

if [[ -z "${MSSQL_SA_PASSWORD:-}" ]]; then
  for candidate in "${ROOT}/docker/.env" "${ROOT}/docker-standalone/.env"; do
    if [[ -f "${candidate}" ]]; then
      # shellcheck disable=SC1090
      set -a
      source "${candidate}"
      set +a
      break
    fi
  done
fi

if [[ -z "${MSSQL_SA_PASSWORD:-}" ]]; then
  echo "Set MSSQL_SA_PASSWORD or create docker/.env from docker/.env.example" >&2
  exit 1
fi

hours=$((SECONDS_ARG / 3600))
minutes=$(((SECONDS_ARG % 3600) / 60))
secs=$((SECONDS_ARG % 60))
DELAY=$(printf '%02d:%02d:%02d' "${hours}" "${minutes}" "${secs}")

if [[ "${MODE}" == "table" ]]; then
  LOCK_SQL="BEGIN TRAN;
UPDATE inventory WITH (TABLOCKX) SET stock = stock;
WAITFOR DELAY '${DELAY}';
ROLLBACK TRAN;"
else
  LOCK_SQL="BEGIN TRAN;
SELECT stock FROM inventory WITH (UPDLOCK, HOLDLOCK) WHERE product_id = '1';
WAITFOR DELAY '${DELAY}';
ROLLBACK TRAN;"
fi

echo "Holding inventory ${MODE} lock for ${SECONDS_ARG}s on ${CONTAINER}/${DB_NAME} ..."
echo "Product search and checkout may block until the lock is released."

docker exec -i "${CONTAINER}" /opt/mssql-tools18/bin/sqlcmd \
  -S localhost \
  -U sa \
  -P "${MSSQL_SA_PASSWORD}" \
  -C \
  -d "${DB_NAME}" \
  -Q "${LOCK_SQL}"

echo "Lock released (transaction rolled back)."
