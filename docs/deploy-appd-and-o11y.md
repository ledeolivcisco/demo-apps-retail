# Deploy runbook: AppDynamics and Splunk o11y

Short operator guide for building scenario-tagged images and starting the FreshMart demo with instrumentation. For architecture and full env reference, see the [root README](../README.md).

**Pick one path per environment — do not mix AppDynamics and Splunk on the same stack.**

| Path | Deploy | Image tag | Java APM | Browser RUM |
|------|--------|-----------|----------|-------------|
| **AppDynamics** | Docker Compose / [`docker-standalone/`](../docker-standalone/) | `appd` | AppD Java agent in compose | `VITE_OBSERVABILITY_BACKEND=appdynamics` |
| **Splunk o11y** | Kubernetes + [`o11y/`](../o11y/) | `splunk` | Splunk OTel operator injection | `VITE_OBSERVABILITY_BACKEND=splunk` |

**Image note:** JVM backend images (`product-service`, `cart-service`, `payment-service`) are identical for both scenarios. Only `ecommerce-web` differs — Browser RUM is baked at build time when [`docker/web/Dockerfile`](../docker/web/Dockerfile) copies [`docker/.env`](../docker/.env) as `.env.production`.

## Prerequisites

| Tool | AppDynamics path | Splunk o11y path |
|------|------------------|------------------|
| Docker + Buildx | Required | Required (build images) |
| `docker login` | Required to push | Required to push |
| AppDynamics Controller | Host, account, access key | — |
| Kubernetes + Helm 3 | — | Required |
| Splunk Observability | — | Org access token, realm, HEC ([`o11y/.env.example`](../o11y/.env.example)) |

---

## AppDynamics (Docker)

### 1. Configure

```bash
cp docker/.env.example docker/.env
```

Set at minimum:

```bash
APPDYNAMICS_CONTROLLER_HOST_NAME=your-controller.saas.appdynamics.com
APPDYNAMICS_AGENT_ACCOUNT_NAME=your-account
APPDYNAMICS_AGENT_ACCOUNT_ACCESS_KEY=your-access-key
VITE_OBSERVABILITY_BACKEND=appdynamics
```

Optional Browser RUM:

```bash
VITE_APPDYNAMICS_ENABLED=true
VITE_APPDYNAMICS_APP_KEY=your-eum-browser-key
```

When pulling pre-built images from a registry, also set `IMAGE_TAG=appd` and `REGISTRY_PREFIX=youruser`.

Full variable list: [`docker/.env.example`](../docker/.env.example).

### 2. Build images

From the repository root, after `docker login`:

```bash
REGISTRY_PREFIX=youruser ./docker/scripts/build-push-scenario.sh appd
```

This validates `VITE_OBSERVABILITY_BACKEND=appdynamics` and pushes:

- `youruser/product-service:appd`
- `youruser/cart-service:appd`
- `youruser/payment-service:appd`
- `youruser/ecommerce-web:appd`
- `youruser/playwright-loop:appd`

**Local only (no registry push):**

```bash
IMAGE_TAG=appd ./docker/scripts/build-all.sh
# or let compose build on start:
./docker/up.sh
```

### 3. Start the app

| Mode | Command | When |
|------|---------|------|
| Build on host | `./docker/up.sh` | Dev / single machine |
| Pull pre-built | `cd docker-standalone && cp .env.example .env && docker compose up -d` | Remote host, no compile |

Open [http://localhost:8080](http://localhost:8080) (or `${WEB_PORT}`).

For standalone hosts, set in `.env`:

```bash
REGISTRY_PREFIX=youruser
IMAGE_TAG=appd
```

### 4. Post-start verification

1. **Java APM** — In the AppDynamics Controller, confirm tiers `product-service`, `cart-service`, `payment-service` under application `wallmart-ecommerce`.
2. **Database Visibility** — Agent **`SQLDBSales`** registers automatically. Create a collector manually:
   - Type: **Microsoft SQL Server**
   - Agent: **`SQLDBSales`**
   - Host: **`sqlserver`**, port **`1433`**, user **`sa`**, password from `MSSQL_SA_PASSWORD`
   - If SSL errors occur, add connection property `sslProtocol=TLSv1.2`
3. **Browser RUM** (optional) — EUM sessions in the Controller after setting `VITE_APPDYNAMICS_APP_KEY` and rebuilding `ecommerce-web`.

Deeper RUM setup: [instrument-react-appdynamics-browser-rum-vite-programmatic.md](instrument-react-appdynamics-browser-rum-vite-programmatic.md).

---

## Splunk o11y (Kubernetes)

### 1. Configure build env

In [`docker/.env`](../docker/.env) (used when building `ecommerce-web`):

```bash
VITE_OBSERVABILITY_BACKEND=splunk
VITE_SPLUNK_REALM=us1                              # same realm as o11y/.env
VITE_SPLUNK_RUM_ACCESS_TOKEN=...                   # RUM token — NOT SPLUNK_ACCESS_TOKEN
VITE_SPLUNK_APPLICATION_NAME=ecommerce-web
VITE_SPLUNK_DEPLOYMENT_ENVIRONMENT=dev             # align with DEPLOYMENT_ENV in o11y/.env
```

### 2. Build images

```bash
REGISTRY_PREFIX=youruser ./docker/scripts/build-push-scenario.sh splunk
```

If JVM backends are already on the registry under another tag, rebuild web only:

```bash
REGISTRY_PREFIX=youruser ./docker/scripts/build-push-scenario.sh splunk --web-only
```

### 3. Configure o11y

```bash
cp o11y/.env.example o11y/.env
# Set SPLUNK_REALM, SPLUNK_ACCESS_TOKEN, SPLUNK_HEC_TOKEN, SPLUNK_HEC_ENDPOINT, CLUSTER_NAME
```

Never commit `o11y/.env` — tokens live in Kubernetes secret `splunk-otel-credentials`.

### 4. Deploy (order matters)

From the repository root:

```bash
REGISTRY_PREFIX=youruser IMAGE_TAG=splunk ./k8s/install.sh
./o11y/install.sh --with-redaction
./o11y/enable-java-instrumentation.sh
./o11y/verify.sh --java
```

### 5. Verify

| Signal | Where to check |
|--------|----------------|
| Java traces | Splunk Observability Cloud → APM → `product-service`, `cart-service`, `payment-service` |
| Browser RUM | RUM → sessions for `ecommerce-web` |
| RUM ingest | Browser DevTools → network to `rum-ingest.{realm}.observability.splunkcloud.com` |
| Java agent injection | `kubectl get pods -n wallmart` — initContainer `opentelemetry-auto-instrumentation-java` |

Deeper guides: [instrument-react-splunk-rum-vite.md](instrument-react-splunk-rum-vite.md) · [o11y/README.md](../o11y/README.md).

### OpenShift

Same tokens in [`o11y/.env`](../o11y/.env) (including HEC). From the repository root:

```bash
REGISTRY_PREFIX=youruser IMAGE_TAG=splunk ./k8s/install.sh
./o11y/openshift/install.sh --with-redaction
./o11y/enable-java-instrumentation.sh
./o11y/openshift/verify.sh --java
```

Details: [o11y/openshift/README.md](../o11y/openshift/README.md).

---

## Image tag cheat sheet

Example layout on Docker Hub:

```
youruser/product-service:appd      # same layers as :splunk
youruser/cart-service:appd
youruser/payment-service:appd
youruser/ecommerce-web:appd        # AppD Browser RUM baked in
youruser/ecommerce-web:splunk      # Splunk Browser RUM baked in
youruser/playwright-loop:appd
```

| Script | Purpose |
|--------|---------|
| [`build-push-scenario.sh`](../docker/scripts/build-push-scenario.sh) `appd` \| `splunk` | Build + push with validated scenario tag |
| [`build-push-scenario.sh`](../docker/scripts/build-push-scenario.sh) `--web-only` | Rebuild/push `ecommerce-web` only |
| [`build-web-only.sh`](../docker/scripts/build-web-only.sh) `--push` | Push web image with custom `IMAGE_TAG` |
| [`build-all.sh`](../docker/scripts/build-all.sh) | Local multi-arch load (any `IMAGE_TAG`) |
| [`build-push-all.sh`](../docker/scripts/build-push-all.sh) | Push all images with generic `IMAGE_TAG` |

Deploy with matching tag:

```bash
# Docker standalone / compose
IMAGE_TAG=appd

# Kubernetes — all images same tag
REGISTRY_PREFIX=youruser IMAGE_TAG=splunk ./k8s/install.sh

# Kubernetes — web-only rebuild (backends on latest, storefront on splunk/appd)
REGISTRY_PREFIX=youruser IMAGE_TAG=latest ECOMMERCE_WEB_IMAGE_TAG=splunk ./k8s/install.sh
```

Or via Helm values:

```yaml
global:
  imageTag: latest
ecommerceWeb:
  image:
    tag: splunk   # or appd
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Browser RUM missing | Rebuild `ecommerce-web` after changing any `VITE_*` var — RUM is not runtime-configurable |
| `build-push-scenario.sh` env mismatch | Set `VITE_OBSERVABILITY_BACKEND` to `appdynamics` (for `appd`) or `splunk` (for `splunk`) in `docker/.env` |
| AppD db-agent fails on Apple Silicon | DB agent image is `linux/amd64` — runs under emulation; JVM services can use native arm64 |
| Splunk Java agent not injected | Re-run `./o11y/enable-java-instrumentation.sh`; check `./o11y/verify.sh --java` (or `./o11y/openshift/verify.sh --java` on OpenShift) |
| Wrong images pulled on standalone host | Confirm `REGISTRY_PREFIX` and `IMAGE_TAG` match what you pushed |

## Related docs

| Doc | Topic |
|-----|-------|
| [README.md](../README.md) | Full architecture, env reference, local dev |
| [instrument-react-appdynamics-browser-rum-vite-programmatic.md](instrument-react-appdynamics-browser-rum-vite-programmatic.md) | AppD Browser RUM details |
| [instrument-react-splunk-rum-vite.md](instrument-react-splunk-rum-vite.md) | Splunk Browser RUM details |
| [o11y/README.md](../o11y/README.md) | Splunk OTel Collector, redaction, Java auto-instrumentation |
| [o11y/openshift/README.md](../o11y/openshift/README.md) | Splunk OTel Collector on OpenShift (SCC, HEC) |
| [k8s/README.md](../k8s/README.md) | Helm chart install options |
| [docker-standalone/README.md](../docker-standalone/README.md) | Pull-only AppD deployment |
