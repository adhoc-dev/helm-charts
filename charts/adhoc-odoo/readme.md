# Odoo by Adhoc

## Odoo Envvars

| Name | Description | is Mandatory | Default | Related Value |
| --- | --- | --- | --- | --- |
| ADHOC_ODOO_STORAGE_MODE | attachment_s3, native, fuse |  | | storage.location |

### ADHOC_ODOO_STORAGE_MODE

Type: enum  
Posible values: attachment_s3, native, fuse  
Default: native

## Notes

### Fuse

[Options](https://github.com/GoogleCloudPlatform/gcsfuse/blob/master/docs/semantics.md)

### CNPG

[DOC](https://cloudnative-pg.io/documentation/1.27/)
[Cluster Spec](https://cloudnative-pg.io/documentation/1.27/cloudnative-pg.v1/#postgresql-cnpg-io-v1-ClusterSpec)
[PDB](https://cloudnative-pg.io/documentation/1.27/kubernetes_upgrade/#pod-disruption-budgets)

#### PG

[VACUUM](https://www.postgresql.org/docs/16/runtime-config-autovacuum.html)
