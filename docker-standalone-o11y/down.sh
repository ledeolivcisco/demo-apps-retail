#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
docker compose down
docker rm -f wallmart-playwright-loop 2>/dev/null || true
