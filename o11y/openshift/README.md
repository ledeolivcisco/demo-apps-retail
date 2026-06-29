# Splunk OpenTelemetry Collector on OpenShift

OpenShift-specific install for the [Splunk OTel Collector](https://github.com/signalfx/splunk-otel-collector-chart) with **HEC log export**, Java operator auto-instrumentation, and optional PII redaction for the FreshMart demo.

Use with the app deployed in namespace `wallmart` ([`k8s/`](../k8s/)).

**For vanilla Kubernetes** (kind, minikube, Docker Desktop), use [`../install.sh`](../install.sh) instead.

## Destinations

| Signal | Destination |
|--------|-------------|
| Metrics, traces, K8s cluster metrics | Splunk Observability Cloud |
| Container logs | Splunk Platform HEC |
| Java backends | Splunk OTel Java agent (operator injection) |

## Prerequisites

- OpenShift 4.x, `oc` CLI (logged in), Helm 3
- Cluster-admin (or equivalent) to create SCC `user-access`
- FreshMart app in `wallmart` ([`k8s/install.sh`](../../k8s/install.sh))
- [`o11y/.env`](../.env) with Observability **and** HEC tokens

## Quick start

```bash
cp o11y/.env.example o11y/.env
# Set SPLUNK_ACCESS_TOKEN, SPLUNK_HEC_TOKEN, SPLUNK_HEC_ENDPOINT, CLUSTER_NAME, etc.

# Optional lab overrides (HEC TLS, tolerations)
cp o11y/openshift/values-local.example.yaml o11y/openshift/values-local.yaml

REGISTRY_PREFIX=youruser IMAGE_TAG=splunk ./k8s/install.sh
./o11y/openshift/install.sh --with-redaction
./o11y/enable-java-instrumentation.sh
./o11y/openshift/verify.sh --java
```

## Scripts

| Script | Purpose |
|--------|---------|
| [install.sh](install.sh) | SCC → secret → Helm install (`--with-redaction`, `--dry-run`) |
| [verify.sh](verify.sh) | OpenShift + HEC checks; `--java` for wallmart injection |
| [uninstall.sh](uninstall.sh) | Remove Helm release; optional `--delete-secret`, `--delete-namespace` |
| [scripts/apply_sec_ctx_constraints.sh](scripts/apply_sec_ctx_constraints.sh) | Create `user-access` SCC for collector agent |

Shared with generic K8s path: [enable-java-instrumentation.sh](../enable-java-instrumentation.sh).

## Configuration

| File | Purpose |
|------|---------|
| [values.example.yaml](values.example.yaml) | OpenShift distribution, SCC, HEC/logs, kubelet TLS, probe span filter |
| [values-local.example.yaml](values-local.example.yaml) | Lab HEC `insecureSkipVerify`, tolerations |
| [values-redaction.example.yaml](values-redaction.example.yaml) | PII redaction before HEC export |
| [../.env.example](../.env.example) | Tokens, realm, HEC endpoint, namespaces |

## HEC log flow

```
wallmart pod stdout → agent filelog → logs pipeline → [redaction/pii] → splunk_hec → Splunk Platform
```

`install.sh` creates secret `splunk-otel-credentials` with:

- `splunk_observability_access_token`
- `splunk_platform_hec_token`

Helm sets `splunkPlatform.endpoint` and `splunkPlatform.index` from `o11y/.env`.

### Redaction validation

1. Run checkout traffic.
2. Raw pod logs still show fake PII:
   ```bash
   oc logs -n wallmart deploy/payment-service | grep creditCardNumber
   ```
3. In Splunk, search `payment.confirmed` — `creditCardNumber`, `creditCardBrand=amex`, and `ssn` values should be masked when installed with `--with-redaction` (Visa, MasterCard, Amex, SSN).

## OpenShift vs generic K8s

| | Generic [`o11y/`](../) | [`o11y/openshift/`](.) |
|--|------------------------|-------------------------|
| CLI | `kubectl` | `oc` |
| SCC | — | `user-access` for agent |
| Values | `distribution` default | `distribution: openshift` |
| Operator UID | chart default | empty `runAsUser` / `fsGroup` |
| Kubelet TLS | — | `insecure_skip_verify: true` |
| HEC logs | yes | yes |

## Troubleshooting

### PodSecurity / SCC warnings on agent

The install creates SCC `user-access` bound to `splunk-otel-collector` in the collector namespace. If agent pods fail SCC checks, re-run:

```bash
./o11y/openshift/scripts/apply_sec_ctx_constraints.sh
```

### Operator pod fails (UID / seccomp)

Ensure `values.example.yaml` has empty operator `securityContext` fields (`fsGroup`, `runAsUser`, `runAsGroup`) so OpenShift assigns namespace UID ranges.

### Kubelet x509 errors in agent logs

`kubeletstats.insecure_skip_verify: true` is set in `values.example.yaml`.

### HEC export / TLS errors

For lab Splunk with self-signed certs, copy `values-local.example.yaml` to `values-local.yaml` and set `splunkPlatform.insecureSkipVerify: true`, then re-run `install.sh`.

### Agent pods not scheduled (taints)

Add tolerations in `values-local.yaml` — see comments in [values-local.example.yaml](values-local.example.yaml).

### Helm install stderr

Check [helm_stderr.txt](helm_stderr.txt) after a failed install.

## Uninstall

```bash
./o11y/openshift/uninstall.sh --delete-secret --delete-namespace -y
```

SCC `user-access` is cluster-scoped and **not** removed automatically. Delete manually only if no longer needed:

```bash
oc delete scc user-access
```

## Related

- [o11y/README.md](../README.md) — generic Kubernetes path, redaction details, Browser RUM
- [docs/deploy-appd-and-o11y.md](../../docs/deploy-appd-and-o11y.md) — full deploy runbook
