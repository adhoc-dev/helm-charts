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
      allowedHosts: []          # enforce: whitelist principal — hosts externos por SNI (443)
      allowedCidrs: []          # enforce: destinos por IP/CIDR (443 SIN SNI; match por IP).
                                #   Baseline baked-in: VIP de Private Google Access (GCS)
      openTcpPorts: []          # enforce: puertos "abiertos a priori" a CUALQUIER host, LOGUEADOS
                                #   (client-first: HTTP/PG/Redis/465...). NO server-first, NO 80/443
      # SMTP/SSH (server-first) se sacan del sidecar y se gobiernan por NetworkPolicy (no ServiceEntry).
      # 5432 también sale del sidecar, pero por latencia (ver nota más abajo), no por server-first:
      excludeOutboundPorts: "587,465,25,22,2525,5432"  # bypassan el sidecar; odoo.smtp.port se auto-incluye
      excludeOutboundIPRanges: ""  # IPs extra fuera del redirect; el metadata server (169.254.169.254) ya va baked-in
      outboundTcpCidrs: []      # enforce: CIDRs permitidos en esos puertos (rango del relay SMTP)
      repoSsh: true             # enforce: agrega CIDRs de GitHub SSH a la NP, SOLO con adhoc.devMode
                                #   (no-op en prod). Default true → devMode abre GitHub:22; false para dev sin SSH
    logAll: false
    http10:
      enabled: false            # habilitar para HTTP/1.0 legacy
```

El modo de egress se controla **solo** por `ingress.istio.egress.mode`. Ver "Egress control" abajo.

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

2. **NetworkPolicy** — dos políticas: una para los pods **no-meshed** (PG/CNPG, jobs; privado +
   la VIP de Google APIs en 443, para gcsfuse/backups a GCS) y otra para el pod **meshed de Odoo**.
   Esta última deja salir privado + HTTPS/443 (que el sidecar re-restringe) + los **puertos sacados
   del sidecar** (`excludeOutboundPorts`) solo a los CIDR declarados.

   > **In-cluster por identidad (Cilium / GKE Dataplane V2).** Ambas políticas usan
   > `namespaceSelector: {}` para el egress in-cluster. En Dataplane V2 (anetd/Cilium) un `ipBlock`
   > CIDR **no** habilita el tráfico a pods del cluster (Cilium los matchea por identidad, no por
   > CIDR): sin `namespaceSelector` el sidecar no llega a **istiod** y el pod **no arranca** bajo
   > `enforce`. Los `ipBlock` privados quedan para destinos privados **no-cluster** (Cloud SQL, LBs
   > internos) y el link-local `169.254.0.0/16` cubre NodeLocal DNSCache y el metadata server.

**SMTP y SSH NO van por ServiceEntry.** Son *server-speaks-first* (el servidor manda el banner
primero) y cuelgan el `tls_inspector` del egress logging → **incluso en `observe`** la conexión
se resetea (15s de timeout); bajo `REGISTRY_ONLY` irían a BlackHole. Por eso esos puertos
(`excludeOutboundPorts`, default `587,465,25,22,2525,5432`) se **sacan del sidecar** y se
allowlistean por **CIDR** en la NetworkPolicy del pod meshed. **El puerto SMTP configurado
(`odoo.smtp.port`) se auto-incluye** en la lista efectiva — un relay en puerto no estándar (p.ej.
Mailgun `2525`) queda excluido sin tener que editar `excludeOutboundPorts`:

- **outboundTcpCidrs** — CIDRs permitidos en los puertos SMTP (los excluidos **salvo 22 y 5432**).
  No se puede derivar de un hostname: usar el rango publicado del proveedor o la IP del relay.

> **`5432` está en la lista por otro motivo: latencia, no server-first.** Postgres es el camino
> más caliente de Odoo y cada salto por el sidecar agrega **~0,15 ms por consulta** — medido con
> un A/B entre bases con el puerto excluido y bases con el puerto aún interceptado, normalizando
> la latencia de red con una sonda al puerto 22 (que ya estaba excluido). A ~126 consultas/s son
> ~2 h de espera acumulada cada 108 h. ⚠️ **No medir esto durante una ventana de CPU throttling
> del propio Postgres**: el congelamiento del backend infla el `SELECT 1`, y esa demora —que es
> del motor— termina contabilizada como si fuera del proxy (nos pasó: 0,85 ms aparentes contra
> 0,13 ms reales). El pod CNPG no está en el mesh, así que el passthrough no aportaba mTLS ni
> políticas. Queda fuera de la regla de `outboundTcpCidrs` (es tráfico a la DB in-cluster, no al
> relay del tenant): lo cubre la regla `namespaceSelector` de la NetworkPolicy meshed. **Si un
> tenant usa Postgres externo con `5432` en `openTcpPorts`, hay que sacarlo de una de las dos
> listas** — el chart rechaza a propósito que un puerto esté en ambas.
- **repoSsh** (default `true`) — agrega los CIDR de GitHub (`repoSshCidrs`, rangos "git" de
  `api.github.com/meta`) a la NetworkPolicy **solo en el puerto 22**. **Solo surte efecto con
  `adhoc.devMode=true`** (es no-op en prod → ahí git-SSH queda bloqueado igual). Con `devMode` abre
  GitHub:22 por defecto; poner `repoSsh: false` para un dev sin git-SSH. Reglas SMTP y SSH **por
  puerto** (no se mezclan).

Notas:

- **Metadata server / Workload Identity.** El metadata server de GKE (`169.254.169.254`, HTTP:80)
  se saca del redirect del sidecar (`excludeOutboundIPRanges`, baked-in). gcsfuse lo consulta para
  la WI; bajo `enforce` el sidecar (REGISTRY_ONLY) lo bloquearía (**502**) → gcsfuse no monta → el
  pod **no arranca**. Excluirlo lo deja gobernado por la NetworkPolicy (que ya permite link-local).
- **allowedHosts** se puebla desde el inventario del modo `observe`.
- **repoHosts** se suman solo si `odoo.entrypoint.repos` no está vacío (default github en el
  template, vale bajo `--reuse-values`; sobreescribible para gitlab/etc.).
- **allowedCidrs** matchea por IP destino (no por SNI) → es el camino para el egress a 443 **sin
  SNI** (p.ej. GCS). Baseline baked-in: el `/30` del **Private Google Access** de Google. Requiere
  que la infra rutee `*.googleapis.com` al VIP privado (ver doc de egress en devops-cloud-infra).
- **openTcpPorts** — puertos "abiertos a priori": emite un ServiceEntry por puerto (`addresses:
  0.0.0.0/0`) que deja salir a **cualquier host** en ese puerto **y lo loguea** (pasa por el
  sidecar). Solo para protocolos **client-first** (HTTP, PostgreSQL, Redis, SMTPS-465…); los
  **server-first** (SMTP 587/25 STARTTLS, SSH 22) cuelgan el `tls_inspector` → esos van por
  `excludeOutboundPorts`. El chart **rechaza 80/443** acá (romperían el bloqueo/whitelist).

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
      reportMaxConcurrency: 3
    sessionAffinity: false
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

#### Límite de reportes concurrentes

`rateLimit.reportMaxConcurrency` acota cuántos `/report/pdf` + `/report/download` tiene **un cliente** en vuelo. Es concurrencia, no tasa: un PDF retiene un worker HTTP de Odoo varios segundos esperando a kwkhtmltopdf, así que la tasa no es la dimensión que se agota — la concurrencia mapea 1:1 a workers. `/report/barcode` queda deliberadamente afuera: lo pide kwkhtmltopdf mientras renderiza un PDF que ya tiene un worker tomado.

Dimensionarlo contra el **pool total** (`odoo.performance.workers` × `replicaCount`), no como número suelto. Criterio usado: que un cliente no retenga más de ~1/3 del pool, porque cada PDF padre arrastra sub-requests que reentran al mismo pool.

**El límite se cuenta por instancia de nginx.** La zona de `limit_conn` vive en memoria compartida de un nginx y no se comparte entre pods, así que con `scale: 2` el techo real por cliente es el doble del configurado — salvo que el cliente caiga siempre en el mismo pod.

#### Afinidad de cliente hacia el reverse proxy

Si un cliente reparte sus requests entre los pods del proxy, el límite de arriba se multiplica por la cantidad de pods. Cada ingress lo resuelve distinto:

| Ingress | Afinidad | Qué hace falta |
| --- | --- | --- |
| Nginx (legacy, adhocprod) | Ya existe | El template emite `nginx.ingress.kubernetes.io/affinity: cookie` de forma incondicional. Nada que configurar. |
| Istio (cell0X) | No existe por default | `reverseProxy.sessionAffinity: true` emite una `DestinationRule` con hash consistente. |

`sessionAffinity` viene **apagado** por dos motivos: afecta el balanceo de todo el tráfico de la instancia (no solo el de reportes), y hasta su incorporación no había ninguna `DestinationRule` en la plataforma.

El hash va por `x-forwarded-for` y **no** por la cookie de sesión a propósito. Con `consistentHash.httpCookie`, si se le agrega un `ttl`, Envoy **genera** la cookie cuando falta; como acá se llamaría `session_id`, pisaría la sesión de Odoo. El header no tiene esa trampa.

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

#### Ephemeral storage en bases `fuse`

Con `storage.location: fuse` el Deployment emite las annotations
`gke-gcsfuse/*` que configuran el sidecar del CSI driver. La de
`ephemeral-storage-limit` merece atención: **es, de hecho, el límite efímero del
pod entero**, no solo del sidecar. Kubelet obtiene el límite del pod sumando los
limits de `ephemeral-storage` de todos sus containers, y `adhoc-odoo` no declara
el suyo — así que ese valor topea también los `emptyDir` del pod. Si se excede,
kubelet desaloja el pod:

```
Warning  Evicted  Pod ephemeral local storage usage exceeds the total limit of containers 5Gi.
```

De ahí el valor más alto en `devMode`: el initContainer `seed-vscode-server`
siembra ~4.8Gi en `emptyDir` (VS Code server ~3.4Gi en `vscode-server` +
`/opt/adhoc-dev` ~1.3Gi en `dev-tools`), con lo que 5Gi dejaban <400Mi de margen
para las escrituras locales de Odoo (reportes, dumps a `/tmp`, logs).

| | `ephemeral-storage-limit` |
| --- | --- |
| `adhoc.devMode: false` | `5Gi` |
| `adhoc.devMode: true` | `12Gi` |

El `request` (`100Mi`, `248Mi` en prod) no depende de `devMode`: el limit
gobierna el desalojo, no el scheduling. Para pisar el valor en una instancia
puntual, definir la key en `podAnnotations` — el template la omite si ya viene de
ahí, para no emitirla duplicada (una key repetida en el map de annotations rompe
el parseo del manifest).

El pod del reverse proxy (`-nx`) queda en `5Gi`: no monta los volúmenes sembrados.

Para medir el uso real de un pod, la summary API de kubelet lo desglosa por
volumen y por container:

```bash
kubectl get --raw "/api/v1/nodes/<node>/proxy/stats/summary"
```

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

> **Política de disrupción (`safeToEvict`, `enablePDB`, ventana de mantenimiento)** — el chart
> ya no declara `enablePDB` ni `nodeMaintenanceWindow`, y tampoco crea un PDB propio para el
> primary: los gobierna el cron `_cron_k8s_checks` de `saas_k8s` con un solo criterio (ventana
> de mantenimiento o base dormida). `nodeMaintenanceWindow` queda jubilado — CNPG lo
> desaconseja porque limita self-healing, rolling updates y el propio PDB, y mientras está
> abierta `enablePDB` no tiene efecto.

> **`safeToEvict`** — valor con el que **nace** la anotación
> `cluster-autoscaler.kubernetes.io/safe-to-evict` del pod de Postgres. Nace en `false`, o sea
> retenida, para que el estado inicial sea coherente con `enablePDB`, que nace en el default
> `true` del CRD. Es **create-only**: en un Cluster que ya existe, el chart refleja el valor vivo
> en vez del values. Quien la gobierna es el cron `_cron_k8s_checks` de `saas_k8s`, según la ventana de mantenimiento y si la base está
> dormida; si el chart la fijara, cada `helm upgrade` pisaría esa decisión — la misma razón por la
> que el chart no declara `nodeMaintenanceWindow` para `prod`. Importa porque el PV es zonal:
> desalojar obliga al pod a volver a la misma zona y, si ahí no hay memoria, la base espera
> (tarea 72293).

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
