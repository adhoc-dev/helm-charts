# adhoc-way-instance

Ephemeral per-user instance of the "way" platform: a pod with a third-party web
tool (an IDE / agent UI) and the `adhocwayAuthProxy` sidecar that only lets the
owning user in. Requires [`adhoc-way-platform`](../adhoc-way-platform) in the same
namespace.

## What it installs

- Deployment with **2 containers**: `auth-proxy` (the only exposed port) + `tool` (reached only over loopback inside the pod; no Service port).
- Service (only the proxy port) · Istio VirtualService (`{host}` → platform gateway) · NetworkPolicy.

## Install (one per user, release = host prefix)

The chart defaults run **openCode**, so the orchestrator passes only the host and
the owning user:

```sh
helm install <prefix> charts/adhoc-way-instance -n <ns> \
  --set host=<prefix>.<platform-domain> \
  --set user.id=<user-id> --set user.email=<user-email>
```

The tool image/port/env and its public-URL env (`OPENCODE_PUBLIC_URL`, derived
from `host`) are preset. Override `tool.*` to run a different tool.

> Only the auth-proxy is exposed in the Service; the tool is reached over
> `127.0.0.1` inside the pod. Prefer a tool that binds loopback (anti-bypass) —
> either way the Service + NetworkPolicy keep the tool off the network.

## User state: one volume per USER, not per instance

An instance is a **user × surface** pair; the state is not. A user may open more
than one surface and **all of them must see the same files**.

So the claim is named after the **user** (`way-user-<id>`, derived from
`user.id`), not after the release, and any surface of that user creates it if it
is not there yet. The second surface finds the same claim and mounts it. Nothing
extra to install:

```sh
helm install <prefix> adhoc-dev/adhoc-way-instance -n <ns> \
  --set host=<prefix>.<platform-domain> \
  --set user.id=<id> --set user.email=<email>
```

It mounts on `/home/odoo`, where everything the user owns lives: agent state in
dotfiles and projects in `workspace/`. One mount, nothing else to wire.

**The volume outlives the surface.** It carries `helm.sh/resource-policy: keep`,
so uninstalling a surface — even the one that happened to create it — leaves the
files alone. Deleting them for real is a deliberate `kubectl delete pvc`. There is
no backup of this data, so that asymmetry is on purpose.

Verified on a live cluster: first surface creates the claim, second surface of the
same user reuses it without duplicating or failing, `helm upgrade` does not touch
it, and `helm uninstall` of the surface that created it leaves it Bound.

Four things worth knowing:

- **The installing identity needs `get` on claims, not only `create`.** Helm's
  `lookup` returns empty when it may not read — it does not fail — so a missing
  permission looks exactly like "the claim is not there", and the create that
  follows dies with an ownership error that never mentions permissions.
- **`lookup` is blind without a cluster**, so `helm template` and `--dry-run`
  render the claim even when it already exists. What CI validates is not what gets
  applied.
- **`podSecurityContext.fsGroup` must match the group of the tool image's user**
  (`1001` for `adhocWayWorkspace`). A freshly provisioned disk belongs to root, so
  without it the pod starts and dies unable to write its own home.
- **`state.subPath`** (default `home`) mounts a subdirectory instead of the volume
  root: the same disk can hold more than one thing later, and the filesystem's
  `lost+found` stays out of the user's home.

`state.persistent=false` swaps the claim for an `emptyDir` — fine for a smoke
test, wrong for a person.

### Two surfaces at the same time

`ReadWriteOnce` does **not** mean "one pod". It means one *node*: several pods can
mount the volume as long as they are scheduled together.

| Situation | Works with ReadWriteOnce |
|---|---|
| One surface at a time | yes |
| Two surfaces, co-scheduled on one node | yes |
| Two surfaces on different nodes, at once | **no** — needs a ReadWriteMany class |

Co-scheduling is a scheduling constraint, not a guarantee: if the node has no room
the second surface stays `Pending`. Decide this before promising simultaneous
surfaces to users.

## Main values

| Key | Default | Description |
|---|---|---|
| `host` | `""` (required) | pod FQDN, `<prefix>.<platform-domain>` |
| `state.persistent` | `true` | `false` swaps the user's claim for an ephemeral `emptyDir` |
| `state.claimName` | `""` | defaults to `way-user-<user.id>` |
| `state.create` | `true` | create the claim when missing (needs `get` on claims) |
| `state.size` | `1Gi` | only used when creating it |
| `state.mountPath` / `state.subPath` | `/home/odoo` / `home` | where the user's volume lands |
| `podSecurityContext.fsGroup` | `1001` | must match the tool image's user group |
| `user.id` / `user.email` | `""` | owning user (annotations) |
| `tool.image.tag` | `open-code-server-20260701-1` | tool image (default: openCode) |
| `tool.port` | `4096` | tool localhost port |
| `tool.publicUrlEnvVar` | `PUBLIC_URL` | env for the tool's public URL (`https://<host>`); `""` to skip |
| `authProxy.maxEntryTtl` | `10m` | max entry-token lifetime the proxy accepts |
| `authProxy.entryPubKeyConfigMap` | `adhoc-way-platform-entry-pubkey` | platform ConfigMap |
| `ingress.istio.gateway` | `adhoc-way-platform-gateway` | platform Gateway |

## Integration contract (for the orchestrator)

An orchestrator (an Odoo module) manages the lifecycle. Three hook points:

### 1. Activate (create the pod)

`helm install <prefix> adhoc-way-instance -n <ns> --set host=... --set user.id=... --set user.email=...`
— or the equivalent via the Kubernetes API. The pod is dedicated to a single user.

### 2. Enter (authorize the user)

1. The backend (with the user already authenticated) calls the signer:
   ```
   POST http://<auth-svc-service>:<port>/grant
   Authorization: Bearer <grant-token>
   Content-Type: application/json

   {"user_id": "<id>", "email": "<email>", "host": "<host>"}
   ```
   `200` → `{ "token", "entry_url", "expires_at" }`
2. Wait until the pod is routable — poll the unauthenticated `GET https://<host>/healthz`
   (`503` while provisioning → `200` when ready). The poll never touches the token.
3. Redirect the user's browser to `entry_url` (`https://<host>/_auth?token=...`).
   The sidecar exchanges the single-use, short-lived token (bounded by
   `authProxy.maxEntryTtl`) for the session cookie.

Full `/grant` contract and errors: see `adhocwayAuthSvc` in `ingadhoc/devops-ops-tools`.

### 3. Destroy (ephemeral)

`helm uninstall <prefix> -n <ns>` — kills the pod (and the sidecar) → access is cut.

### Notes

- The grant token is the same bearer as the platform Secret; keep it server-side (never expose it to the browser).
- `/grant` only signs for hosts under the configured suffix — validate the prefix on the caller side too.
- Immediate revocation = destroy the instance. The entry token's short `exp` is the safety net.
- One pod = one user: the token's `aud == host` guarantees a token from another instance will not work here.
