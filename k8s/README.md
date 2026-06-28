# Kubernetes deployment (Helm)

Deploy the FreshMart ecommerce demo with the [wallmart-ecommerce](wallmart-ecommerce/) Helm chart.

The base chart deploys the application only — **no AppDynamics agents** and **no Splunk collector**. For Splunk Observability (Java OTel + optional Browser RUM), see [Observability](#observability) below and [`o11y/README.md`](../o11y/README.md). Step-by-step build + deploy: [`docs/deploy-appd-and-o11y.md`](../docs/deploy-appd-and-o11y.md#splunk-o11y-kubernetes).

## Prerequisites

- Kubernetes 1.25+
- Helm 3
- Container images built and pushed (or loaded into kind/minikube)
- For in-cluster SQL Server: a node with `linux/amd64` (Apple Silicon clusters need amd64 emulation or an amd64 node pool)

## Build images

From the repository root:

```bash
# Splunk o11y: set VITE_OBSERVABILITY_BACKEND=splunk in docker/.env, then:
./docker/scripts/build-push-scenario.sh splunk
# or web only (JVM backends are scenario-agnostic):
./docker/scripts/build-push-scenario.sh splunk --web-only

# Deploy with matching tag:
REGISTRY_PREFIX=your-registry IMAGE_TAG=splunk ./k8s/install.sh

# Or backends on latest, web rebuilt with --web-only:
REGISTRY_PREFIX=your-registry IMAGE_TAG=latest ECOMMERCE_WEB_IMAGE_TAG=splunk ./k8s/install.sh
```

Generic build (any tag):

```bash
REGISTRY_PREFIX=your-registry IMAGE_TAG=latest ./docker/scripts/build-push-all.sh
```

**Rebuild workflow** (after code changes — chart uses `imagePullPolicy: Always`):

```bash
./docker/scripts/build-all.sh
# push to registry if cluster pulls remotely, or kind load for local clusters
kubectl rollout restart deployment -n wallmart product-service cart-service payment-service ecommerce-web
```

For local kind clusters, load images after building:

```bash
kind load docker-image your-registry/product-service:latest
kind load docker-image your-registry/cart-service:latest
kind load docker-image your-registry/payment-service:latest
kind load docker-image your-registry/ecommerce-web:latest
# optional synthetic loop:
kind load docker-image your-registry/playwright-loop:latest
```

**Splunk Browser RUM:** if using [`o11y/`](../o11y/), bake RUM into `ecommerce-web` at build time — set `VITE_OBSERVABILITY_BACKEND=splunk` and `VITE_SPLUNK_*` in [`docker/.env`](../docker/.env) before building the web image. See [Observability](#observability).

## Install

```bash
./k8s/install.sh
```

Uses `k8s/wallmart-ecommerce/values-local.yaml` when present; otherwise reads `MSSQL_SA_PASSWORD` and `REGISTRY_PREFIX` from the environment or `docker/.env` / `docker-standalone/.env`.

| Flag | Purpose |
|------|---------|
| `--local` | Require `values-local.yaml` |
| `--cloud` | Skip values file; LoadBalancer defaults + env password |
| `--synthetic` | Enable Playwright loop |
| `--dry-run` | `helm template` only (no cluster changes) |

Manual install:

```bash
helm upgrade --install wallmart ./k8s/wallmart-ecommerce \
  --namespace wallmart --create-namespace \
  --set global.imageRegistry=your-registry \
  --set global.imageTag=latest \
  --set ecommerceWeb.image.tag=splunk \
  --set mssql.password='YourStrong!Passw0rd'
```

`ecommerceWeb.image.tag` overrides `global.imageTag` for the storefront only (Browser RUM is baked at build time). JVM backends always use `global.imageTag`. All containers use `imagePullPolicy: Always`.

Enable the Playwright synthetic loop:

```bash
helm upgrade --install wallmart ./k8s/wallmart-ecommerce \
  --namespace wallmart --create-namespace \
  --set global.imageRegistry=your-registry \
  --set mssql.password='YourStrong!Passw0rd' \
  --set synthetic.enabled=true
```

### Local cluster (kind / minikube)

No cloud LoadBalancer — use ClusterIP and port-forward:

```bash
cp k8s/wallmart-ecommerce/values-local.example.yaml k8s/wallmart-ecommerce/values-local.yaml
# edit values-local.yaml — set mssql.password and image registry

helm upgrade --install wallmart ./k8s/wallmart-ecommerce \
  --namespace wallmart --create-namespace \
  -f k8s/wallmart-ecommerce/values-local.yaml

kubectl port-forward svc/ecommerce-web 8080:80 -n wallmart
```

Open http://localhost:8080

## Public access

By default `ecommerce-web` Service type is **LoadBalancer** (one external IP for the whole app). nginx inside the pod proxies API calls to internal ClusterIP services.

```bash
kubectl get svc ecommerce-web -n wallmart
```

| Service type | When to use |
|--------------|-------------|
| `LoadBalancer` | EKS, GKE, AKS (default) |
| `ClusterIP` | kind/minikube + port-forward |
| `NodePort` | bare-metal without cloud LB |

Override:

```bash
--set ecommerceWeb.service.type=ClusterIP
```

Ingress is **disabled** by default (`ingress.enabled: false`). Enable only if you already run an ingress controller:

```bash
--set ingress.enabled=true --set ingress.host=wallmart.example.com
```

## Secrets

The chart creates a Secret from `mssql.password` when `mssql.createSecret: true` (default).

Use a pre-created secret instead:

```bash
kubectl create secret generic mssql-credentials -n wallmart \
  --from-literal=MSSQL_SA_PASSWORD='YourStrong!Passw0rd' \
  --from-literal=WALLMART_DB_PASSWORD='YourStrong!Passw0rd'

helm upgrade --install wallmart ./k8s/wallmart-ecommerce \
  --set mssql.createSecret=false \
  --set mssql.existingSecret=mssql-credentials
```

Never commit real passwords to git.

## Observability

| Layer | Mechanism | Config |
|-------|-----------|--------|
| Java backends | Splunk OTel Java agent (operator) | [`o11y/`](../o11y/) after app deploy |
| Browser RUM | `@splunk/otel-web` in `ecommerce-web` | Build-time `VITE_OBSERVABILITY_BACKEND=splunk` |

**Recommended K8s + Splunk stack:**

```bash
# 1. Build web image with Splunk RUM (in docker/.env before build):
#    VITE_OBSERVABILITY_BACKEND=splunk
#    VITE_SPLUNK_REALM=us1
#    VITE_SPLUNK_RUM_ACCESS_TOKEN=<rum-token>

REGISTRY_PREFIX=your-registry ./docker/scripts/build-push-all.sh

# 2. Deploy app
./k8s/install.sh

# 3. Install Splunk OTel Collector + Java injection
cp o11y/.env.example o11y/.env   # SPLUNK_ACCESS_TOKEN, HEC, realm
./o11y/install.sh --with-redaction
./o11y/enable-java-instrumentation.sh
./o11y/verify.sh --java
```

Splunk RUM auto-instruments browser `fetch` calls and propagates trace context to OTel-instrumented Java services (end-to-end traces).

| Doc | Purpose |
|-----|---------|
| [`o11y/README.md`](../o11y/README.md) | Collector install, Java injection, PII redaction |
| [`docs/instrument-react-splunk-rum-vite.md`](../docs/instrument-react-splunk-rum-vite.md) | Browser RUM env vars and verification |

The Docker Compose path uses **AppDynamics** instead — see [root README](../README.md#observability).

## Verify

```bash
helm status wallmart -n wallmart
kubectl get pods -n wallmart
kubectl logs -n wallmart deploy/product-service -f
```

## Uninstall

```bash
./k8s/uninstall.sh
```

| Flag | Purpose |
|------|---------|
| `-y` / `--yes` | Skip confirmation |
| `--dry-run` | Show what would be removed |
| `--delete-pvc` | Also delete SQL Server PVCs (retained by default) |
| `--delete-namespace` | Delete the `wallmart` namespace after uninstall |

Full cleanup:

```bash
./k8s/uninstall.sh --delete-pvc --delete-namespace -y
```

Manual equivalent:

```bash
helm uninstall wallmart -n wallmart
```

SQL Server PVCs are retained unless `--delete-pvc` is used. Delete manually:

```bash
kubectl delete pvc -n wallmart -l app.kubernetes.io/name=sqlserver
```

## Lint / dry-run

```bash
helm lint k8s/wallmart-ecommerce
helm template wallmart k8s/wallmart-ecommerce \
  --set mssql.password='YourStrong!Passw0rd' | less
```

## Chart values reference

See [wallmart-ecommerce/values.yaml](wallmart-ecommerce/values.yaml) and [values-local.example.yaml](wallmart-ecommerce/values-local.example.yaml).
