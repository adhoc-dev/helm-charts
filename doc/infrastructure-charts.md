# Charts de infraestructura

Charts de plataforma base. La mayoría son instalados por Pulumi en `devops-cloud-infra` al provisionar cada cell.

---

## kwkhtmltopdf

Servicio de generación de PDFs (wkhtmltopdf). Consumido por Odoo vía `odoo.kwkhtmltopdfServerUrl`.

**Imagen:** `dockerhub.adhoc.inc/adhoc/ops-tools:kwkhtmltopdf-2026.05.07.2`

```yaml
replicaCount: 2
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
monitoring:
  enabled: true
```

Instalado por Pulumi en namespace `kwkhtmltopdf`. URL consumida por Odoo: `http://kwkhtmltopdf.kwkhtmltopdf`.

---

## adhoc-redis

Redis como caché para instancias Odoo. Instalado por Pulumi en `devops-cloud-infra`.

```yaml
redis:
  maxclients: 100000
  appendonly: "yes"
  requirepass: "..."
  port: 6379

resources:
  requests:
    cpu: 300m
    memory: 3Gi

nodeTag: "Prod"
podPriority:
  enabled: true
  priorityClassName: "high-priority"
```

---

## registry-cache

Registry cache local (Docker Distribution / `distribution/distribution`). Cachea imágenes de Docker Hub para reducir pull rate limits y latencia.

Referencia: [hub.docker.com/_/registry](https://hub.docker.com/_/registry) | [distribution docs](https://distribution.github.io/distribution/about/deploying/)

Instalado por Pulumi en `devops-cloud-infra`.

---

## cert-cfg

Configuraciones de cert-manager para los clusters. Crea los `ClusterIssuer` de Let's Encrypt y el ConfigMap de nginx.

**Contenido:**

- `prod_issuer.yaml` — ClusterIssuer Let's Encrypt producción
- `staging_issuer.yaml` — ClusterIssuer Let's Encrypt staging
- `nginx_configMap.yaml` — Configuración nginx del ingress controller

**Cloudflare DNS01** (para wildcards y dominios sin HTTP01):

Permisos del API Token:
- Zone - DNS - Edit
- Zone - Zone - Read
- Zone Resources: All Zones

---

## istio-cfg

Configuración base de Istio para cada cluster. Crea los recursos compartidos de gateways, egress y cert issuers.

**Templates:**

| Template | Recurso |
| --- | --- |
| `io_gw_common.yaml` | Gateway interno (ILB) + externo (LB público) |
| `io_egress_gw.yaml` | EgressGateway para tráfico saliente controlado |
| `io_envoy_filter.yaml` | EnvoyFilter compartido |
| `cm_clusterissuer_http.yaml` | ClusterIssuer HTTP01 (Let's Encrypt) |
| `cm_clusterissuer_dns.yaml` | ClusterIssuer DNS01 (Cloudflare) |
| `cm_wildcard_cert.yaml` | Certificate wildcard del cluster |

---

## adhoc-defaultbackend

Backend por defecto para el ingress controller nginx. Sirve páginas de error personalizadas cuando ninguna regla de ingress coincide.

Contenido estático en `www/`.

---

## adhoc-aeroo-docs

Servicio Aeroo para generación de documentos en Odoo (reportes LibreOffice). Consumido por instancias Odoo que lo tienen habilitado vía `odoo.aerooHost`.

---

## weblate

Plataforma de traducción. No forma parte del stack SaaS core — uso puntual.
