#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"
docker compose -f docker/docker-compose.yml down
docker rm -f wallmart-playwright-loop
