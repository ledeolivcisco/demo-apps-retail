#!/usr/bin/env bash
# Build all ecommerce Spring Boot modules (aggregator + three services).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ECOMMERCE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ECOMMERCE_ROOT}"
echo "Building ecommerce modules from ${ECOMMERCE_ROOT} ..."
mvn clean package
echo "Build finished. Executable JARs are under each module's target/ directory."
