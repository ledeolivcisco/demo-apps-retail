---
name: splunk-otel-collector-openshift
description: Use when installing and configuring Splunk Otel Collector on OpenShift using HELM.

---

# Splunk OpenTelemetry Collector for OpenShift + Splunk Observability Cloud

Use this skill when installing the Splunk OTel Collector in Openshift using HELM

## Overview
This SKILL documents a Helm OpenShift setup for Splunk OTel Collector:

## Safety Rules

- Never ask for Splunk Observability access tokens or Splunk Platform HEC tokens in conversation.

## Primary workflow
- If not informed, ask if OBI is going to be enabled or not. Use `templates/values-obi.yaml` or `templates/values-simple.yaml` as the base for `values.yaml`.

### 1. Add Splunk OTel Collector Helm repo

```bash
helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart
helm repo update
```

### 2. Apply OpenShift SCC for the agent
```bash
./scripts/apply_sec_ctx_constraints.sh
```

### 3. Configure credentials and values
- Copy `.env.example` to `.env` and set `SPLUNK_O11Y_ACCESS_TOKEN`, `SPLUNK_OPENSHIFT_CLUSTER_NAME`, and optionally `SPLUNK_O11Y_REALM`.
- Copy the appropriate template from `templates/` to `values.yaml` and adjust placeholders (for OBI, set `discovery.instrument` namespaces or use `k8s_namespace: '*'` for cluster-wide).
- If you do not find `.env`, abort installation.

### 4. Install (namespace, OBI prerequisites, and Helm)
`install_o11y_oc.sh` runs the full one-shot flow:
- Creates the install namespace if missing (`INSTALL_NAMESPACE`, default `otel`).
- When `obi.enabled: true` in `values.yaml`, runs **`prepare_obi_prerequisites.sh` before Helm** (SCC → service account → SCC binding). This avoids Helm `--wait` timeouts from OBI pods failing SCC checks.
- Runs `helm upgrade --install` with a longer wait when OBI is enabled (`HELM_TIMEOUT_OBI`, default `8m`).
- Restarts the OBI DaemonSet only if pods are still not ready after Helm (upgrade/recovery path).

```bash
./scripts/install_o11y_oc.sh
```

### 5. Validate installation
- `helm_stderr.txt` must be empty. If it is not, abort and show `helm_stderr.txt` for troubleshooting.
- Wait 30 seconds, then run:

```bash
./scripts/validate_otel_install.sh
```

Validation includes an OBI DaemonSet check when `obi.enabled: true` in `values.yaml`.


## OBI / eBPF prerequisites (automated)

When `obi.enabled: true` in `values.yaml`, **do not** run Helm until OBI prerequisites are in place. `install_o11y_oc.sh` calls `prepare_obi_prerequisites.sh` automatically in this order:

1. **Deploy the custom SCC** — `apply_obi_scc.sh` (idempotent).
2. **Ensure namespace** — `INSTALL_NAMESPACE` (default `otel`).
3. **Pre-create the OBI service account** — `splunk-otel-collector-obi` (Helm adopts it; required so binding can run before pods schedule).
4. **Bind the SA to the SCC** — `oc adm policy add-scc-to-user splunk-otel-obi-scc -z splunk-otel-collector-obi -n <namespace>`.

Manual runs (troubleshooting only):

```bash
./scripts/prepare_obi_prerequisites.sh   # steps 1–4
./scripts/apply_obi_scc.sh             # SCC only
```

### After a failed install (manual recovery)

If OBI pods were created before SCC binding (older installs), restart the DaemonSet:

```bash
oc rollout restart daemonset/splunk-otel-collector-obi -n otel
oc rollout status daemonset/splunk-otel-collector-obi -n otel
```

Verify the SCC role binding (OpenShift 4.x may show `users: []` on the SCC; binding is via ClusterRole):

```bash
oc adm policy who-can use scc/splunk-otel-obi-scc -n otel
```


## Troubleshooting

### Error similar to this:
'''
warnings.go:110] "Warning: would violate PodSecurity "restricted:latest": host namespaces (hostNetwork=true), hostPort (container "otel-collector" uses hostPorts 14250, 14268, 4317, 4318, 9411), allowPrivilegeEscalation != false (container "otel-collector" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "otel-collector" must set securityContext.capabilities.drop=["ALL"]), restricted volume types (volumes "host-dev", "host-etc", "host-proc", "host-run-udev-data", "host-sys", "host-var-run-utmp", "host-usr-lib-osrelease" use restricted volume type "hostPath"), runAsNonRoot != true (pod or container "otel-collector" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "otel-collector" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")"
'''

Deploy this in the cluster
```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: user-access
allowPrivilegedContainer: true
allowHostDirVolumePlugin: true
allowHostNetwork: true
allowHostPorts: true
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: RunAsAny
fsGroup:
  type: RunAsAny
users:
  - system:serviceaccount:<namespace>:<service account>
```

where:
<namespace> where is the collector going to be installed
<service account> service account for the otel collector usually: splunk-otel-collector

### Problem: Operator POD does not start /auto instrumentation does not work

1 - Check events 
``bash
oc get events <splunk namespace>
```

2 - If you find something like this error in any of the messages
```
Error creating: pods "splunk-otel-collector-operator-7ff58ddb96-" is forbidden: unable to validate against any security context constraint: [pod.metadata.annotations[container.seccomp.security.alpha.kubernetes.io/manager]: Forbidden: seccomp may not be set, pod.metadata.annotations[container.seccomp.security.alpha.kubernetes.io/kube-rbac-proxy]: Forbidden: seccomp may not be set, provider restricted-v2: .spec.securityContext.fsGroup: Invalid value: []int64{65532}: 65532 is not an allowed group, provider restricted-v2: .containers[0].runAsUser: Invalid value: 65532: must be in the ranges: [1000800000, 1000809999], provider restricted-v2: .containers[1].runAsUser: Invalid value: 65532: must be in the ranges: [1000800000, 1000809999], provider "restricted": Forbidden: not usable by user or serviceaccount, provider "nonroot-v2": Forbidden: not usable by user or serviceaccount, provider "nonroot": Forbidden: not usable by user or serviceaccount, provider "pcap-dedicated-admins": Forbidden: not usable by user or serviceaccount, provider "hostmount-anyuid": Forbidden: not usable by user or serviceaccount, provider "hostnetwork-v2": Forbidden: not usable by user or serviceaccount, provider "hostnetwork": Forbidden: not usable by user or serviceaccount, provider "hostaccess": Forbidden: not usable by user or serviceaccount, provider "node-exporter": Forbidden: not usable by user or serviceaccount, provider "user-access": Forbidden: not usable by user or serviceaccount, provider "privileged": Forbidden: not usable by user or serviceaccount]
```

3 - Double check if you have this in your values.yaml
```
securityContextConstraints:
  create: true

operator:
  enabled: true
  replicaCount: 1
  securityContext:
    fsGroup:
    runAsGroup:
    runAsUser:
```

### Problem: X509 certificate errors in agent(collector) logs

- If you get something like this message in the collector logs
```
Get \"https://xxxxx:10250/stats/summary\\": tls: failed to verify certificate: x509: certificate signed by unknown authority"}
http://github.com/open-telemetry/opentelemetry-collector-contrib/receiver/kubeletstatsreceiver.(*kubeletScraper ).scrape
	http://github.com/open-telemetry/opentelemetry-collector-contrib/receiver/kubeletstatsreceiver@v0.145.0/scraper.go:106 
 
	go.opentelemetry.io/collector/scraper@v0.145.0/metrics.go:24
go.opentelemetry.io/collector/scraper/scraperhelper.wrapObsMetrics.func1
	go.opentelemetry.io/collector/scraper/scraperhelper@v0.145.0/obs_metrics.go:57
 
	go.opentelemetry.io/collector/scraper@v0.145.0/metrics.go:24
 
	go.opentelemetry.io/collector/scraper/scraperhelper@v0.145.0/controller.go:167
 
	go.opentelemetry.io/collector/scraper/scraperhelper@v0.145.0/controller.go:139
go.opentelemetry.io/collector/scraper/scraperhelper/internal/controller.(*Controller[...]).startScraping.func1
	go.opentelemetry.io/collector/scraper/scraperhelper@v0.145.0/internal/controller/controller.go:119
2026-02-18T14:47:37.370Z	error	scraperhelper@v0.145.0/obs_metrics.go:61	Error scraping metrics	{"resource": {"service.instance.id": "427ef0ce-864e-46cf-9fda-3ca8137635cc", "service.name": "otel-agent", "service.version": "v0.145.0", "splunk_autodiscovery": "true", "splunk_otlp_histograms": "true"}, "otelcol.component.id": "kubeletstats", "otelcol.component.kind": "receiver", "otelcol.signal": "metrics", "scraper": "kubeletstats", "error": "Get \"https://10.2.91.21:10250/stats/summary\\": tls: failed to verify certificate: x509: certificate signed by unknown authority"}
```

- Double check if you have this in your values.yaml
```
agent:
  config:
    receivers:
      kubeletstats:
        insecure_skip_verify: true
```

## Taints and Tolerations
- check nodes taints
```bash
kubectl describe node <node>
```
**Taints:             3scale=reserved:NoSchedule**


- Add the tolerations to the values.yaml

```bash
tolerations:
  - key: "3scale"
    operator: "Equal"
    value: "reserved"
    effect: "NoSchedule"

#Note that this session should be in the same level as the agent: session
```

- upgrade or redeploy the chart
