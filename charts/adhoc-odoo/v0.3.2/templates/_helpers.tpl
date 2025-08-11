{{- /*
Expand the name of the chart.
*/}}
{{- define "adhoc-odoo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- /*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "adhoc-odoo.fullname" -}}
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

{{- /*
Create chart name and version as used by the chart label.
*/}}
{{- define "adhoc-odoo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- /*
Get odoo mayor version.
*/}}
{{- define "adhoc-odoo.odoo-version" -}}
{{- printf "%s" (regexReplaceAll "^([0-9]+\\.[0-9]+)\\..*" .Values.image.tag "$1") }}
{{- end }}

{{- /*
Get odoo minor version.
*/}}
{{- define "adhoc-odoo.odoo-minor-version" -}}
{{- printf "%s" (regexReplaceAll "^[0-9][0-9]\\.[0-9]\\.([0-9][0-9][0-9][0-9])\\.([0-9][0-9])\\.([0-9][0-9]).*" .Values.image.tag "$1$2$3") }}
{{- end }}


{{- /*
Common labels
*/}}
{{- define "adhoc-odoo.labels" -}}
helm.sh/chart: {{ include "adhoc-odoo.chart" . }}
{{ include "adhoc-odoo.adhocLabels" . }}
{{ include "adhoc-odoo.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- else }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- /*
Selector labels
*/}}
{{- define "adhoc-odoo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "adhoc-odoo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- /*
AdHoc labels
*/}}
{{- define "adhoc-odoo.adhocLabels" -}}
adhoc.ar/tier : {{ .Values.adhoc.appType | lower }}
adhoc.ar/service-level : {{ default "standard" .Values.adhoc.serviceLevel | lower }}
adhoc.ar/odoo-version : {{ include "adhoc-odoo.odoo-version" . | quote }}
adhoc.ar/client-analytic-account : {{ .Values.adhoc.clientAnalyticAccount | quote }}
{{- end }}

{{- /*
Create the name of the service account to use
*/}}
{{- define "adhoc-odoo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "adhoc-odoo.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- /*
Create the prefix of the service to use
We remove initial number to compile with [a-z]([-a-z0-9]*[a-z0-9])?
*/}}
{{- define "adhoc-odoo.serviceNameSuffix" -}}
{{- $original := (include "adhoc-odoo.fullname" .) | lower }}
{{- $original = regexReplaceAll "^[0-9]+" $original "" }}
{{- regexReplaceAll "[^a-z0-9-]" $original "" }}
{{- end }}

{{- /*
Create a sha256sum of the certain values. Is used to force a redeploy only when if needed.
*/}}
{{- define "adhoc-odoo.releaseDigest" -}}
{{- printf "%s%s%s%s" .Values.image.tag .Values.odoo.entrypoint.custom .Values.odoo.entrypoint.repos (.Values.odoo.extraEnvVars | toYaml) | sha256sum }}
{{- end }}

{{- /*
Check if both ingress and istio are enabled
*/}}
{{- if and .Values.ingress.enabled .Values.ingress.istio.enabled }}
{{- fail "You can't enable both: ingress.enabled and ingress.istio.enabled at the same time. Please enable only one." }}
{{- end }}

{{- end }}
