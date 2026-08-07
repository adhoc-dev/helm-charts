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
{{ include "adhoc-way-user.adhocLabels" . }}
{{- end }}

{{/*
Adhoc labels — same convention as the rest of the fleet (adhoc-odoo, weblate,
adhoc-pg): `adhoc.ar/app-name` identifies the workload and `adhoc.ar/product`
matches the label already on the namespace, which is what cost reporting groups
by.

Note these are KUBERNETES labels. They do NOT reach the GCP disk: a provisioned
PD only carries the cluster-level labels (env, team, iac) plus goog-* ones, and
the PVC name lands in its description, which cannot be grouped by in billing.
Putting our labels on the disk itself would take a dedicated StorageClass.
*/}}
{{- define "adhoc-way-user.adhocLabels" -}}
adhoc.ar/product: {{ .Values.adhoc.product | quote }}
adhoc.ar/app-name: {{ .Values.adhoc.appName | quote }}
{{- with .Values.user.id }}
adhoc.ar/way-user-id: {{ . | quote }}
{{- end }}
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
