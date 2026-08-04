{{/* Chart name. */}}
{{- define "adhoc-way-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Fully qualified name — singleton, so stable = Chart.Name. */}}
{{- define "adhoc-way-platform.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/* Common labels. */}}
{{- define "adhoc-way-platform.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "adhoc-way-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: adhoc-way
{{- end }}

{{/* Selector labels. */}}
{{- define "adhoc-way-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "adhoc-way-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: auth-svc
{{- end }}

{{/* Service account name. */}}
{{- define "adhoc-way-platform.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "adhoc-way-platform.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* Secret name for signing-key/grant-token (existing, or created by the chart). */}}
{{- define "adhoc-way-platform.authSvcSecretName" -}}
{{- if .Values.authSvc.existingSecret }}
{{- .Values.authSvc.existingSecret }}
{{- else }}
{{- printf "%s-authsvc" (include "adhoc-way-platform.fullname" .) }}
{{- end }}
{{- end }}
