# Version changes

## *0.3.4*

Fixes:

- Bases `fuse`: la `livenessProbe` de `adhoc-odoo` y del reverse proxy (`-nx`)
  pasa de `tcpSocket:8069` a un `exec` que verifica el mount del filestore. Si el
  sidecar gcsfuse muere, el mount queda colgado (`Errno 107`) pero Odoo sigue
  escuchando en 8069, así que el pod quedaba "vivo pero roto" (`/web/image` y
  adjuntos daban 500); ahora el kubelet reinicia el container y gcsfuse remonta
  limpio. odoo: `os.stat` del mount + check de puerto; nginx: `[ -d mount ]`. Se
  agrega además `readinessProbe` al nginx del `-nx` (`tcpSocket:9080`). Solo
  afecta bases `fuse`; con valores por defecto el render no cambia (sin bump).
- OWC (wakeup controller): los helpers `wakeupController.domain` y
  `wakeupController.enabled` ahora toleran que el sub-map
  `autoscaling.wakeupController` venga nil/ausente (caso típico: `helm upgrade
  --reuse-values` sobre una instancia legacy anterior a #74). Antes el render
  fallaba con `nil pointer evaluating interface {}.domain`. Regresión cubierta
  por el fixture `ci/legacy-no-wakeupcontroller-values.yaml`.
- Odoo 19: `report.url` se coloca en la sección de conf según la imagen. Corrige
  la suposición previa de que era inerte: `server_global_parameters` (ADHOC SA)
  lo lee del odoo.conf vía `get_param`, así que quitarlo cambiaba el
  comportamiento (afecta wkhtml2pdf). Ahora: imágenes 19 `>= 20260707` (con el
  `server_global_parameters` que lee la sección `[adhoc]`) lo reciben bajo
  `[adhoc]` (sin warning `unknown option`); imágenes 18 y 19 anteriores lo
  reciben bajo `[options]` (compatibilidad con el módulo previo). `x_sendfile=True`
  queda siempre en `[options]`.

Features:

- Reverse Proxy:
  - Global bot blocking based on User-Agent (NGINX `map`)
    - 444 response for matching blocks (Bots, Countries, IP, etc) at reverse proxy level
    - Declarative configuration via Helm values (`ingress.reverseProxy.botBlock.blockedUserAgents`)
    - Enable / disable switch (`ingress.reverseProxy.botBlock.enabled`)
    - Default blocked bots list includes common AI, crawler and scraping agents (GPTBot, Claude, Bytespider, SemrushBot, Baiduspider, etc.)
  - Global IP, Country blocking
  - Helm questions added to manage blocked User-Agents without modifying templates
  - Unified behavior across Odoo versions (18.x and 19.x)
  - Maintenance mode
  - New personalized image
  - New personalized error pages
  - IP WhiteList for rate limit
- CNPG:
  - Add safe-to-evict
  - PodMonitor `metricRelabelings` drop  `cnpg_pg_settings_setting` (static value). see `devops-cloud-infra/doc/observability/cardinality-budget.md`.
  - Add nodeMaintenanceWindow for non-prod loads

BugFixes:

- Reverse Proxy:
  - Fix NGINX crash on Odoo 18 due to undefined variables (`unknown "block_bad_ua" variable`)
  - Ensure bot-block variables are always defined before usage
  - Improved configuration consistency between nginx versions

Improvements:

- Reverse Proxy:
  - Reduced configuration drift by moving bot blocking logic from hardcoded templates to values-driven configuration
  - Safer upgrades and rollbacks using Helm-managed values
- Istio:
  - new config to allow legacy http01 requests (`ingress.istio.http10.enabled`)
- Autoscaling (OWC):
  - keda is a prerequisite for the wakeup controller: disabling keda now disables OWC automatically instead of failing the render (the `wakeupController.enabled` helper already gated on keda; removed the hard `fail` in `validate.yaml`)

## *0.3.3*

Features:

- Reverse Proxy:
  - Rate limits (Disabled by default `ingress.reverseProxy.rateLimit.enabled: false`)
    - static files (Default 3000r/s `ingress.reverseProxy.rateLimit.static: 3000r/s`)
    - access/secure endpoints (Default 5r/m `ingress.reverseProxy.rateLimit.access: 5r/m`)
    - common endpoints (Default 60r/s `ingress.reverseProxy.rateLimit.generic: 60r/s`)
    - websocket (Default 10r/s `ingress.reverseProxy.rateLimit.ws: 10r/s`)
  - Cache for public images, static content, etc. (Disabled by default `ingress.reverseProxy.imageCacheEnabled: false`)
- CNPG:
  - Webhook added to wait pg to be ready
  - SmartShutdown disabled
  - Allow disruption (this facilitates node rotation durring the maintenance windows)
- Resource Quotas:
  - Minimal implementation of ResourceQuota
  - Minimal implementation of LimitRange
- Prometheus Pod monitoring:
  - Minimal odoo implementation
  - Minimal nx implementation
  - Minimal cnpg implementation

## *0.3.2*

Features:

- New Autoscaler (Keda)
- New ingress available (Istio)
- Istio:
  - Ingress:
    - Enable istio as ingress (`ingress.istio.enabled`)
    - Client domains list (`ingress.istio.altHosts`) new cloud domain (`ingress.istio.cloudMainDomain`)
  - Egress: now we can block outgoing traffick by default (`ingress.istio.blockOutboundTraffic: false`) and allow only thats ones in a white list (`ingress.istio.allowedHosts: false`)
- Keda: (`autoscaling.keda.enabled` )
  - Http autoscaler, works with istio and nginx as ingress. (Allowing scale to 0 `autoscaling.minReplicas`)
- Common:
  - Remove unused values
  - priorityClass: to warranties critical features and production environments
- FUSE:
  - Reducing de requested resources
  - Disable "streaming writes" to avoid the creation of empty files
- Odoo:
  - New environment variable: `RELEASE_DIGEST` with the value computed from the image and all odoo settings
  - Remove "history" labels on deploy
  - PDB: allow maxUnavailable to improve eviction
- CNPG:
  - Change anti-affinity to avoid deploy several pg in the same node.
- Reverse Proxy:
  - PDB: allow maxUnavailable to improve eviction  

## *0.3.1*

Features:

- odoo:
  - Added pdb
  - Fixed report.url conf
  - Improved affinity selectors
  - Added "changeCause"
- reverse Proxy:
  - Added pdb
  - Added some rules to prevent scans
  - Added node affinity
- cnpg:
  - option to disable ro services
  - option to enable exposed service

Improvements:

- rolling mechanism:
  - now depends of the odoo version and some key config
  - now we use the same mechanism for nx and odoo

- rolling strategy:
  - set maxSurge to 1 to grant pdb (avoiding noDecisionStatus.noScaleDown issues)
  - set maxUnavailable to 0 (or 1 for deployments with multiple replicas for fast deployments)

BugFixes:

- adhoc.ar/service-level: Fix typos
- extraEnvs is a shared config now
- reverse Proxy:
  - add missing nodeSelector (used by fuse)

## *0.3.0*

Features:

- odoo:
  - default readiness, liveness and startup probes updated
- cnpg:
  - add pg_stat_statements to shared preload libraries
- reverse Proxy:
  - add nginx to serve files
    - `ingress.reverseProxy.enabled`
    - `ingress.reverseProxy.scale`

## *0.2.9*

Features:

- CNPG:
  - NetworkPolicy: pg only can be reached from the same namespace
  - Superuser: able to set superuser password
  - Restore: now we able to restore from GCP snapchot `cloudNativePG.restore.fromGCPSnapshot`
- ODOO:
  - Envvars: now we use a ConfigMap to store the envvars

## *0.2.8*

Features:

- Add ODOO_INITIAL_LANGUAGE envvar and its question `odoo.basic.language`

Note: **NOT ready for CNPG**

## *0.2.7*

Features:

- Add support for FUSE bucket volumes (Only for GCP) `storage.location='fuse'`
  (This feature requires CSI Fuse driver enabled on GKE Cluster and GKE Metadata enabled on node_pools )

## *0.2.6*

Features:

- CloudNative Volume Snapshots [+info](https://cloudnative-pg.io/documentation/1.22/backup/#object-stores-or-volume-snapshots-which-one-to-use) [+info](https://cloudnative-pg.io/documentation/1.22/backup_volumesnapshot/)
- Add new questions for pullSecret and CloudNativePG

## *0.2.5*

Features:

- Remove the WebSocket service when no workers are present.
- Add `devMode` to disable the entrypoint, liveness, and readiness probes.
- Make Ingress configuration snippets optional (enable with `configurationSnippet.enabled`).
- Add support for additional environment variables for the Odoo container (`odoo.extraEnvVars`).
- Add new app tye annotation: `adhoc.appType` (prod, test, etc)
- Add initial support for Cloud-Native-pg (**CloudNativePG operator** must be installed before [+info](https://github.com/cloudnative-pg/charts))

## *0.2.4*

Features:

- Add configuration-snippet with some security improvements
- Add new service level annotation: `adhoc.serviceLevel` (standard, advanced, premium)
- Add new labels:
  - `adhoc.ar/service-level`: Adhoc Service level (standard, advanced, premium)
  - `adhoc.ar/tier`: Tier (prod, test, etc)
  - `adhoc.ar/odoo-version`: Odoo base version (`17.0`, `18.0`)
- Remove warning on "Skipped a TLS block"

## *0.2.3*

Features:

- Add "Managed pull secret" (DockerHub credentials for odoo)
- Initial support for minikube
- Update ingressClassName
- Fix HelmApp Version
