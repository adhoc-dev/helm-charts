{{/* Chart name. */}}
{{- define "adhoc-way-user.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified name — per user, includes the release.

This name is the contract with adhoc-way-instance: each surface references it as
`state.existingClaim`, so it has to be predictable from the release name.
*/}}
{{- define "adhoc-way-user.fullname" -}}
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
{{- define "adhoc-way-user.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "adhoc-way-user.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: way-user-state
app.kubernetes.io/part-of: adhoc-way
{{- end }}

{{/*
Claim name. Default: the release name, plain.

This is the CONTRACT with adhoc-way-instance — every surface of this user passes
it as `state.existingClaim`, and the Odoo module has to be able to construct it
without guessing. So it is deliberately the release name and not the usual
`<release>-<chart>` fullname: one less rule to remember at the other end.
*/}}
{{- define "adhoc-way-user.claimName" -}}
{{- default .Release.Name .Values.state.claimName | trunc 63 | trimSuffix "-" }}
{{- end }}
