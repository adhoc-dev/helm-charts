{{- /*
Selector labels
*/}}
{{- define "adhoc-odoo.nxselectorLabels" -}}
app.kubernetes.io/name: {{ include "adhoc-odoo.name" . }}-nx
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "adhoc-odoo.nginx.cache_headers" -}}
proxy_buffering on;
proxy_cache cache;
proxy_cache_valid 240m;
proxy_cache_valid any 1m;
proxy_cache_revalidate on;
proxy_cache_use_stale error timeout updating;
proxy_cache_background_update on;
proxy_cache_lock on;
expires 365d;
add_header Cache-Control "public, immutable";
proxy_cache_valid 200 302 365d;
proxy_cache_valid 404 1m;
add_header X-Cache-Status $upstream_cache_status;
# Security recommendations
# https://www.odoo.com/documentation/18.0/administration/on_premise/deploy.html?highlight=nginx#serving-static-files
add_header Content-Security-Policy $content_type_csp;
{{- end }}
