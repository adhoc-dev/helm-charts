# helm-charts — Overview

Repositorio de charts Helm del stack Adhoc. Publicado como repositorio Helm en:

```
https://adhoc-dev.github.io/helm-charts/
```

Fuente canónica para la topología del stack desplegado (DB, Odoo, jobs, certs SSL, ingress).

## Charts

| Chart | Categoría | Descripción |
| --- | --- | --- |
| `adhoc-odoo` | DevOps | Deployment completo de Odoo v16+: app + CNPG + ingress (Nginx/Istio) + reverse proxy + storage |
| `adhoc-pg` | Database | PostgreSQL standalone (legacy / alternativa a CNPG) |
| `adhoc-redis` | Infrastructure | Redis para caché Odoo |
| `kwkhtmltopdf` | DevOps | Servicio de generación de PDFs |
| `cert-cfg` | Infrastructure | Cert issuers (Let's Encrypt prod/staging, Cloudflare DNS01) + nginx ConfigMap |
| `istio-cfg` | Infrastructure | Configuración base Istio: gateways, egress, envoy filter, cert issuers HTTP01/DNS01 |
| `registry-cache` | Infrastructure | Registry cache local (Docker Distribution) |
| `adhoc-defaultbackend` | DevOps | Backend por defecto para el ingress controller |
| `adhoc-aeroo-docs` | Odoo | Servicio Aeroo para generación de documentos Odoo |
| `weblate` | Infrastructure | Plataforma de traducción Weblate |

## Quién instala qué

| Chart | Instalado por | Notas |
| --- | --- | --- |
| `kwkhtmltopdf` | Pulumi (`k8s_apps/apps/kwkhtmltopdf.py`) | Plataforma base |
| `registry-cache` | Pulumi (`k8s_apps/apps/registry_cache.py`) | Plataforma base |
| `adhoc-redis` | Pulumi (`k8s_apps/apps/redis.py`) | Plataforma base |
| `keda` | Pulumi (`k8s_apps/apps/keda.py`) | Plataforma base |
| `adhoc-odoo` | `saas_provider` en runtime | Por instancia Odoo |
| `adhoc-pg` | `saas_provider` en runtime | Por instancia Odoo (si no usa CNPG) |

Pulumi consume el repo vía URL `https://adhoc-dev.github.io/helm-charts/` en `devops-cloud-infra`.

## Mantenedores

`dib@adhoc.inc`, `jjs@adhoc.inc`, `az@adhoc.inc`

## Imágenes externas referenciadas

| Imagen | Usada por |
| --- | --- |
| `dockerhub.adhoc.inc/adhoc/ops-tools:odooEdgeProxy-<fecha>` | `adhoc-odoo` (sidecar reverse proxy) |
| `dockerhub.adhoc.inc/adhoc/ops-tools:kwkhtmltopdf-<fecha>` | `kwkhtmltopdf` |
| `dockerhub.adhoc.inc/adhoc/ops-tools:prometheus-nginxlog-exporter-<fecha>` | `adhoc-odoo` (monitoring del reverse proxy) |

Las imágenes `ops-tools` son construidas en `devops-ops-tools`. Ver [memory/repo-relationships.md](../memory/repo-relationships.md).
