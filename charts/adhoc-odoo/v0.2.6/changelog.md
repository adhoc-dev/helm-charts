# Version changes

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
- Add new service level annotation: `adhoc.serviceLevel` (standard, advance, premium)
