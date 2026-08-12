{{- /*
Expand the name of the chart.
*/}}
{{- /* Deterministic (no `now`): se evalúa por separado en pg_restoreVolumenes.yaml y pgcluster.yaml; releaseName+namespace es único por release aun con 2 CNPG en el mismo ns. */}}
{{- define "cnpg.targetBkp" -}}
{{- printf "%s-%s" .Release.Name .Release.Namespace | sha256sum | trunc 12 }}
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

{{- /*
safe-to-evict del pod de Postgres, según adhoc.appType.

El autoscaler no vacía un nodo con pods que no pertenecen a un controller —y los de
CNPG los crea el operador—, así que sin esta anotación en "true" no hay consolidación.
El costo es que al desalojar el pod, su PV zonal lo obliga a volver a LA MISMA zona: si
ahí no hay memoria queda Pending hasta que aparezca (tarea 72293). Por eso los appType
donde esa espera se paga con una fecha comprometida se marcan como no desalojables:
ese nodo no consolida mientras la base viva ahí.
*/}}
{{- define "cnpg.safeToEvict" -}}
{{- $appType := .Values.adhoc.appType | toString -}}
{{- if has $appType (.Values.cloudNativePG.evictionProtectedAppTypes | default list) -}}
{{- "false" -}}
{{- else -}}
{{- "true" -}}
{{- end -}}
{{- end }}
