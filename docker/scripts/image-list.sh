#!/usr/bin/env bash
# Shared image catalog for build-all.sh, push-all.sh, and build-push-all.sh.
# Format per entry: <dockerfile-relative-to-repo-root>:<image-suffix>
WALLMART_IMAGES=(
  "docker/product-service/Dockerfile:product-service"
  "docker/cart-service/Dockerfile:cart-service"
  "docker/payment-service/Dockerfile:payment-service"
  "docker/web/Dockerfile:ecommerce-web"
  "docker/playwright-loop/Dockerfile:playwright-loop"
)

# Browser RUM is baked into ecommerce-web at build time; JVM backends are scenario-agnostic.
WALLMART_WEB_IMAGE="docker/web/Dockerfile:ecommerce-web"

# Map scenario alias → registry tag (appd | splunk).
wallmart_scenario_image_tag() {
  case "$1" in
    'appd' | 'appdynamics') echo appd ;;
    'splunk' | 'o11y') echo splunk ;;
    *)
      echo "Unknown observability scenario: $1 (use appd or splunk)" >&2
      return 1
      ;;
  esac
}

# Expected VITE_OBSERVABILITY_BACKEND in docker/.env for each scenario alias.
wallmart_scenario_vite_backend() {
  case "$1" in
    'appd' | 'appdynamics') echo appdynamics ;;
    'splunk' | 'o11y') echo splunk ;;
    *)
      return 1
      ;;
  esac
}
