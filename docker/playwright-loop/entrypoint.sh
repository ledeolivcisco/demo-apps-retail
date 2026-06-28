#!/usr/bin/env bash
# Infinite synthetic browser loop: run Playwright E2E, sleep, repeat.
# Optional env:
#   PLAYWRIGHT_BASE_URL              (default http://ecommerce-web — nginx on compose network)
#   PLAYWRIGHT_LOOP_INTERVAL_SECONDS pause between runs (default 30)
#   PLAYWRIGHT_WORKERS               concurrent workers (default 4)
#   PLAYWRIGHT_FULLY_PARALLEL        run tests in same file concurrently (default true)
#   PLAYWRIGHT_SYNTHETIC_PACE_MS     shorter pacing in loop (default 500)

set -uo pipefail

export PLAYWRIGHT_BASE_URL="${PLAYWRIGHT_BASE_URL:-http://ecommerce-web}"
INTERVAL="${PLAYWRIGHT_LOOP_INTERVAL_SECONDS:-30}"
WORKERS="${PLAYWRIGHT_WORKERS:-4}"
FULLY_PARALLEL="${PLAYWRIGHT_FULLY_PARALLEL:-true}"
PACE_MS="${PLAYWRIGHT_SYNTHETIC_PACE_MS:-500}"

export PLAYWRIGHT_WORKERS="${WORKERS}"
export PLAYWRIGHT_FULLY_PARALLEL="${FULLY_PARALLEL}"
export PLAYWRIGHT_SYNTHETIC_PACE_MS="${PACE_MS}"

echo "playwright-loop: baseURL=${PLAYWRIGHT_BASE_URL} interval=${INTERVAL}s workers=${WORKERS} fullyParallel=${FULLY_PARALLEL} paceMs=${PACE_MS}"

while true; do
  echo "==== $(date -Iseconds) playwright test start ===="
  if npx playwright test "$@"; then
    echo "==== $(date -Iseconds) playwright test PASSED ===="
  else
    echo "==== $(date -Iseconds) playwright test FAILED (exit $?) ===="
  fi
  sleep "${INTERVAL}"
done
