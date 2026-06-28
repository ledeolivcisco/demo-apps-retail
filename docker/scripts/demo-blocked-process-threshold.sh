#!/usr/bin/env bash
# Enable or disable SQL Server blocked-process reporting for demo / chaos scenarios.
#
# Usage:
#   ./docker/scripts/demo-blocked-process-threshold.sh 10      # enable (5–300 seconds)
#   ./docker/scripts/demo-blocked-process-threshold.sh restore # disable (default)
#
# When enabled, SQL Server writes a blocked-process report to the error log when a session
# waits on a lock longer than the threshold. Pair with demo-lock-inventory.sh or the HTTP
# inventory lock endpoint to simulate blocking visible in Database Visibility.
#
# Requires:
#   - Running stack with container wallmart-sqlserver
#   - MSSQL_SA_PASSWORD in the environment, or in docker/.env / docker-standalone/.env
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ARG="${1:-restore}"
CONTAINER="${SQLSERVER_CONTAINER:-wallmart-sqlserver}"

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

if [[ "${ARG}" == "restore" ]]; then
  SECONDS=0
  echo "Disabling blocked process threshold on ${CONTAINER} ..."
else
  SECONDS="${ARG}"
  if ! [[ "${SECONDS}" =~ ^[0-9]+$ ]] || [[ "${SECONDS}" -lt 5 ]] || [[ "${SECONDS}" -gt 300 ]]; then
    echo "seconds must be an integer between 5 and 300, or 'restore' (got: ${ARG})" >&2
    exit 1
  fi
  echo "Setting blocked process threshold to ${SECONDS}s on ${CONTAINER} ..."
fi

CONFIG_SQL="
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'blocked process threshold', ${SECONDS};
RECONFIGURE;
SELECT name, value_in_use FROM sys.configurations WHERE name LIKE 'blocked process threshold%';
"

docker exec -i "${CONTAINER}" /opt/mssql-tools18/bin/sqlcmd \
  -S localhost \
  -U sa \
  -P "${MSSQL_SA_PASSWORD}" \
  -C \
  -Q "${CONFIG_SQL}"

if [[ "${SECONDS}" -eq 0 ]]; then
  echo "Blocked process threshold disabled."
else
  echo "Blocked process threshold set to ${SECONDS}s. Trigger an inventory lock to generate reports."
fi
