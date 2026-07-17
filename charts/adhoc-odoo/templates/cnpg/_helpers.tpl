{{- /*
Expand the name of the chart.
*/}}
{{- define "cnpg.targetBkp" -}}
{{- now | date "20060102150405" }}
{{- end }}

{{- /*
Pg name sanitization.
*/}}
{{- define "cnpg.sanitizedPgName" -}}
{{- $original := .Release.Name | lower }}
{{- $original = regexReplaceAll "^[0-9]+" $original "" }}
{{- regexReplaceAll "[^a-z0-9-]" $original "" }}
{{- end }}

{{- /*
CNPG Cluster object name (single source of truth for the lookup name).
*/}}
{{- define "cnpg.pgClusterName" -}}
{{- printf "%s-pg" (include "cnpg.sanitizedPgName" .) }}
{{- end }}
