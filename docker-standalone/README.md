# Wallmart ecommerce — standalone Docker

This directory is self-contained: copy it to a server, set `.env`, and run **no build** — only images from your registry (or images you have loaded locally).

This path uses the **AppDynamics** observability stack (JVM agent, db-agent, machine-agent). Browser RUM is baked into the `ecommerce-web` image at build time — set `VITE_OBSERVABILITY_BACKEND=appdynamics` when building images (see [`docker/.env.example`](../docker/.env.example)). For **Splunk Observability**, deploy on Kubernetes with [`o11y/`](../o11y/) instead. Step-by-step build + deploy: [`docs/deploy-appd-and-o11y.md`](../docs/deploy-appd-and-o11y.md#appdynamics-docker).

For full project documentation (architecture, local dev, image builds, tests, env reference), see the [root README](../README.md).

## Quick start

1. `cp .env.example .env` and fill in AppDynamics controller/account values, `MSSQL_SA_PASSWORD`, and registry if not `leandrovo`.
2. Ensure images exist locally or are pullable:  
   `{REGISTRY_PREFIX}/product-service`, `cart-service`, `payment-service`, `ecommerce-web` at `{IMAGE_TAG}`.  
   AppDynamics agents (`appdynamics/db-agent:26.4.0-5606`, `java-agent`, `machine-agent`) are pulled from Docker Hub.
3. From this directory:

   ```bash
   docker compose up -d
   ```

4. Open the app at `http://<host>:${WEB_PORT:-8080}`.

5. In the AppDynamics Controller, create an **Microsoft SQL Server** collector on agent **`SQLDBSales`**: host **`sqlserver`**, port **1433**, user **`sa`**, password **`MSSQL_SA_PASSWORD`** from `.env`. See [root README](../README.md#post-deploy-sql-server-collector-database-visibility).

## Browser RUM

Standalone hosts do not rebuild the frontend. RUM is configured when the `ecommerce-web` image was built:

| Setting | Where to set (on build machine) |
|---------|--------------------------------|
| `VITE_OBSERVABILITY_BACKEND=appdynamics` | [`docker/.env`](../docker/.env) copied into web Dockerfile |
| `VITE_APPDYNAMICS_APP_KEY` | same |

Rebuild and push with the AppDynamics scenario tag:

```bash
./docker/scripts/build-push-scenario.sh appd
# standalone hosts: IMAGE_TAG=appd in .env
```

Guides: [AppDynamics RUM](../docs/instrument-react-appdynamics-browser-rum-vite-programmatic.md) · [Splunk RUM](../docs/instrument-react-splunk-rum-vite.md) (K8s path).

## Helper scripts

Run from this directory (`docker-standalone/`):

| Script | Purpose |
|--------|---------|
| [`up.sh`](up.sh) | `docker compose up -d` |
| [`up_load.sh`](up_load.sh) | Start stack + synthetic Playwright loop profile |
| [`down.sh`](down.sh) | Stop stack and remove playwright-loop container |
| [`ps.sh`](ps.sh) | Container status |
| [`logs.sh`](logs.sh) | Follow all service logs |
| [`logs_loop.sh`](logs_loop.sh) | Follow playwright-loop logs |
| [`logs_db_agent.sh`](logs_db_agent.sh) | Follow AppDynamics db-agent logs |
| [`logs_machine_agent.sh`](logs_machine_agent.sh) | Follow AppDynamics machine-agent logs |
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

Set `COMPOSE_PULL_POLICY=never` in `.env` and load images with `docker load` (or a private registry mirror) before `up`.
