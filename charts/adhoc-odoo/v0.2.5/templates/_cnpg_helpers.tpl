{{/*
    https://cloudnative-pg.io/documentation/1.22/appendixes/object_stores/#google-cloud-storage
*/}}
{{- define "barmanObjectStore.gcp" -}}
destinationPath: {{ printf "gs://%s/%s" ( .Values.cloudNativePG.bucketName ) ( .Release.Name | lower ) }}
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
