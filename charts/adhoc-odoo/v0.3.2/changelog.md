# Version changes

## *0.3.2*

Features:

- New Autoscaler (Keda)
- New ingress available (Istio)
- Istio:
  - ingress:
    - new ingress (`ingress.istio.enabled`)
    - client domains list (`ingress.istio.altHosts`) new cloud domain (`ingress.istio.cloudMainDomain`)
  - egress: now we can block outgoing traffick by default (`ingress.istio.blockOutboundTraffic: false`) and allow only thats ones in a white list (`ingress.istio.allowedHosts: false`)
- Keda:
  - When the autoscaler is enabled with istio, keda autoscaler is used instead the "regular" hpa
- Common:
  - remove unused values

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
