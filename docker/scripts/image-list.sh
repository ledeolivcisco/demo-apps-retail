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
