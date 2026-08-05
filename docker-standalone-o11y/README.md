# Wallmart ecommerce — standalone Docker (Splunk Observability)

This directory is self-contained: copy it to a server, set `.env`, and run **no build** — only images from your registry (or images you have loaded locally).

This path uses the **Splunk Observability Cloud** stack:

- **Splunk OTel Java agent** v2.29.0 (sidecar seeds a shared JAR volume)
- **Splunk OTel Collector** v0.156.0 (OTLP gateway → Splunk APM)
- **Browser RUM** baked into the `ecommerce-web` image at build time (`VITE_OBSERVABILITY_BACKEND=splunk`)

For Kubernetes deployments, see [`o11y/`](../o11y/). For AppDynamics Docker, see [`docker-standalone/`](../docker-standalone/).

For full project documentation (architecture, local dev, image builds, tests, env reference), see the [root README](../README.md).

## Quick start

1. `cp .env.example .env` and set `SPLUNK_ACCESS_TOKEN`, `SPLUNK_REALM`, `MSSQL_SA_PASSWORD`, and registry if not `leandrovo`.
2. Ensure images exist locally or are pullable:
   `{REGISTRY_PREFIX}/product-service`, `cart-service`, `payment-service`, `appliance-service`, `ecommerce-web` at `{IMAGE_TAG}` (use `splunk` tag for RUM).
3. From this directory:

   ```bash
   docker compose up -d
   ```

4. Open the app at `http://<host>:${WEB_PORT:-8080}` — includes the **Appliances** shopping section (nginx proxies `/graphql` and `/addappliance` to `appliance-service`).

5. Verify collector from the host (distroless image has no in-container health probe): `curl -s http://localhost:13133/`

6. **Appliances GraphiQL** (optional, direct to the service): `http://<host>:${APPLIANCE_PORT:-8084}/graphiql?path=/graphql`.

7. Generate traffic and confirm traces in Splunk APM for `product-service`, `cart-service`, `payment-service`, and `appliance-service`.

## Observability stack

| Component | Image | Role |
|-----------|-------|------|
| `splunk-java-agent` | `ghcr.io/signalfx/splunk-otel-java/splunk-otel-java:v2.29.0` | Copies agent JAR into shared volume |
| `splunk-otel-collector` | `quay.io/signalfx/splunk-otel-collector:0.156.0` | Receives OTLP on `:4318`, exports traces to Splunk Observability Cloud |
| Java backends | pre-built registry images | `-javaagent` + OTLP to collector |

### Collector config

Pipeline behavior is defined in [`otel-collector-config.yaml`](otel-collector-config.yaml), mounted read-only into the collector. Credentials (`SPLUNK_ACCESS_TOKEN`, `SPLUNK_REALM`) and memory limit (`SPLUNK_MEMORY_LIMIT_MIB`) are passed via `.env` and referenced in the YAML as `${...}` placeholders.

To customize (e.g. add Jaeger/Zipkin receivers or metrics pipelines), edit `otel-collector-config.yaml` and restart the collector:

```bash
docker compose restart splunk-otel-collector
```

## Browser RUM

Standalone hosts do not rebuild the frontend. RUM is configured when the `ecommerce-web` image was built:

| Setting | Where to set (on build machine) |
|---------|--------------------------------|
| `VITE_OBSERVABILITY_BACKEND=splunk` | [`docker/.env`](../docker/.env) copied into web Dockerfile |
| `VITE_SPLUNK_RUM_*` | same |

Rebuild and push with the Splunk scenario tag:

```bash
./docker/scripts/build-push-scenario.sh splunk
# standalone hosts: IMAGE_TAG=splunk in .env
```

Guide: [Splunk RUM](../docs/instrument-react-splunk-rum-vite.md)

## Helper scripts

Run from this directory:

| Script | Purpose |
|--------|---------|
| [`up.sh`](up.sh) | `docker compose up -d` |
| [`up_load.sh`](up_load.sh) | Start stack + synthetic Playwright loop profile |
| [`down.sh`](down.sh) | Stop stack and remove playwright-loop container |
| [`ps.sh`](ps.sh) | Container status |
| [`logs.sh`](logs.sh) | Follow all service logs |
| [`logs_loop.sh`](logs_loop.sh) | Follow playwright-loop logs |
| [`demo-lock-loop.sh`](demo-lock-loop.sh) | Infinite HTTP inventory lock demo (chaos) |

## Optional synthetic monitoring

Build and push `playwright-loop` to `{REGISTRY_PREFIX}/playwright-loop:{IMAGE_TAG}`, then:

```bash
docker compose --profile synthetic up -d
```

## Tear down

```bash
docker compose down
```

If you used the synthetic profile, remove the named loop container when Compose leaves it in a bad state after network recreation:

```bash
docker rm -f wallmart-playwright-loop 2>/dev/null || true
```

## Offline / air-gapped hosts

Set `COMPOSE_PULL_POLICY=never` in `.env` and load images with `docker load` (or a private registry mirror) before `up`. Pre-pull:

- `ghcr.io/signalfx/splunk-otel-java/splunk-otel-java:v2.29.0`
- `quay.io/signalfx/splunk-otel-collector:0.156.0`
