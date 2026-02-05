{{- /*
Expand the name of the chart.
*/}}
{{- define "odoo.image" -}}
{{ $minorVersion := include "adhoc-odoo.odoo-minor-version" . | int }}
{{- $odooImage := printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}
{{- if and (gt $minorVersion 20250415) (or .Values.adhoc.devMode ( .Values.odoo.entrypoint.repos)) (not (hasSuffix $odooImage ".dev")) }}
{{- $odooImage = printf "%s.dev" $odooImage }}
{{- end }}
{{- $odooImage -}}
{{- end }}