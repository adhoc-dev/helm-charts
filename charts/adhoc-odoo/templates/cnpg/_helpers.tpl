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
safe-to-evict del pod de Postgres — create-only: en un Cluster que ya existe se
refleja el valor vivo, no el del values.

Quién manda es el cron `_cron_k8s_checks` (saas_k8s), que lo mueve según la ventana
de mantenimiento y si la base está dormida (CRD del wakeup-controller). Si el chart
lo fijara, cada `helm upgrade` —cada deploy, cada canary— pisaría esa decisión; es
la misma razón por la que el chart no declara `nodeMaintenanceWindow` para prod.

`lookup` devuelve vacío también cuando no puede leer (dry-run, permisos), y ahí cae
al default del values: fail-open a "true", que es el comportamiento histórico y a lo
sumo devuelve una base al estado desalojable hasta la próxima pasada del cron.
*/}}
{{- define "cnpg.safeToEvict" -}}
{{- $existing := lookup "postgresql.cnpg.io/v1" "Cluster" .Release.Namespace (include "cnpg.pgClusterName" .) -}}
{{- $live := "" -}}
{{- if $existing -}}
{{- $live = dig "spec" "inheritedMetadata" "annotations" "cluster-autoscaler.kubernetes.io/safe-to-evict" "" $existing -}}
{{- end -}}
{{- $live | default (.Values.cloudNativePG.safeToEvict | toString) -}}
{{- end }}
