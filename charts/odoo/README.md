# Odoo

[Odoo](https://www.odoo.com/) is a suite of web-based open source business apps. The main Odoo Apps include an Open Source CRM, Website Builder, eCommerce, Project Management, Billing & Accounting, Point of Sale, Human Resources, Marketing, Manufacturing, Purchase Management, ...

Odoo Apps can be used as stand-alone applications, but they also integrate seamlessly so you get a full-featured Open Source ERP when you install several Apps.

## TL;DR

```console
$ helm repo add bitnami https://charts.bitnami.com/bitnami
$ helm install my-release bitnami/odoo
```

## Introduction

This chart bootstraps a [Odoo](https://github.com/ganar-gan-ar/docker-odoo-02-odoo) deployment on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

This chart has been tested to work with NGINX Ingress, cert-manager, fluentd and Prometheus on top of [Rancher](http://rancher.com/).

## Prerequisites

- Kubernetes 1.12+
- Helm 3.1.0
- PV provisioner support in the underlying infrastructure
- ReadWriteMany volumes for deployment scaling

## Installing the Chart

To install the chart with the release name `my-release`:

```console
$ helm install my-release ganar-gan-ar/odoo
```

The command deploys Odoo on the Kubernetes cluster in the default configuration. The [Parameters](#parameters) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list`

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```console
$ helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Parameters

The following table lists the configurable parameters of the Odoo chart and their default values.

| Parameter                 | Description                                     | Default                                                 |
|---------------------------|-------------------------------------------------|---------------------------------------------------------|
| `global.imageRegistry`    | Global Docker image registry                    | `nil`                                                   |
| `global.imagePullSecrets` | Global Docker registry secret names as an array | `[]` (does not add image pull secrets to deployed pods) |
| `global.storageClass`     | Global storage class for dynamic provisioning   | `nil`                                                   |

### Deployment & common parameters

| Parameter                            | Description                                                                                       | Default                                                 |
|--------------------------------------|---------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| `image.registry`                     | Odoo image registry                                                                               | `docker.io`                                             |
| `image.repository`                   | Odoo Image name                                                                                   | `ganarganar/odoo-02-odoo`                               |
| `image.tag`                          | Odoo Image tag                                                                                    | `13.0`                                                  |
| `image.pullPolicy`                   | Image pull policy                                                                                 | `IfNotPresent`                                          |
| `image.pullSecrets`                  | Specify docker-registry secret names as an array                                                  | `[]` (does not add image pull secrets to deployed pods) |
| `hostAliases`                        | Add deployment host aliases                                                                       | `[]`                                                    |
| `nameOverride`                       | String to partially override odoo.fullname template with a string (will prepend the release name) | `nil`                                                   |
| `kubeVersion`                        | Force target Kubernetes version (using Helm capabilities if not set)                              | `nil`                                                   |
| `fullnameOverride`                   | String to fully override odoo.fullname template with a string                                     | `nil`                                                   |
| `commonAnnotations`                  | Annotations to be added to all deployed resources                                                 | `{}` (evaluated as a template)                          |
| `commonLabels`                       | Labels to be added to all deployed resources                                                      | `{}` (evaluated as a template)                          |
| `extraVolumeMounts`                  | Optionally specify extra list of additional volumeMounts for odoo container                       | `[]`                                                    |
| `extraVolumes`                       | Optionally specify extra list of additional volumes for odoo container                            | `[]`                                                    |
| `persistence.enabled`                | Enable persistence using PVC                                                                      | `true`                                                  |
| `persistence.existingClaim`          | Enable persistence using an existing PVC                                                          | `nil`                                                   |
| `persistence.storageClass`           | PVC Storage Class                                                                                 | `nil` (uses alpha storage class annotation)             |
| `persistence.accessMode`             | PVC Access Mode                                                                                   | `ReadWriteOnce`                                         |
| `persistence.size`                   | PVC Storage Request                                                                               | `8Gi`                                                   |
| `podAffinityPreset`                  | Pod affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`               | `""`                                                    |
| `podAntiAffinityPreset`              | Pod anti-affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`          | `soft`                                                  |
| `nodeAffinityPreset.type`            | Node affinity preset type. Ignored if `affinity` is set. Allowed values: `soft` or `hard`         | `""`                                                    |
| `nodeAffinityPreset.key`             | Node label key to match Ignored if `affinity` is set.                                             | `""`                                                    |
| `nodeAffinityPreset.values`          | Node label values to match. Ignored if `affinity` is set.                                         | `[]`                                                    |
| `affinity`                           | Affinity for pod assignment                                                                       | `{}` (evaluated as a template)                          |
| `nodeSelector`                       | Node labels for pod assignment                                                                    | `{}` (evaluated as a template)                          |
| `tolerations`                        | Tolerations for pod assignment                                                                    | `[]` (evaluated as a template)                          |
| `podSecurityContext.enabled`         | Enable security context for Odoo pods                                                             | `true`                                                  |
| `podSecurityContext.fsGroup`         | Group ID for the volumes of the pod                                                               | `1001`                                                  |
| `containerSecurityContext.enabled`   | Odoo Container securityContext                                                                    | `false`                                                 |
| `containerSecurityContext.runAsUser` | User ID for the Odoo container                                                                    | `1001`                                                  |
| `initContainers`                     | Add additional init containers to the Odoo pods                                                   | `{}` (evaluated as a template)                          |
| `sidecars`                           | Add additional sidecar containers to the Odoo pods                                                | `{}` (evaluated as a template)                          |

### Service parameters

| Parameter                       | Description                          | Default        |
|---------------------------------|--------------------------------------|----------------|
| `service.type`                  | Kubernetes Service type              | `NodePort`     |
| `service.port`                  | Service HTTP port                    | `80`           |
| `service.loadBalancer`          | Kubernetes LoadBalancerIP to request | `nil`          |
| `service.externalTrafficPolicy` | Enable client source IP preservation | `Cluster`      |
| `service.nodePort`              | Kubernetes http node port            | `""`           |

### Odoo parameters

| Parameter                            | Description                                                        | Default                                        |
|--------------------------------------|--------------------------------------------------------------------|------------------------------------------------|
| `odooPassword`                       | Master password                                                    | _random 16 character long alphanumeric string_ |
| `workers`                            | Number of workers                                                  | 2                                              |
| `maxCronThreads`                     | Number of cron workers                                             | 1                                              |
| `dbMaxConn`                          | Max number of db conns. Change it after change nº of workers       | 6                                              |
| `limitMemoryHard`                    | Master password                                                    | 1395864371                                     |
| `limitMemorySoft`                    | Master password                                                    | 530242876                                      |
| `dbFilter`                           | Master password                                                    | ^%d$                                           |
| `listDb`                             | Wheter list databases or not                                       | `false`                                        |
| `withoutDemo`                        | Disable Odoo modules demo data ('', 'all' or comma-separated list) | `all`                                          |
| `smtpHost`                           | SMTP host                                                          | `nil`                                          |
| `smtpPort`                           | SMTP port                                                          | `nil`                                          |
| `smtpUser`                           | SMTP user                                                          | `nil`                                          |
| `smtpPassword`                       | SMTP password                                                      | `nil`                                          |
| `smtpProtocol`                       | SMTP protocol [`ssl`, `tls`]                                       | `nil`                                          |
| `existingSecret`                     | Name of a secret with the application password                     | `nil`                                          |
| `resources`                          | CPU/Memory resource requests/limits                                | Memory: `512Mi`, CPU: `500m`                   |
| `livenessProbe.enabled`              | Enable/disable the liveness probe                                  | `true`                                         |
| `livenessProbe.initialDelaySeconds`  | Delay before liveness probe is initiated                           | 300                                            |
| `livenessProbe.periodSeconds`        | How often to perform the probe                                     | 30                                             |
| `livenessProbe.timeoutSeconds`       | When the probe times out                                           | 5                                              |
| `livenessProbe.failureThreshold`     | Minimum consecutive failures to be considered failed               | 6                                              |
| `livenessProbe.successThreshold`     | Minimum consecutive successes to be considered successful          | 1                                              |
| `readinessProbe.enabled`             | Enable/disable the readiness probe                                 | `true`                                         |
| `readinessProbe.initialDelaySeconds` | Delay before readinessProbe is initiated                           | 30                                             |
| `readinessProbe.periodSeconds   `    | How often to perform the probe                                     | 10                                             |
| `readinessProbe.timeoutSeconds`      | When the probe times out                                           | 5                                              |
| `readinessProbe.failureThreshold`    | Minimum consecutive failures to be considered failed               | 6                                              |
| `readinessProbe.successThreshold`    | Minimum consecutive successes to be considered successful          | 1                                              |
| `customLivenessProbe`                | Override default liveness probe                                    | `nil`                                          |
| `customReadinessProbe`               | Override default readiness probe                                   | `nil`                                          |
| `command`                            | Custom command to override image cmd                               | `nil` (evaluated as a template)                |
| `args`                               | Custom args for the custom command                                 | `nil` (evaluated as a template)                |
| `extraEnvVars`                       | An array to add extra env vars                                     | `[]` (evaluated as a template)                 |
| `extraEnvVarsCM`                     | Array to add extra configmaps                                      | `[]`                                           |
| `extraEnvVarsSecret`                 | Array to add extra environment from a Secret                       | `nil`                                          |

### Ingress parameters

| Parameter                        | Description                                                   | Default                        |
|----------------------------------|---------------------------------------------------------------|--------------------------------|
| `ingress.enabled`                | Enable ingress controller resource                            | `true`                         |
| `ingress.certManager`            | Add annotations for cert-manager                              | `true`                         |
| `ingress.hostname`               | Default host for the ingress resource                         | `demo.ganargan.ar`             |
| `ingress.path`                   | Default path for the ingress resource                         | `/`                            |
| `ingress.longpollingPath`        | Default path for the longpolling ingress resource             | `/longpolling`                 |
| `ingress.tls`                    | Create TLS Secret                                             | `true`                         |
| `ingress.annotations`            | Ingress annotations                                           | `[]` (evaluated as a template) |
| `ingress.extraHosts[0].name`     | Additional hostnames to be covered                            | `nil`                          |
| `ingress.extraHosts[0].path`     | Additional hostnames to be covered                            | `nil`                          |
| `ingress.apiVersion`             | Force Ingress API version (automatically detected if not set) | ``                             |
| `ingress.extraPaths`             | Additional arbitrary path/backend objects                     | `nil`                          |
| `ingress.extraTls[0].hosts[0]`   | TLS configuration for additional hostnames to be covered      | `nil`                          |
| `ingress.extraTls[0].secretName` | TLS configuration for additional hostnames to be covered      | `nil`                          |
| `ingress.secrets[0].name`        | TLS Secret Name                                               | `nil`                          |
| `ingress.secrets[0].certificate` | TLS Secret Certificate                                        | `nil`                          |
| `ingress.secrets[0].key`         | TLS Secret Key                                                | `nil`                          |
| `ingress.pathType`               | Ingress path type                                             | `ImplementationSpecific`       |

### Database parameters

| Parameter                             | Description                               | Default                                     |
|---------------------------------------|-------------------------------------------|---------------------------------------------|
| `postgresql.enabled`                  | Deploy PostgreSQL container(s)            | `false`                                     |
| `postgresql.postgresqlPassword`       | PostgreSQL password                       | `nil`                                       |
| `postgresql.persistence.enabled`      | Enable PostgreSQL persistence using PVC   | `true`                                      |
| `postgresql.persistence.storageClass` | PVC Storage Class for PostgreSQL volume   | `nil` (uses alpha storage class annotation) |
| `postgresql.persistence.accessMode`   | PVC Access Mode for PostgreSQL volume     | `ReadWriteOnce`                             |
| `postgresql.persistence.size`         | PVC Storage Request for PostgreSQL volume | `8Gi`                                       |
| `externalDatabase.host`               | Host of the external database             | `localhost`                                 |
| `externalDatabase.user`               | Existing username in the external db      | `odoo`                                      |
| `externalDatabase.password`           | Password for the above username           | `nil`                                       |
| `externalDatabase.database`           | Name of the existing database             | `prod`                                      |
| `externalDatabase.port`               | Database port number                      | `5432`                                      |

The above parameters map to the env variables defined in [ganarganar/odoo-01-base](https://github.com/ganar-gan-ar/docker-odoo-01-base/). For more information please refer to the [ganarganar/odoo-01-base](https://github.com/ganar-gan-ar/docker-odoo-01-base/) image documentation.

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```console
$ helm install my-release \
  --set odooPassword=password,postgresql.postgresPassword=secretpassword \
    ganar-gan-ar/odoo
```

The above command sets the Odoo administrator account password to `password` and the PostgreSQL `postgres` user password to `secretpassword`.

> NOTE: Once this chart is deployed, it is not possible to change the application's access credentials, such as usernames or passwords, using Helm. To change these application credentials after deployment, delete any persistent volumes (PVs) used by the chart and re-deploy it, or use the application's built-in administrative tools if available.

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
$ helm install my-release -f values.yaml ganar-gan-ar/odoo
```

> **Tip**: You can use the default [values.yaml](values.yaml)

## Configuration and installation details

### [Rolling VS Immutable tags](https://docs.bitnami.com/containers/how-to/understand-rolling-tags-containers/)

It is strongly recommended to use immutable tags in a production environment. This ensures your deployment does not change automatically if the same tag is updated with a different image.

Bitnami will release a new chart updating its containers if a new version of the main container, significant changes, or critical vulnerabilities exist.

### Change Odoo version

To modify the Odoo version used in this chart you can specify a [valid image tag](https://hub.docker.com/repository/docker/ganarganar/odoo-02-odoo/tags) using the `image.tag` parameter. For example, `image.tag=X.Y.Z`. This approach is also applicable to other images like exporters.

### Using an external database

Sometimes you may want to have Odoo connect to an external database rather than installing one inside your cluster, e.g. to use a managed database service, or use a single database server for all your applications. To do this, the chart allows you to specify credentials for an external database under the [`externalDatabase` parameter](#parameters). You should also disable the PostgreSQL installation with the `postgresql.enabled` option. For example using the following parameters:

```console
postgresql.enabled=false
externalDatabase.host=myexternalhost
externalDatabase.user=myuser
externalDatabase.password=mypassword
externalDatabase.port=3306
```

Note also if you disable PostgreSQL per above you MUST supply values for the `externalDatabase` connection.

### Sidecars and Init Containers

If you have a need for additional containers to run within the same pod as Odoo, you can do so via the `sidecars` config parameter. Simply define your container according to the Kubernetes container spec.

```yaml
sidecars:
  - name: your-image-name
    image: your-image
    imagePullPolicy: Always
    ports:
      - name: portname
       containerPort: 1234
```

Similarly, you can add extra init containers using the `initContainers` parameter.

### Setting Pod's affinity

This chart allows you to set your custom affinity using the `affinity` parameter. Find more information about Pod's affinity in the [kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity).

As an alternative, you can use of the preset configurations for pod affinity, pod anti-affinity, and node affinity available at the [bitnami/common](https://github.com/bitnami/charts/tree/master/bitnami/common#affinities) chart. To do so, set the `podAffinityPreset`, `podAntiAffinityPreset`, or `nodeAffinityPreset` parameters.

## Persistence

The [Ganar Ganar Odoo](https://github.com/ganar-gan-ar/docker-odoo-01-base) image stores the Odoo data and configurations at the `/opt/odoo` path of the container.

Persistent Volume Claims are used to keep the data across deployments. This is known to work in GCE, AWS, and minikube.
See the [Parameters](#parameters) section to configure the PVC or to disable persistence.

## Troubleshooting

TO-DO.