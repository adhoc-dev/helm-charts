{{/*
Expand the name of the chart.
*/}}
{{- define "adhoc-wakeup-controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "adhoc-wakeup-controller.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "adhoc-wakeup-controller.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "adhoc-wakeup-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "adhoc-wakeup-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "adhoc-wakeup-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "adhoc-wakeup-controller.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "adhoc-wakeup-controller.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
FQDN of the waiting-page service (used by adhoc-odoo as CONTROLLER_SVC annotation).
*/}}
{{- define "adhoc-wakeup-controller.serviceFQDN" -}}
{{- printf "%s.%s.svc.cluster.local" (include "adhoc-wakeup-controller.fullname" .) .Release.Namespace }}
{{- end }}
