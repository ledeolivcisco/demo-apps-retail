# syntax=docker/dockerfile:1
# Build context: repository root (WALLMART).
FROM node:20-alpine AS builder
WORKDIR /app
COPY ecommerce-web/package.json ecommerce-web/package-lock.json ./
# Harden against flaky registry connections during `docker compose build` (ETIMEDOUT).
RUN --mount=type=cache,target=/root/.npm \
    npm config set fetch-retries 10 \
    && npm config set fetch-retry-mintimeout 20000 \
    && npm config set fetch-retry-maxtimeout 120000 \
    && npm config set fetch-timeout 300000 \
    && npm ci
COPY ecommerce-web/ ./
# Local `ecommerce-web/.env` is excluded by .dockerignore. Vite loads `.env.production` when
# NODE_ENV=production, so monorepo docker/.env (same VITE_* keys you use for compose) drives the build.
COPY docker/.env .env.production
ENV NODE_ENV=production
RUN npm run build

FROM nginx:1.27-alpine
COPY docker/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
