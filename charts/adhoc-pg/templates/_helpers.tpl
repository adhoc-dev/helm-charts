{{/*
Expand the name of the chart.
*/}}
{{- define "adhoc-pg.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "adhoc-pg.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "adhoc-pg.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "adhoc-pg.labels" -}}
helm.sh/chart: {{ include "adhoc-pg.chart" . }}
{{ include "adhoc-pg.selectorLabels" . }}
{{ include "adhoc-pg.adhocLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "adhoc-pg.selectorLabels" -}}
app.kubernetes.io/name: {{ include "adhoc-pg.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- /*
AdHoc labels
*/}}
{{- define "adhoc-pg.adhocLabels" -}}
adhoc.ar/infrastructure: "true"
adhoc.ar/odoo-client-shared: "true"
{{- end }}


{{/*
Create the name of the service account to use
*/}}
{{- define "adhoc-pg.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "adhoc-pg.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
