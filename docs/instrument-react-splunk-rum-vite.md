# Instrument a React Web Application with Splunk Browser RUM (Vite)

This guide documents **Splunk Observability Cloud Browser RUM** for the **ecommerce-web** Vite + React 18 SPA using `@splunk/otel-web`, env-driven configuration, and **SPA route metrics** for React Router.

> **Companion guides:**
> - [AppDynamics Browser RUM (programmatic)](instrument-react-appdynamics-browser-rum-vite-programmatic.md)
> - [o11y/ README](../o11y/README.md) — Kubernetes Java auto-instrumentation (backends only)

## Requirements

| Requirement | Detail |
|---|---|
| Splunk Observability Cloud org | Access to the UI |
| RUM access token | **Settings → Access Tokens → RUM** (not the org ingest token used by `o11y/`) |
| Realm | e.g. `us1` (same as `SPLUNK_REALM` in `o11y/.env`) |
| npm package | `@splunk/otel-web` (Splunk Distribution of OpenTelemetry for Web) |
| SPA support | `spaMetrics: true` — route change timing for React Router |

## Backend switch

The app uses a single master switch — only one RUM backend loads per build:

```bash
VITE_OBSERVABILITY_BACKEND=splunk   # Splunk Browser RUM
VITE_OBSERVABILITY_BACKEND=appdynamics   # AppDynamics Browser RUM
VITE_OBSERVABILITY_BACKEND=none     # no RUM
```

Dispatcher: [`ecommerce-web/src/observability/initObservability.ts`](../ecommerce-web/src/observability/initObservability.ts)

## Environment variables

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `VITE_OBSERVABILITY_BACKEND` | recommended | legacy fallback | `splunk` \| `appdynamics` \| `none` |
| `VITE_SPLUNK_REALM` | yes (splunk) | — | Observability Cloud realm |
| `VITE_SPLUNK_RUM_ACCESS_TOKEN` | yes (splunk) | — | RUM ingest token |
| `VITE_SPLUNK_APPLICATION_NAME` | no | `ecommerce-web` | App name in Splunk RUM |
| `VITE_SPLUNK_DEPLOYMENT_ENVIRONMENT` | no | `dev` | Environment tag |
| `VITE_SPLUNK_SPA_METRICS` | no | enabled | Set `false` to disable SPA route metrics |

## Local development

```bash
cp ecommerce-web/.env.example ecommerce-web/.env.local
```

Edit `.env.local`:

```bash
VITE_OBSERVABILITY_BACKEND=splunk
VITE_SPLUNK_REALM=us1
VITE_SPLUNK_RUM_ACCESS_TOKEN=your-rum-token
VITE_SPLUNK_DEPLOYMENT_ENVIRONMENT=dev
```

```bash
cd ecommerce-web
npm run dev
```

Restart the dev server after changing env files.

## Docker Compose / production image

Set vars in `docker/.env` (copied to `.env.production` at web image build time):

```bash
VITE_OBSERVABILITY_BACKEND=splunk
VITE_SPLUNK_REALM=us1
VITE_SPLUNK_RUM_ACCESS_TOKEN=...
VITE_SPLUNK_APPLICATION_NAME=ecommerce-web
VITE_SPLUNK_DEPLOYMENT_ENVIRONMENT=dev
```

Rebuild the web image:

```bash
docker compose -f docker/docker-compose.yml build ecommerce-web
```

## Kubernetes + o11y/

The Splunk OTel Collector chart in [`o11y/`](../o11y/) instruments **Java backends** only. Browser RUM is configured at **web image build time** — bake `VITE_OBSERVABILITY_BACKEND=splunk` into the image before deploying with [`k8s/install.sh`](../k8s/install.sh).

Recommended pairing for end-to-end traces:

1. Build web image with `VITE_OBSERVABILITY_BACKEND=splunk`
2. Deploy app + `./o11y/install.sh`
3. Run `./o11y/enable-java-instrumentation.sh`

Splunk RUM auto-instruments `fetch`/XHR and propagates W3C `traceparent` to OTel-instrumented Java services.

## Verification

1. Open the app and browse `/`, `/cart`, `/payment`.
2. DevTools → Network: requests to `rum-ingest.{realm}.observability.splunkcloud.com`.
3. Splunk Observability Cloud → **RUM** → Sessions / Pages for `ecommerce-web`.
4. Confirm `adrum-latest.js` is **not** loaded when backend is `splunk`.

## Content Security Policy

If you add a strict CSP, allow:

- `script-src`: `cdn.observability.splunkcloud.com` (if loading via CDN; npm bundle may not need this)
- `connect-src`: `rum-ingest.{realm}.observability.splunkcloud.com`

## References

- [Install the Splunk RUM browser agent](https://help.splunk.com/en/splunk-observability-cloud/manage-data/instrument-front-end-applications/instrument-mobile-and-web-applications-for-splunk-rum/instrument-browser-applications-for-splunk-rum/install-the-splunk-rum-browser-agent)
- [Monitor single page applications](https://help.splunk.com/en/splunk-observability-cloud/monitor-end-user-experience/real-user-monitoring/monitor-single-page-applications)
- [@splunk/otel-web on npm](https://www.npmjs.com/package/@splunk/otel-web)
