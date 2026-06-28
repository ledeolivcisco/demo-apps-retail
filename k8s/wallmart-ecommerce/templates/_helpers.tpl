{{/*
Expand the name of the chart.
*/}}
{{- define "wallmart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "wallmart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "wallmart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "wallmart.namespace" -}}
{{- .Values.namespace.name }}
{{- end }}

{{- define "wallmart.labels" -}}
helm.sh/chart: {{ include "wallmart.chart" . }}
{{ include "wallmart.selectorLabels" . }}
app.kubernetes.io/part-of: wallmart-ecommerce
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{- define "wallmart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wallmart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "wallmart.componentSelectorLabels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/part-of: wallmart-ecommerce
{{- end }}

{{- define "wallmart.componentLabels" -}}
helm.sh/chart: {{ include "wallmart.chart" .root }}
{{ include "wallmart.componentSelectorLabels" . }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{- define "wallmart.appImage" -}}
{{- $registry := .root.Values.global.imageRegistry -}}
{{- $tag := .root.Values.global.imageTag -}}
{{- printf "%s/%s:%s" $registry .repository $tag }}
{{- end }}

{{- define "wallmart.mssqlSecretName" -}}
{{- if .Values.mssql.existingSecret }}
{{- .Values.mssql.existingSecret }}
{{- else }}
{{- printf "%s-mssql" (include "wallmart.fullname" .) }}
{{- end }}
{{- end }}

{{- define "wallmart.mssqlPasswordKey" -}}
{{- if .Values.mssql.existingSecret -}}
{{- .Values.mssql.existingSecretPasswordKey -}}
{{- else -}}
MSSQL_SA_PASSWORD
{{- end -}}
{{- end }}

{{- define "wallmart.dbEnv" -}}
- name: WALLMART_DB_HOST
  value: {{ .root.Values.appConfig.dbHost | quote }}
- name: WALLMART_DB_PORT
  value: {{ .root.Values.appConfig.dbPort | quote }}
- name: WALLMART_DB_NAME
  value: {{ .root.Values.appConfig.dbName | quote }}
- name: WALLMART_DB_USER
  value: {{ .root.Values.appConfig.dbUser | quote }}
- name: WALLMART_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "wallmart.mssqlSecretName" .root }}
      key: WALLMART_DB_PASSWORD
- name: WALLMART_DB_BOOTSTRAP
  value: {{ .dbBootstrap | quote }}
{{- end }}

{{- define "wallmart.waitForSqlInitContainer" -}}
{{- if .root.Values.initContainers.waitForSql.enabled }}
- name: wait-for-sql
  image: {{ .root.Values.initContainers.waitForSql.image }}
  imagePullPolicy: {{ .root.Values.global.imagePullPolicy }}
  command:
    - sh
    - -c
    - |
      until nc -z {{ .root.Values.serviceNames.sqlserver }} {{ .root.Values.appConfig.dbPort }}; do
        echo "waiting for sqlserver:{{ .root.Values.appConfig.dbPort }}..."
        sleep 2
      done
{{- end }}
{{- end }}

{{- define "wallmart.waitForProductInitContainer" -}}
{{- if .root.Values.initContainers.waitForProduct.enabled }}
- name: wait-for-product
  image: {{ .root.Values.initContainers.waitForProduct.image }}
  imagePullPolicy: {{ .root.Values.global.imagePullPolicy }}
  command:
    - sh
    - -c
    - |
      until nc -z {{ .root.Values.serviceNames.productService }} {{ .root.Values.productService.port }}; do
        echo "waiting for {{ .root.Values.serviceNames.productService }}:{{ .root.Values.productService.port }}..."
        sleep 2
      done
{{- end }}
{{- end }}

{{- define "wallmart.podSecurityContext" -}}
runAsNonRoot: {{ .Values.podSecurity.runAsNonRoot }}
runAsUser: {{ .Values.podSecurity.runAsUser }}
fsGroup: {{ .Values.podSecurity.fsGroup }}
{{- end }}
