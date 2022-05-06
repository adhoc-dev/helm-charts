# PG

App de PG para Odoo by Adhoc.  
IMPORTANTE: configurar en GCP > Discos > Programación de instantáneas (ver activa, actualmente es snap-us-east-1-nubeadhoc-v2)

## Parámetros

```yml
Name: PGs Principales
    Args:
      postgres
      -p 5432
      --max_connections=2000
      --shared_buffers=10GB
      --work_mem=18MB
      --effective_cache_size=30GB
      --max_parallel_workers_per_gather=2
      --min_wal_size=1GB
      --max_wal_size=4GB
      --effective_io_concurrency=200
      --maintenance_work_mem=1920MB
      --max_worker_processes=4
      --max_parallel_workers=4
      --max_parallel_maintenance_workers=1
      --random_page_cost=1.1
      --checkpoint_completion_target=0.9
      --wal_buffers=256MB
      --shared_preload_libraries=pg_stat_statements
      --default_statistics_target=100
      --pg_stat_statements.max=10000
      --pg_stat_statements.track=all
    Requests:
      cpu:      3
      memory:   50Gi

Name: PGs Intermedios
    Args:
      postgres
      -p 5432
      --max_connections=1100
      --shared_buffers=5GB
      --work_mem=18MB
      --effective_cache_size=15GB
      --max_parallel_workers_per_gather=1
      --min_wal_size=1GB
      --max_wal_size=4GB
      --effective_io_concurrency=200
      --maintenance_work_mem=1920MB
      --max_worker_processes=2
      --max_parallel_workers=2
      --max_parallel_maintenance_workers=1
      --random_page_cost=1.1
      --checkpoint_completion_target=0.9
      --wal_buffers=256MB
      --shared_preload_libraries=pg_stat_statements
      --default_statistics_target=100
      --pg_stat_statements.max=10000
      --pg_stat_statements.track=all
    Requests:
      cpu:      2
      memory:   25Gi
```
