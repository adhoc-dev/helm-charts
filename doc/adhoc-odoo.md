# Chart: adhoc-odoo

Chart Helm para deployar instancias Odoo v16+ completas en Kubernetes. Es el chart más complejo del repo — incluye la app Odoo, base de datos (CNPG o standalone), ingress (Nginx o Istio), reverse proxy, storage y scaling.

Versión actual: `0.3.4`

## Estructura de templates

```
templates/
├── odoo/          — Deployment, Service, HPA, Jobs de inicialización
├── cnpg/          — Cluster CNPG (PostgreSQL cloud-native)
├── reverseProxy/  — Deployment del sidecar odooEdgeProxy
├── scaler/        — KEDA ScaledObject
├── rbac/          — ServiceAccount, RBAC
├── odooEnvs.yaml  — ConfigMap con env vars de Odoo
├── regcred.yaml   — ImagePullSecret (opcional)
├── resourceQuota.yaml
└── monitoringCommon.yaml
```

## Secciones del values.yaml

### Imagen Odoo

```yaml
image:
  repository: adhoc/odoo-adhoc   # o dockerhub.adhoc.inc/adhoc/odoo-adhoc
  tag: "19.0"
  pullSecret: "regcred"
```

### Ingress — Nginx (legacy)

```yaml
ingress:
  enabled: true
  issuer: adhoc-letsencrypt-prod-issuer  # o staging
  hosts: ""         # hosts alternativos
  cloudMainDomain: adhoc.ar
```

### Ingress — Istio

```yaml
ingress:
  istio:
    enabled: false
    revision: default
    issuer: istio-http-cluster-issuer
    cloudMainDomain: shared.dev-adhoc.com
    altHosts: ""
    createCertificate: true
    allowedHosts: []            # enforce: hosts externos extra (whitelist), por SNI
    egress:
      mode: ""                  # "" | open | observe | enforce ("" → observe con istio)
      meshExternalNamespaces:   # enforce: ns cluster-level que Odoo usa cross-namespace
        - adhoc-redis
        - adhoc-aeroo-docs
        - kwkhtmltopdf
      networkPolicy:
        allow: []               # enforce: CIDRs privados extra (pods no-meshed)
      repoHosts:                # enforce: hosts para clonar repos custom (default github);
        - github.com            #   se suman a la whitelist solo si odoo.entrypoint.repos != ""
        - codeload.github.com
        - objects.githubusercontent.com
      allowedCidrs: []          # enforce: destinos por IP/CIDR (443 SIN SNI; match por IP).
                                #   Baseline baked-in: VIP de Private Google Access (GCS)
      # SMTP/SSH (server-first) se sacan del sidecar y se gobiernan por NetworkPolicy (no ServiceEntry):
      excludeOutboundPorts: "587,465,25,22"  # puertos que bypassan el sidecar
      outboundTcpCidrs: []      # enforce: CIDRs permitidos en esos puertos (rango del relay SMTP)
      repoSsh: false            # enforce: agrega CIDRs de GitHub SSH a la NP, SOLO si adhoc.devMode
    logAll: false
    http10:
      enabled: false            # habilitar para HTTP/1.0 legacy
```

`blockOutboundTraffic`/`logEgress` quedan como flags legacy (deprecados): el helper de modo
los mapea a `enforce`/`observe`. Ver "Egress control" abajo.

### Egress control

Postura de salida por tenant vía `ingress.istio.egress.mode` (solo con istio habilitado):

| Modo | Sidecar | Logging | Bloqueo |
| --- | --- | --- | --- |
| `open` | `ALLOW_ANY` | no | no |
| `observe` (default con istio) | `ALLOW_ANY` | sí (SNI → Cloud Logging) | no |
| `enforce` | `REGISTRY_ONLY` | sí (hereda observe) | solo la whitelist (ver abajo); no-TLS, HTTP/80 y pods no-meshed bloqueados |

**enforce bloquea en dos planos**, según por dónde sale el tráfico:

1. **Istio (sidecar `REGISTRY_ONLY`)** — el egress HTTPS/443 que pasa por el sidecar: solo los
   destinos con `ServiceEntry`. Dos tipos de matcher:

   | Matcher | Value | ServiceEntry | Para |
   | --- | --- | --- | --- |
   | Host/SNI | `allowedHosts` + `repoHosts` | host, 443/HTTPS, DNS | HTTPS con SNI |
   | IP/CIDR | `allowedCidrs` (+ baseline PGA) | `addresses`, 443/TCP, `resolution: NONE` | 443 **sin SNI** (GCS) |

2. **NetworkPolicy** — dos políticas: una para los pods **no-meshed** (PG/CNPG, jobs; solo
   privado) y otra para el pod **meshed de Odoo**. Esta última deja salir privado + HTTPS/443
   (que el sidecar re-restringe) + los **puertos sacados del sidecar** (`excludeOutboundPorts`)
   solo a los CIDR declarados.

**SMTP y SSH NO van por ServiceEntry.** Son *server-speaks-first* (el servidor manda el banner
primero) y cuelgan el `tls_inspector` del egress logging → bajo `REGISTRY_ONLY` irían a BlackHole.
Por eso esos puertos (`excludeOutboundPorts`, default `587,465,25,22`) se **sacan del sidecar** y
se allowlistean por **CIDR** en la NetworkPolicy del pod meshed:

- **outboundTcpCidrs** — CIDRs permitidos en los puertos SMTP (los excluidos **salvo 22**). No se
  puede derivar de un hostname: usar el rango publicado del proveedor o la IP del relay.
- **repoSsh** (+ `adhoc.devMode`) — agrega los CIDR de GitHub (`repoSshCidrs`, rangos "git" de
  `api.github.com/meta`) a la NetworkPolicy **solo en el puerto 22**; en prod y tests comunes el
  git por SSH queda bloqueado. Las reglas SMTP y SSH son **por puerto** (no se mezclan).

Notas:

- **allowedHosts** se puebla desde el inventario del modo `observe`.
- **repoHosts** se suman solo si `odoo.entrypoint.repos` no está vacío (default github en el
  template, vale bajo `--reuse-values`; sobreescribible para gitlab/etc.).
- **allowedCidrs** matchea por IP destino (no por SNI) → es el camino para el egress a 443 **sin
  SNI** (p.ej. GCS). Baseline baked-in: el `/30` del **Private Google Access** de Google. Requiere
  que la infra rutee `*.googleapis.com` al VIP privado (ver doc de egress en devops-cloud-infra).

Diseño y rationale completos: specs de egress (firewall + listas blancas enriquecidas) en
devops-project. Infraestructura del cluster que lo sostiene (NodeLocal DNS, istiod,
Private Google Access, observabilidad): doc de egress en devops-cloud-infra.

### Reverse Proxy (odooEdgeProxy sidecar)

```yaml
ingress:
  reverseProxy:
    enabled: false
    scale: 1
    blockedIps: [...]            # lista de IPs bloqueadas (extensa por defecto)
    blockedCountries: [CN, IR, CU, SY, ...]
    botBlock:
      enabled: true
      blockedUserAgents:         # GPTBot, Claude, SemrushBot, Baiduspider...
        - GPTBot
        - ClaudeBot
        - ...
    rateLimit:
      enabled: false
      static: 1000r/m
      access: 5r/m
      generic: 1000r/m
      rpc: 60r/m
      debugHeaders: false
    imageCacheEnabled: false
    image:
      repository: dockerhub.adhoc.inc/adhoc/ops-tools
      tag: "odooEdgeProxy-2026.05.21.1"
    loadBalancerCIDR: 10.0.0.0/8
    internalClusterCIDR: 10.0.0.0/8
    monitoring:
      enabled: false
      exporterRepository: dockerhub.adhoc.inc/nginx/nginx-prometheus-exporter
      exporterTag: "1.5.1"
      logRepository: dockerhub.adhoc.inc/adhoc/ops-tools
      logTag: "prometheus-nginxlog-exporter-20251216"
    inactive:
      mode: ""     # maintenance | upgrade | manual
      eta: 0       # unix timestamp
```

### Configuración Odoo

```yaml
odoo:
  pg:
    user: ""
    pass: ""
    host: "adhoc-pg.adhoc-pg"
    port: 5432
    db: "adhoc-pg"

  basic:
    adminPass: "admin"
    dbFilter: ""
    wideModules: "base,web,server_mode,saas_client"
    logLevel: "info"
    aerooHost: ""
    emailFrom: "notifications@adhoc.nubeadhoc.com"
    withoutDemo: true
    language: "es_419"

  saas:
    mode: false
    autoinstallEnabled: "server_mode"
    autoinstallDisabled: "snailmail,account_edi_facturx"
    installDisabled: "l10n_es"

  performance:
    workers: 0
    maxCronTh: 1
    maxDbConn: 96
    dbTemplate: "template0"
    maxMemHard: "4777721600"
    maxMemSoft: "3147484000"
    maxTimeCpu: 3000
    maxTimeReal: 1600
    maxTimeCron: 6000
    maxHttpTh: 8

  entrypoint:
    fixdbs: false
    fixdbsAdhoc: true
    repos: ""           # repos adicionales a clonar en el entrypoint
    custom: ""          # scripts custom del entrypoint
    githubBotToken: ""  # token del bot CICD; se inyecta como GITHUB_BOT_TOKEN
                        # solo si `repos` no está vacío

  smtp:
    host: ""
    port: 0
    ssl: false
    user: ""
    pass: ""

  kwkhtmltopdfServerUrl: "http://kwkhtmltopdf.kwkhtmltopdf"
  monitoring:
    enabled: false
```

### Storage

```yaml
storage:
  location: "attachment_s3"    # attachment_s3 | native | fuse
  aws_region: "US-EAST1"
  aws_host: "https://storage.googleapis.com"   # GCS compatible con S3 API
  aws_bucketname: "..."
  aws_access_key_id: "..."
  aws_secret_access_key: "..."
```

La env var de Odoo equivalente es `ADHOC_ODOO_STORAGE_MODE`.

### Redis

```yaml
redis:
  enabled: false
  host: ""
  pass: ""
  port: 6379
```

### Scaling (HPA / KEDA)

```yaml
autoscaling:
  minReplicas: 1
  maxReplicas: 10
  hpa:
    enabled: false
    targetCPUUtilizationPercentage: 80
    targetMemoryUtilizationPercentage: 90
  keda:
    enabled: false
    rpsThreshold: 2    # réplicas por RPS
```

### CNPG (CloudNativePG)

```yaml
cloudNativePG:
  enabled: false
  version: "15.0"
  instances: 1
  persistence:
    size: 10          # GB
    storageClass: gpc-ssd-d   # gcp-ssd-r (retain) | gcp-ssd-d (delete)
    separateWAL: false
  libraries:
    pgaudit: false
    autoExplain: false
  backup:
    volumeSnapshot:
      enabled: true
      volumeSnapshotClass: gcp-r
    barman:
      enabled: false
  restore:
    fromSnapshot: ""
    fromGCPSnapshot: null
```

> Para GCP: activar "Programación de instantáneas" en el disco persistente del cluster PG.

### Metadata Adhoc

```yaml
adhoc:
  serviceLevel: standard    # standard | advanced | premium
  appType: prod             # test | train | backup | new | old | prod
  clientAnalyticAccount: "Unknown"
  devMode: false
```

> `adhoc.dnsBannedHost` (sinkhole `/etc/hosts`) fue removido — el bloqueo de egress se hace
> con `ingress.istio.egress.mode: enforce` (ver "Egress control").

## Resources por defecto (Odoo pod)

```yaml
resources:
  limits:
    cpu: 3000m
    memory: 4096Mi
  requests:
    cpu: 30m
    memory: 250Mi
```

## Changelog reciente

| Versión | Cambios principales |
| --- | --- |
| 0.3.4 | Bot-blocking declarativo en values (User-Agent, IP, Country), CNPG `safe-to-evict`, Istio HTTP/1.0 |
| 0.3.3 | Rate limits en reverse proxy, cache de imágenes, CNPG webhook ready, ResourceQuota/LimitRange, Prometheus pod monitoring |
