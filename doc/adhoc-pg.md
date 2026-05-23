# Chart: adhoc-pg

Chart Helm para PostgreSQL standalone (sin CNPG operator). Alternativa/legacy al CNPG embebido en `adhoc-odoo`. Versión actual: `0.20.3`.

> Para instancias nuevas, preferir `cloudNativePG` en `adhoc-odoo`. Este chart se mantiene para compatibilidad.

## Configuración principal

```yaml
image:
  repository: postgres
  tag: "15"

pg:
  data: ""
  db: "postgres"
  user: "odoo"
  pass: ""
  port: 5432
  args:
    logLinePrefix: '[%u %d] [%p]'
    logMinDurationStatement: 600000   # ms — loguea queries lentas
    maxConn: 2000
    workMem: 18MB
    ecs: 30GB
    sharedBuffers: 10GB               # opcional
    maxParallelWorkersPerGather: 2

resources:
  requests:
    cpu: 3000m
    memory: 50Gi
  # Sin limits de CPU/mem en PG (buena práctica)

nodeTag: "pg"    # nodo dedicado para PG
```

## Notas operativas

- **Sin límites de CPU/memoria en PG** — intencional. Definir `requests` para visibilidad de scheduling.
- **Snapshot GCP:** activar política de snapshots en GCP → Discos → "Programación de instantáneas" (actualmente `snap-us-east-1-nubeadhoc-v2`).
- `nodeTag: "pg"` requiere nodos con la label correspondiente en el cluster.
- Changelog reciente: `0.20.3` — cronjobs movidos al mismo nodo que PG.
