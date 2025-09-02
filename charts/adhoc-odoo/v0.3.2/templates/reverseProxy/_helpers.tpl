{{- /*
Selector labels
*/}}
{{- define "adhoc-odoo.nxselectorLabels" -}}
app.kubernetes.io/name: {{ include "adhoc-odoo.name" . }}-nx
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
