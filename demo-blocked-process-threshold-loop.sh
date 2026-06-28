#!/usr/bin/env bash
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/docker-standalone/demo-blocked-process-threshold-loop.sh" "$@"
