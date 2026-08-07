{{/* Chart name. */}}
{{- define "adhoc-way-instance.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Fully qualified name — per instance, includes the release (prefix). */}}
{{- define "adhoc-way-instance.fullname" -}}
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

{{/* Common labels. */}}
{{- define "adhoc-way-instance.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "adhoc-way-instance.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: adhoc-way
{{- end }}

{{/* Selector labels. */}}
{{- define "adhoc-way-instance.selectorLabels" -}}
app.kubernetes.io/name: {{ include "adhoc-way-instance.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: way-instance
{{- end }}

{{/*
Adhoc labels — convención de la flota (adhoc-odoo, weblate, adhoc-pg):
`adhoc.ar/app-name` identifica el workload y `adhoc.ar/product` coincide con el
label del namespace, que es por donde agrupa el reporte de costos.
*/}}
{{- define "adhoc-way-instance.adhocLabels" -}}
adhoc.ar/product: {{ .Values.adhoc.product | quote }}
adhoc.ar/app-name: {{ .Values.adhoc.appName | quote }}
{{- with .Values.user.id }}
adhoc.ar/way-user-id: {{ . | quote }}
{{- end }}
{{- end }}
