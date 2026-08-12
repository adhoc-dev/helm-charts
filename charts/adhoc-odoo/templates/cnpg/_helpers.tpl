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

{{- /* safe-to-evict create-only: lo gobierna el cron de saas_k8s, así que en un Cluster
existente se refleja el valor vivo. `lookup` vacío (dry-run, permisos) cae al values. */}}
{{- define "cnpg.safeToEvict" -}}
{{- $existing := lookup "postgresql.cnpg.io/v1" "Cluster" .Release.Namespace (include "cnpg.pgClusterName" .) -}}
{{- $live := "" -}}
{{- if $existing -}}
{{- $live = dig "spec" "inheritedMetadata" "annotations" "cluster-autoscaler.kubernetes.io/safe-to-evict" "" $existing -}}
{{- end -}}
{{- $live | default (.Values.cloudNativePG.safeToEvict | toString) -}}
{{- end }}
