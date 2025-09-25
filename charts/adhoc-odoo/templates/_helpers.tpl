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
adhoc.ar/tier : {{ default "unknown" .Values.adhoc.appType | quote | lower }}
adhoc.ar/service-level : {{ default "standard" .Values.adhoc.serviceLevel | quote | lower }}
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
{{- printf "%s%s%s%s" .Values.image.tag (.Values.odoo | toYaml ) | sha256sum }}
{{- end }}

{{- /*
Check if both ingress and istio are enabled
*/}}
{{- if and .Values.ingress.enabled .Values.ingress.istio.enabled }}
{{- fail "You can't enable both: ingress.enabled and ingress.istio.enabled at the same time. Please enable only one." }}
{{- end }}

{{- /*
Check if both hpa and keda are enabled
*/}}
{{- if and .Values.autoscaling.hpa.enabled .Values.autoscaling.keda.enabled }}
{{- fail "You can't enable both: autoscaling.hpa.enabled and autoscaling.keda.enabled at the same time. Please enable only one." }}
{{- end }}

{{- /*
Check if min replicas is higher than 0
*/}}
{{- if and .Values.autoscaling.hpa.enabled (not .Values.autoscaling.minReplicas) }}
{{- fail "You must set autoscaling.minReplicas to a value higher than 0 when autoscaling.hpa.enabled is true." }}
{{- end }}

{{- /*
Check if the database is set
*/}}
{{- if not .Values.odoo.pg.db }}
{{- fail "You must set .Values.odoo.pg.db to a valid database name." }}
{{- end }}

{{- define "sumMemory" -}}
{{- $totalBytes := 0 -}}
{{- range . -}}
    {{- if hasSuffix "Gi" . -}}
      {{- $value := replace "Gi" "" . | float64 -}}
      {{- $totalBytes = add $totalBytes (mul $value 1073741824) -}}
    {{- else if hasSuffix "Mi" . -}}
      {{- $value := replace "Mi" "" . | float64 -}}
      {{- $totalBytes = add $totalBytes (mul $value 1048576) -}}
    {{- else if hasSuffix "Ki" . -}}
      {{- $value := replace "Ki" "" . | float64 -}}
      {{- $totalBytes = add $totalBytes (mul $value 1024) -}}
    {{- else if hasSuffix "G" . -}}
      {{- $value := replace "G" "" . | float64 -}}
      {{- $totalBytes = add $totalBytes (mul $value 1000000000) -}}
    {{- else if hasSuffix "M" . -}}
      {{- $value := replace "M" "" . | float64 -}}
      {{- $totalBytes = add $totalBytes (mul $value 1000000) -}}
    {{- else if hasSuffix "K" . -}}
      {{- $value := replace "K" "" . | float64 -}}
      {{- $totalBytes = add $totalBytes (mul $value 1000) -}}
    {{- else -}}
      {{- $totalBytes = add $totalBytes (. | float64) -}}
    {{- end -}}
{{- end -}}

{{- if ge $totalBytes 1073741824 -}}
  {{- printf "%.0fGi" (div $totalBytes 1073741824 | float64) -}}
{{- else if ge $totalBytes 1048576 -}}
  {{- printf "%.0fMi" (div $totalBytes 1048576 | float64) -}}
{{- else if ge $totalBytes 1024 -}}
  {{- printf "%.0fKi" (div $totalBytes 1024| float64) -}}
{{- else -}}
  {{- printf "%d" $totalBytes -}}
{{- end -}}

{{- end -}}

{{- define "sumCPU" -}}
{{- $totalMilli := 0 -}}
{{- range . -}}
  {{- if hasSuffix "m" . -}}
    {{- $value := replace "m" "" . | int -}}
    {{- $totalMilli = add $totalMilli $value -}}
  {{- else -}}
    {{- $value := . | float64 -}}
    {{- $totalMilli = add $totalMilli (mul $value 1000) -}}
  {{- end -}}
{{- end -}}

{{- if ge $totalMilli 1000 -}}
  {{- $cores := div $totalMilli 1000 -}}
  {{- if eq (mod $totalMilli 1000) 0 -}}
    {{- printf "%d" $cores -}}
  {{- else -}}
    {{- printf "%.1f" (div $totalMilli 1000.0) -}}
  {{- end -}}
{{- else -}}
  {{- printf "%dm" $totalMilli -}}
{{- end -}}

{{- end -}}
