# ADHOC Charts

Charts Helm del stack de Adhoc: DB (CNPG/PostgreSQL), Odoo, jobs de
instalación y mantenimiento, certs SSL, ingress, y demás infraestructura de
soporte. Fuente canónica para la topología del stack desplegado.

Publicado como repositorio Helm en:

```
https://adhoc-dev.github.io/helm-charts/
```

(rama `dev` publica en `https://adhoc-dev.github.io/helm-charts/dev/`).

## Uso

```sh
helm repo add adhoc https://adhoc-dev.github.io/helm-charts/
helm repo update
helm search repo adhoc
helm install <release> adhoc/<chart> -n <namespace> -f values.yaml
```

## Charts

| Chart | Categoría | Descripción |
| --- | --- | --- |
| [`adhoc-odoo`](charts/adhoc-odoo) | DevOps | Deployment completo de Odoo v16+: app + CNPG + ingress (Nginx/Istio) + reverse proxy + storage |
| [`adhoc-pg`](charts/adhoc-pg) | Database | PostgreSQL standalone (legacy / alternativa a CNPG) |
| [`adhoc-redis`](charts/adhoc-redis) | Infrastructure | Redis para caché de sesiones Odoo |
| [`kwkhtmltopdf`](charts/kwkhtmltopdf) | DevOps | Servicio de generación de PDFs |
| [`adhoc-aeroo-docs`](charts/adhoc-aeroo-docs) | Odoo | Servicio Aeroo para generación de documentos (reportes LibreOffice) |
| [`cert-cfg`](charts/cert-cfg) | Infrastructure | Cert issuers (Let's Encrypt prod/staging, Cloudflare DNS01) + nginx ConfigMap |
| [`istio-cfg`](charts/istio-cfg) | Infrastructure | Configuración base Istio: gateways, egress, envoy filter, cert issuers HTTP01/DNS01 |
| [`registry-cache`](charts/registry-cache) | Infrastructure | Registry cache local (Docker Distribution) para reducir pull rate limits |
| [`adhoc-defaultbackend`](charts/adhoc-defaultbackend) | DevOps | Backend por defecto del ingress controller (páginas de error) |
| [`weblate`](charts/weblate) | Infrastructure | Plataforma de traducción Weblate |
| [`adhoc-cluster-sentinel`](charts/adhoc-cluster-sentinel) | DevOps | Controller que corre checks de salud del cluster (Prometheus-sourced) en modo observe/enforce |
| [`adhoc-wakeup-controller`](charts/adhoc-wakeup-controller) | DevOps | Controller que escala instancias Odoo idle a 0 y las despierta on-demand vía CRD |
| [`adhoc-way-platform`](charts/adhoc-way-platform) | DevOps | Singleton por cluster de la plataforma "way": signer, Gateway Istio y cert wildcard |
| [`adhoc-way-instance`](charts/adhoc-way-instance) | DevOps | Instancia efímera por usuario de la plataforma "way" (IDE/agent UI + auth proxy) |

Categorías definidas en [`charts/CHART_CATEGORIES`](charts/CHART_CATEGORIES).

## Documentación

Documentación técnica ampliada en [`doc/`](doc/):

- [`doc/overview.md`](doc/overview.md) — panorama del repo, quién instala qué, imágenes externas referenciadas.
- [`doc/adhoc-odoo.md`](doc/adhoc-odoo.md) — chart principal de Odoo.
- [`doc/adhoc-pg.md`](doc/adhoc-pg.md) — PostgreSQL standalone.
- [`doc/infrastructure-charts.md`](doc/infrastructure-charts.md) — resto de charts de infraestructura.

## Desarrollo

Lint y template-render de los charts modificados corren en CI
([`.github/workflows/helm-validate.yml`](.github/workflows/helm-validate.yml))
y localmente vía pre-commit:

```sh
pre-commit install
pre-commit run --files charts/<chart>/...
```

También se puede correr manualmente sobre todos los charts:

```sh
bash scripts/helm-validate-charts.sh
```

El release (`helm package` + `helm repo index`, publicado a la rama
`gh-pages`) es automático al mergear a `main` (o `dev` para el canal dev) —
ver [`.github/workflows/helm.yml`](.github/workflows/helm.yml) /
[`helm-dev.yml`](.github/workflows/helm-dev.yml).
