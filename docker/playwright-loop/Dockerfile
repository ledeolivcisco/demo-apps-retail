# syntax=docker/dockerfile:1
# Browser + Node match @playwright/test in ecommerce-web/package.json.
FROM mcr.microsoft.com/playwright:v1.49.1-jammy

WORKDIR /app

# Image already bundles Chromium for this Playwright build.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    CI=1

COPY ecommerce-web/package.json ecommerce-web/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm config set fetch-retries 10 \
    && npm config set fetch-retry-mintimeout 20000 \
    && npm config set fetch-retry-maxtimeout 120000 \
    && npm config set fetch-timeout 300000 \
    && npm ci

COPY ecommerce-web/playwright.config.ts ./
COPY ecommerce-web/e2e ./e2e

COPY docker/playwright-loop/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD []
