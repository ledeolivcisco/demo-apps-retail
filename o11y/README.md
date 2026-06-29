# Splunk OpenTelemetry Collector (o11y)

Install the [Splunk Distribution of the OpenTelemetry Collector](https://github.com/signalfx/splunk-otel-collector-chart) to monitor the Kubernetes cluster and auto-instrument the FreshMart Java backends.

**Use with:** Kubernetes app deploy ([`k8s/`](../k8s/)) — not Docker Compose (Docker uses AppDynamics).

| Platform | Install path |
|----------|--------------|
| Generic Kubernetes (kind, minikube, Docker Desktop) | [`install.sh`](install.sh) + [`values.example.yaml`](values.example.yaml) |
| OpenShift | [`openshift/install.sh`](openshift/install.sh) + [`openshift/values.example.yaml`](openshift/values.example.yaml) — see [openshift/README.md](openshift/README.md) |

**Destinations:**
- Splunk Observability Cloud — metrics, traces, Kubernetes cluster metrics
- Splunk Platform HEC — container logs

## Stack overview

| Component | Instrumentation | Config location |
|-----------|-----------------|-----------------|
| `product-service`, `cart-service`, `payment-service` | Splunk OTel Java agent (operator) | `o11y/` scripts + annotations |
| `ecommerce-web` (React) | Splunk Browser RUM (`@splunk/otel-web`) | Build-time `VITE_*` in web image — see [Browser RUM](#browser-rum-ecommerce-web) |
| Cluster / container logs | Splunk OTel Collector | `o11y/install.sh` |

## Prerequisites

- Kubernetes 1.25+ or OpenShift 4.x, Helm 3, kubectl (or `oc` for OpenShift)
- FreshMart app deployed in namespace `wallmart` ([k8s/install.sh](../k8s/install.sh))
- Splunk Observability Cloud org access token and realm
- Splunk Platform HEC token and endpoint

## Quick start

```bash
cp o11y/.env.example o11y/.env
# Edit o11y/.env — set SPLUNK_* tokens, CLUSTER_NAME, HEC endpoint

# Optional local overrides (e.g. insecureSkipVerify for lab HEC)
cp o11y/values-local.example.yaml o11y/values-local.yaml

./k8s/install.sh
./o11y/install.sh --with-redaction
./o11y/enable-java-instrumentation.sh
./o11y/verify.sh --java
```

## Scripts

| Script | Purpose |
|--------|---------|
| [install.sh](install.sh) | Add Helm repo, create credentials secret, install collector + operator (generic K8s) |
| [openshift/install.sh](openshift/install.sh) | Same for OpenShift (SCC + HEC + `oc`) |
| [uninstall.sh](uninstall.sh) | Remove Helm release; optional `--delete-secret`, `--delete-namespace` |
| [openshift/uninstall.sh](openshift/uninstall.sh) | OpenShift uninstall (`oc`) |
| [verify.sh](verify.sh) | Check agent, cluster receiver, operator, webhooks, Instrumentation CR |
| [openshift/verify.sh](openshift/verify.sh) | OpenShift checks including HEC secret and log collection |
| [enable-java-instrumentation.sh](enable-java-instrumentation.sh) | Annotate Java deployments for zero-code injection |

`install.sh` flags: `--dry-run`, `--with-redaction` (layers [values-redaction.example.yaml](values-redaction.example.yaml)).

## Configuration

| File | Purpose |
|------|---------|
| [.env.example](.env.example) | Splunk tokens, realm, HEC endpoint, cluster name |
| [values.example.yaml](values.example.yaml) | Collector, operator, logs, Obs + HEC settings |
| [values-local.example.yaml](values-local.example.yaml) | Local cluster overrides (copy to `values-local.yaml`) |
| [values-redaction.example.yaml](values-redaction.example.yaml) | Documented redaction processor overlay (credit card / SSN) |

Tokens are stored in Kubernetes secret `splunk-otel-credentials` — never commit `o11y/.env`.

## Java auto-instrumentation

The operator injects the Splunk OTel Java agent via initContainer when this annotation is present on the pod template:

```yaml
instrumentation.opentelemetry.io/inject-java: "splunk-otel/splunk-otel-collector"
```

[enable-java-instrumentation.sh](enable-java-instrumentation.sh) patches `product-service`, `cart-service`, and `payment-service` in `wallmart` and restarts them.

After injection, each Java pod should show:
- initContainer `opentelemetry-auto-instrumentation-java`
- `OTEL_SERVICE_NAME`, `JAVA_TOOL_OPTIONS` with `-javaagent:...`

## Sensitive-data redaction

See [values-redaction.example.yaml](values-redaction.example.yaml) for a fully commented example of how redaction is configured.

Based on the [Splunk Observability sensitive-data workshop](https://splunk.github.io/observability-workshop/en/ninja-workshops/foundations/3-opentelemetry-collector-workshops/2-advanced-collector/4-sensitive-data/).

The `payment-service` logs simulated fake credit card numbers and SSNs on checkout (`event=payment.confirmed`). The `redaction/pii` processor masks:

- Visa, MasterCard, and American Express patterns (Amex: 34/37 prefix, 15 digits)
- US SSN pattern (`XXX-XX-XXXX`, matches demo `900-XX-XXXX` values)

Enable at install or upgrade an existing release:

```bash
./o11y/install.sh --with-redaction
```

### How it works

1. **Define processor** — `agent.config.processors.redaction/pii` with `blocked_values` regex list
2. **Wire pipelines** — add `redaction/pii` to `logs` and `traces` processor chains before export
3. **Full pipeline required** — overriding `service.pipelines.logs.processors` replaces the chart default list entirely

```
payment-service stdout → agent logs pipeline → redaction/pii → HEC
```

### Validation

1. Generate traffic (Playwright synthetic loop or manual checkout).
2. **Raw pod logs** still contain fake PII:
   ```bash
   kubectl logs -n wallmart deploy/payment-service | grep creditCardNumber
   ```
3. **HEC / Splunk** search for `payment.confirmed` — `creditCardNumber=` and `ssn=` values should appear masked (`****`).
4. After validation, set `summary: info` or `summary: silent` in [values-redaction.example.yaml](values-redaction.example.yaml).

## Uninstall

```bash
./o11y/uninstall.sh --delete-secret --delete-namespace -y
```

Operator CRDs are cluster-scoped and retained by default.

## Browser RUM (ecommerce-web)

Java auto-instrumentation above does **not** cover the React frontend. Pair Splunk RUM with this stack for browser sessions, Web Vitals, and end-to-end traces (browser `fetch` → OTel Java backends).

### 1. Build web image with Splunk RUM

Set in [`docker/.env`](../docker/.env) before building `ecommerce-web`:

```bash
VITE_OBSERVABILITY_BACKEND=splunk
VITE_SPLUNK_REALM=us1                              # same realm as SPLUNK_REALM below
VITE_SPLUNK_RUM_ACCESS_TOKEN=...                   # RUM token — NOT SPLUNK_ACCESS_TOKEN
VITE_SPLUNK_APPLICATION_NAME=ecommerce-web
VITE_SPLUNK_DEPLOYMENT_ENVIRONMENT=dev             # align with DEPLOYMENT_ENV
```

```bash
docker compose -f docker/docker-compose.yml build ecommerce-web
# or push with scenario tag:
./docker/scripts/build-push-scenario.sh splunk --web-only
# then: REGISTRY_PREFIX=youruser IMAGE_TAG=splunk ./k8s/install.sh
```

### 2. Deploy app + o11y (order)

```bash
./k8s/install.sh
./o11y/install.sh --with-redaction
./o11y/enable-java-instrumentation.sh
```

### 3. Verify

- Splunk Observability Cloud → **RUM** → sessions for `ecommerce-web`
- DevTools → network to `rum-ingest.{realm}.observability.splunkcloud.com`
- Traces linking browser to Java services after checkout flows

Full guide: [docs/instrument-react-splunk-rum-vite.md](../docs/instrument-react-splunk-rum-vite.md). AppDynamics Browser RUM (Docker path): [docs/instrument-react-appdynamics-browser-rum-vite-programmatic.md](../docs/instrument-react-appdynamics-browser-rum-vite-programmatic.md).

## Related docs

- [Splunk auto-instrumentation install](https://github.com/signalfx/splunk-otel-collector-chart/blob/main/docs/auto-instrumentation-install.md)
- [Advanced collector configuration](https://help.splunk.com/en/splunk-observability-cloud/manage-data/splunk-distribution-of-the-opentelemetry-collector/get-started-with-the-splunk-distribution-of-the-opentelemetry-collector/collector-for-kubernetes/advanced-configuration)
- [Redaction processor](https://help.splunk.com/en/splunk-observability-cloud/manage-data/manage-sensitive-data/sanitize-data-with-opentelemetry-collector-processors/redaction-processor)
