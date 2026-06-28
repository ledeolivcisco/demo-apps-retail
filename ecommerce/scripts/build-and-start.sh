#!/usr/bin/env bash
# Build all modules, then start the three services in the background.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/build.sh"
"${SCRIPT_DIR}/start-all.sh"
