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

---

## adhoc-cluster-sentinel

Plataforma de supervisión del cluster: corre checks enchufables que detectan recursos
"sanos para Kubernetes pero rotos de verdad" y, según el check, actúan o sólo miden.
Código en `devops-ops-tools/clusterSentinel`; instalado por Pulumi en cada cell.

### RBAC — qué permiso pide cada check y por qué

| Permiso | Alcance | Check |
| --- | --- | --- |
| `pods: list, delete` | ClusterRole | El trabajo base: detectar y recrear pods rotos. |
| `persistentvolumeclaims`, `persistentvolumes: get, list` | ClusterRole | `pv-zone-stuck` — el pod no dice en qué zona quedó clavado; eso está en el PV. `list` es de `cnpg-resize-stuck`, que barre los PVC buscando la condition de resize. |
| `nodes: list, patch` | ClusterRole | `node-memory-pressure` — `list` para probar que existe un destino antes de mover nada; `patch` es el cordon del nodo de origen. |
| `replicasets: get`, `deployments: get, patch` | ClusterRole | `node-memory-pressure` — resolver pod → Deployment, leer la estrategia real de rollout y hacer el restart. |
| `secrets: list` | ClusterRole | `helm-release-stuck` — el estado de un release de Helm vive en un Secret. |
| `clusters: list` (`postgresql.cnpg.io`) | ClusterRole | `cnpg-resize-stuck` — sólo el CR dice si la base está hibernada y en qué phase está el Cluster. |
| `jobs: list` | **Role en `helmJobs.namespace`** | `helm-release-stuck` — un Job de Helm vivo distingue "operación en curso" de "abandonada". |

#### `secrets: list` es cluster-wide, y es la decisión sensible

El storage driver de Helm es un Secret con labels `owner`/`name`/`status`/`version`, así
que es la única forma de saber qué releases quedaron a mitad de una operación. El check
lo pide con un selector de estado pendiente y en la práctica recibe un puñado de objetos,
pero el **verbo** no distingue: alcanza los values de todos los releases del cluster, que
pueden incluir credenciales.

No se puede acotar por namespace sin pagar caro: los releases viven en el namespace de
cada base, así que haría falta reconciliar un RoleBinding por base, y las bases nacen y
mueren todo el tiempo. `resourceNames` en RBAC tampoco sirve — no aplica a `list`.

La alternativa que sí lo eliminaría es exponer los labels de los Secrets vía
kube-state-metrics (`metricLabelsAllowlist=secrets=[owner,name,status,version]`) y que el
check lea el estado desde Prometheus: KSM lee metadata y nunca el campo `data`, así que el
centinela no necesitaría ningún permiso sobre secrets. El costo son ~6k series nuevas,
contra el presupuesto de `devops-cloud-infra/doc/observability/cardinality-budget.md`.
Queda planteada, no tomada.

#### `jobs: list` sí está acotado

Todos los Jobs de Helm del provider viven en un solo namespace (`devops`, donde los crea
`pylib_odoo_saas`), así que el permiso va en un Role + RoleBinding ahí y no en el
ClusterRole.

**Requerimiento:** ese namespace tiene que existir al instalar — el chart no lo crea. Con
`helmJobs.namespace: ""` no se renderiza el Role y el check pierde esa guarda: pasa a
reportar de más (un release pendiente de larga duración se ve como abandonado), nunca de
menos.

El value decide **dónde se crea el Role**, no dónde mira el check: eso es
`helm_jobs_namespace`, un default de clase como el resto de los knobs por-check. Los dos
tienen que coincidir.

#### `clusters: list` de CNPG: por qué el CR y no los pods

`cnpg-resize-stuck` necesita saber si la base está **hibernada**, y ése es justamente el
caso en el que el pod de la instancia no existe: no hay nada que mirar del lado de los
pods. La annotation `cnpg.io/hibernation` y la phase del Cluster viven en el CR y en
ningún otro lado.

El proxy que usa la alerta —el Deployment de odoo en 0 réplicas— no sirve acá: medido el
2026-08-20, los 8 namespaces de cell02 con odoo dormido tenían igual su instancia de CNPG
viva. Dormir odoo no hiberna la base, así que para distinguir "hibernada" de "deadlock"
hace falta el CR. Es `list` read-only sobre un CRD.
