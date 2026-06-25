# Control de egress (Istio)

Control del tráfico **saliente** de un tenant Odoo vía Istio. Diseño y rationale
completos en la spec `devops-project` (firewall de egress, iteración 2); este doc es la
referencia operativa del chart.

Solo aplica con `ingress.istio.enabled: true`. Sin Istio, el modo efectivo es `open` y
ningún recurso de egress se renderiza.

## Modos

`ingress.istio.egress.mode: open | observe | enforce`

| Modo | Sidecar | Logging | Bloqueo |
| --- | --- | --- | --- |
| `open` | `ALLOW_ANY` | no | no |
| `observe` (default) | `ALLOW_ANY` | sí (SNI → Cloud Logging) | no |
| `enforce` | `REGISTRY_ONLY` | sí (hereda observe) | sí: solo `allowedHosts`/443; no-TLS y no-meshed bloqueados |

**Modo efectivo** (helper `adhoc-odoo.egressMode`), por precedencia:

1. `ingress.istio.egress.mode` explícito.
2. Flags legacy (deprecados): `blockOutboundTraffic: true` → `enforce`; `logEgress: true` → `observe`.
3. Default con `istio.enabled` → `observe`.

## Values

| Value | Aplica en | Qué hace |
| --- | --- | --- |
| `ingress.istio.egress.mode` | — | Modo (ver arriba). Vacío → `observe` con Istio. |
| `ingress.istio.allowedHosts` | `enforce` | Hosts externos extra alcanzables (un `ServiceEntry` 443/HTTPS por host). Se puebla desde el inventario del modo `observe`. |
| `ingress.istio.egress.repoHosts` | `enforce` | Hosts que el boot necesita para clonar repos custom. Se agregan a la whitelist **solo** si `odoo.entrypoint.repos` no está vacío. Default: trío github; sobreescribir si los repos viven en otro host. |
| `ingress.istio.egress.meshExternalNamespaces` | `enforce` | Namespaces cluster-level que Odoo usa cross-namespace (redis, aeroo, kwkhtmltopdf). Bajo `REGISTRY_ONLY` hay que incluirlos en el scope del `Sidecar` o se bloquean. |
| `ingress.istio.egress.networkPolicy.allow` | `enforce` | CIDRs privados extra para los pods NO-meshed, además de los baked-in. Normalmente vacío. |

## Cómo bloquea `enforce`

Dos capas, según el tipo de pod:

- **Pods inyectados (Odoo) — sidecar `REGISTRY_ONLY`.** Solo los hosts con `ServiceEntry`
  (`allowedHosts` + `repoHosts`) son alcanzables; el sidecar sale **directo** a ellos (sin
  egress gateway). Como solo se declaran ServiceEntries en 443/HTTPS, el no-TLS (HTTP/80,
  TCP plano) y todo host fuera de la lista quedan bloqueados (deny-by-default).
- **Pods NO inyectados (PostgreSQL/CNPG, jobs) — `NetworkPolicy`.** No tienen sidecar y
  saldrían directo por el NAT. La policy los selecciona (`security.istio.io/tlsMode`
  `DoesNotExist`) y permite **solo destinos privados** (RFC1918 + link-local:
  `10/8`, `172.16/12`, `192.168/16`, `169.254/16`), denegando el público.

El rango privado cubre de una pods/services, API server GKE (`172.16/12`), NodeLocal
DNSCache + metadata server (`169.254/16`), istio-system y los namespaces cluster-level.

## Logging (observe y enforce)

- `EnvoyFilter` `egress-sni-inspector`: inserta el `tls_inspector` en `virtualOutbound`.
  Sin él, el egress TLS en passthrough se loguea como TCP y el campo `sni` queda vacío.
- `Telemetry` `access-logging-egress`: loguea el tráfico del workload como `CLIENT`
  (outbound) con el provider `envoy` (JSON + `sni`, configurado a nivel mesh).
- En `enforce` el logging se hereda para **ver qué cae bloqueado** (`upstream_cluster:
  BlackHoleCluster`) y refinar las listas.
- Acotar volumen/costo: se puede sumar un filtro CEL a la `Telemetry` (p. ej.
  `xds.cluster_name == "PassthroughCluster"`) — validar la expresión contra la versión de
  Istio del cluster.

## Gotchas

- **DNS en GKE va por NodeLocal DNSCache (`169.254.20.10`, link-local)**, no por el
  ClusterIP de kube-dns. El rango `169.254/16` de la NetworkPolicy lo cubre; sin él,
  `enforce` rompe todo el DNS de los pods no-meshed.
- **CNPG no se inyecta** (rompe el operador) — su egress lo cubre la NetworkPolicy.
- `egress.repoHosts` trae el default github **en el template** (no solo en `values.yaml`)
  para que aplique también bajo `helm upgrade --reuse-values`, donde los defaults nuevos
  de `values.yaml` no se mergean.
- Listas vacías + sin repos en `enforce` → 0 ServiceEntries → todo egress externo
  bloqueado (deny-by-default). Poblá `allowedHosts` desde el inventario antes de pasar a
  `enforce`.
