{{/*
    https://cloudnative-pg.io/documentation/1.22/appendixes/object_stores/#google-cloud-storage
*/}}
{{- define "barmanObjectStore.gcp" -}}
{{- if and .Values.cloudNativePG.backup.bucket.enabled .Values.cloudNativePG.backup.bucket.bucketName }}
destinationPath: {{ printf "gs://%s/%s" ( .Values.cloudNativePG.backup.bucket.bucketName | default "notSet" ) ( .Release.Name | lower ) }}
googleCredentials:
  applicationCredentials:
    name: {{ include "adhoc-odoo.fullname" . }}-backup-secret
    key: backup-key.json
wal:
  compression: gzip
  encryption: AES256
  maxParallel: 8
data:
  compression: gzip
  encryption: AES256
  immediateCheckpoint: false
  jobs: 2
{{- end }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "cnpg.targetBkp" -}}
{{- now | date "20060102150405" }}
{{- end }}
