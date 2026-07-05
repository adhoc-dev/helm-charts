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


{{- /*
Check if keda can be enable.

DevMode is incompatible with KEDA (in dev mode, we always want one replica).
The inactive mode of reverseProxy is incompatible (the Odoo deployment is disabled in this mode, so scaling it is pointless).
Restoring the database we need to scale down to 0, so if replicaCount is set to 0, we assume that the user wants to be able to scale down to 0, so we enable KEDA even if it's not explicitly enabled.
*/}}
{{- define "keda.enabled" -}}
{{- and
    (.Values.autoscaling.keda.enabled | default false)
    (not .Values.adhoc.devMode)
    (eq .Values.ingress.reverseProxy.inactive.mode "")
    (ne (.Values.replicaCount | int) 0)
-}}
{{- end -}}

{{/*
wakeupController.enabled — true when KEDA + wakeup controller are both active,
minReplicas>=1, and controllerSvc is set. The OWC owns the 1→0 transition, so KEDA
is pinned at floor>=1 (never scales to 0 on its own); the OWC lowers the floor to 0
and scales down itself when idle, and back to 1 on wakeup.

Resilient by design: minReplicas>=1 is a CONDITION here, NOT a hard validation. If an
instance ends up OWC-enabled with minReplicas=0 (e.g. mid-migration of the values),
this returns false → the OWC is silently disabled and the instance falls back to
KEDA-owned scale-to-zero (woken by the HTTP interceptor) instead of failing to render.
*/}}
{{- define "wakeupController.enabled" -}}
{{- $wc := .Values.autoscaling.wakeupController | default dict -}}
{{- and
    (eq (include "keda.enabled" . | trim) "true")
    ($wc.enabled | default false)
    (ge (.Values.autoscaling.minReplicas | int) 1)
    (ne ($wc.controllerSvc | default "") "")
-}}
{{- end -}}

{{/*
wakeupController.domain — CRD group / managed-label prefix of the controller this
instance is attached to. Default "wakeup.adhoc.inc" (stable). Set to a canary
domain (e.g. "wakeup-canary.adhoc.inc") together with a matching canary install of
adhoc-wakeup-controller to shadow-test a new OWC build. See OWC doc/canary-testing.md.
*/}}
{{- define "wakeupController.domain" -}}
{{- $wc := .Values.autoscaling.wakeupController | default dict -}}
{{- $wc.domain | default "wakeup.adhoc.inc" -}}
{{- end -}}

{{/*
adhoc-odoo.egressMode — resuelve el modo de egress efectivo: open | observe | enforce.
- open: ALLOW_ANY, sin logging ni bloqueo.
- observe: ALLOW_ANY + logging de egress (tls_inspector + Telemetry).
- enforce: REGISTRY_ONLY + listas (allow/ban) + NetworkPolicy. Hereda el logging.
Fuente única: ingress.istio.egress.mode. Vacío con istio.enabled → default "observe".
Sin istio.enabled devuelve "open" (los recursos de egress no aplican).
*/}}
{{- define "adhoc-odoo.egressMode" -}}
{{- $istio := .Values.ingress.istio -}}
{{- if not $istio.enabled -}}
{{- "open" -}}
{{- else -}}
{{- $mode := ($istio.egress | default dict).mode | default "observe" -}}
{{- if not (has $mode (list "open" "observe" "enforce")) -}}
  {{- fail (printf "ingress.istio.egress.mode inválido: %q (open|observe|enforce)" $mode) -}}
{{- end -}}
{{- $mode -}}
{{- end -}}
{{- end -}}

{{/*
adhoc-odoo.egressExcludePorts — puertos que se SACAN del sidecar (server-first: SMTP/SSH).
Default 587,465,25,22,2525 (SMTP estándar 587/465/25 + Mailgun-2525 + SSH 22) MÁS el
odoo.smtp.port configurado si es no estándar. Los puertos SMTP son server-speaks-first: si
pasan por el sidecar, el tls_inspector del egress logging los cuelga (timeout 15s → reset,
incluso en observe). Auto-derivar smtp.port evita que un relay en puerto no estándar (p.ej.
Mailgun 2525) quede bloqueado. Nunca agrega 443 (debe pasar por el sidecar). El override de
podAnnotations lo maneja cada template; este helper es el DEFAULT.
*/}}
{{- define "adhoc-odoo.egressExcludePorts" -}}
{{- $egress := (.Values.ingress.istio.egress | default dict) -}}
{{- $base := ($egress.excludeOutboundPorts | default "587,465,25,22,2525") -}}
{{- $ports := list -}}
{{- range (splitList "," $base) -}}
{{- $p := trim . -}}
{{- if $p -}}{{- $ports = append $ports $p -}}{{- end -}}
{{- end -}}
{{- $smtp := (((.Values.odoo | default dict).smtp | default dict).port | default 0 | toString | trim) -}}
{{- if and (ne $smtp "0") (ne $smtp "") (ne $smtp "443") (not (has $smtp $ports)) -}}
{{- $ports = append $ports $smtp -}}
{{- end -}}
{{- join "," $ports -}}
{{- end -}}

{{/*
adhoc-odoo.egressExcludeIPRanges — IPs que se SACAN del redirect del sidecar (salen directo).
Baseline: el metadata server de GKE (169.254.169.254). La Workload Identity de gcsfuse lo consulta
por HTTP:80; bajo enforce (REGISTRY_ONLY) el sidecar no tiene ServiceEntry para él → 502 → gcsfuse
no obtiene el token → el mount cuelga → el pod NO ARRANCA. Excluirlo del mesh lo resuelve (queda
gobernado por la NetworkPolicy, que ya permite link-local). Se le suman los CIDRs extra que el
tenant declare en egress.excludeOutboundIPRanges.
*/}}
{{- define "adhoc-odoo.egressExcludeIPRanges" -}}
{{- $egress := (.Values.ingress.istio.egress | default dict) -}}
{{- $ranges := list "169.254.169.254/32" -}}
{{- range (splitList "," ($egress.excludeOutboundIPRanges | default "")) -}}
{{- $r := trim . -}}
{{- if and $r (not (has $r $ranges)) -}}{{- $ranges = append $ranges $r -}}{{- end -}}
{{- end -}}
{{- join "," $ranges -}}
{{- end -}}
