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

{{/*
Claim name for this user's state.

Derived from the user id so that every surface of the same person lands on the
same volume without the caller having to pass anything: the whole point is that
the state belongs to the user, not to the surface.
*/}}
{{- define "adhoc-way-instance.claimName" -}}
{{- if .Values.state.claimName }}
{{- .Values.state.claimName }}
{{- else if .Values.user.id }}
{{- printf "way-user-%v" .Values.user.id }}
{{- else }}
{{- printf "%s-state" (include "adhoc-way-instance.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Service account of the pod.

Its token is how the platform knows which instance is asking for a credential. The release
name is that instance, so nobody has to pass it.
*/}}
{{- define "adhoc-way-instance.serviceAccountName" -}}
{{- default .Release.Name .Values.serviceAccount.name }}
{{- end }}

{{/*
The name of a source, checked. Everything else about it is derived from this, so what is
not a name in the root of the workspace is refused here instead of rendering a pod that
kubelet or the entrypoint would turn down.
*/}}
{{- define "adhoc-way-instance.sourceKey" -}}
{{- $name := trimPrefix "." (.dstPath | default "") -}}
{{- if not (regexMatch "^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" $name) -}}
{{- fail (printf "sources: dstPath %q is not a name in the root of the workspace (an optional dot, then lowercase letters, digits and dashes)" .dstPath) -}}
{{- end -}}
{{- if gt (len $name) 56 -}}
{{- /* 56 and not 63: the volume name is this with `source-` in front. */ -}}
{{- fail (printf "sources: dstPath %q is longer than 56 characters, which is what a volume name leaves for it" .dstPath) -}}
{{- end -}}
{{- $name -}}
{{- end }}

{{/*
Refuse two sources that would render the same volume.
*/}}
{{- define "adhoc-way-instance.validateSources" -}}
{{- $keys := list -}}
{{- range .Values.sources -}}
{{- $keys = append $keys (include "adhoc-way-instance.sourceKey" .) -}}
{{- end -}}
{{- if ne (len $keys) (len (uniq $keys)) -}}
{{- fail (printf "sources: two entries share a dstPath (%v)" $keys) -}}
{{- end -}}
{{- end }}

{{/*
Volume name of a source.
*/}}
{{- define "adhoc-way-instance.sourceName" -}}
{{- printf "source-%s" (include "adhoc-way-instance.sourceKey" .) -}}
{{- end }}

{{/*
Where a source is mounted. Under /mnt and not in the workspace: what belongs in the
workspace is the directory inside the image, and a link is the only way to expose it.
*/}}
{{- define "adhoc-way-instance.sourceMount" -}}
{{- printf "/mnt/%s" (include "adhoc-way-instance.sourceKey" .) -}}
{{- end }}

{{/*
What a source links to: srcPath inside its mount. Refused if it leaves the mount, which
is the same mistake as a dstPath that is not a name, one directory down.
*/}}
{{- define "adhoc-way-instance.sourceTarget" -}}
{{- $mount := include "adhoc-way-instance.sourceMount" . -}}
{{- $target := clean (printf "%s/%s" $mount (.srcPath | default "" | trimPrefix "/")) -}}
{{- if not (or (eq $target $mount) (hasPrefix (printf "%s/" $mount) $target)) -}}
{{- fail (printf "sources: srcPath %q leaves the mount of %q" .srcPath .dstPath) -}}
{{- end -}}
{{- $target -}}
{{- end }}
