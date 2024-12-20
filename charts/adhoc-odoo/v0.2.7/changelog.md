# Version changes

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
- Add support for additional environment variables for the Odoo container (`extraEnvVars`).
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