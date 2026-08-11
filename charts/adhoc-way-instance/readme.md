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

- **The installing identity needs `get` on claims, not only `create`.** Without it
  the install stops at render time — `lookup` propagates the 403 instead of
  swallowing it, so the message names the permission, the service account and the
  namespace:

  ```
  error calling lookup: persistentvolumeclaims "way-user-2" is forbidden:
  User "system:serviceaccount:devops:helm-runner-ksa" cannot get resource
  "persistentvolumeclaims" in API group "" in the namespace "way"
  ```

  Note it fails *before* creating anything, so a half-installed surface is not a
  state you can end up in this way.
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
| `github.credentialUrl` | `""` | where the pod asks for git credentials; empty means no GitHub access |
| `github.tokenAudience` | `adhocway-credential` | audience of the pod's token; must match what the platform validates |
| `github.tokenExpirationSeconds` | `600` | lifetime of each projected token |
| `serviceAccount.name` | `""` | identity of the pod; defaults to the release's full name |
| `workspace` | `{}` | what the workspace works on: its projects (see below) |
| `user.name` / `user.email` | `""` | the identity git commits with inside the workspace |

## Workspace

`workspace.projects` is what this workspace works on. Each project is cloned on start
if missing and brought up to date if already there, keeping whatever the person had in
progress. A project's `path` is relative to the workspace root and a component's to the
project that mounts it, to any depth.

```yaml
user:
  name: Jane Doe (jd)
  email: jane.doe@example.com
workspace:
  projects:
    - path: handbook
      clone_url: https://git.example.com/acme/handbook
      access: write
      components:
        - path: memory
          clone_url: https://git.example.com/acme/handbook-memory
          access: read
```

Written as YAML here and handed to the image as JSON in `ADHOCWAY_WORKSPACE`.

`user.name` and `user.email` are exported as `ADHOCWAY_USER_NAME` and
`ADHOCWAY_USER_EMAIL`, and become the git identity of the workspace. Without them git
refuses to commit at all (*"Please tell me who you are"*), so a workspace meant for
work needs both. `user.email` used to be informational only, in an annotation; it still
is one, and now it is also this.

`components` and `access` are optional. `access` (`read` or `write`) is informational:
what a credential is good for is decided when it is asked for. `clone_url` has to be
https — the pod authenticates through the credential helper and holds no ssh key.

When reapplying the person's changes conflicts, **the conflict is left in the tree** so
the agent in the workspace resolves it before pushing; nothing is lost. `access` lands in
each repository's local config, which is what an agent can read before trying to push.
The image's readme has the rest of the behaviour.

## GitHub access

The pod holds **no GitHub credential**. `git` asks the platform for one per operation
through the credential helper the tool image ships, and the token it gets back is an
installation token of a GitHub App that expires in an hour and is never written to disk.

How the pod proves which instance is asking: Kubernetes projects a **service account
token** into it, minted for `github.tokenAudience` and signed by the cluster. The
platform validates it against the cluster's public JWKS — no credential of the platform
is involved and the API server is not called. Two consequences worth knowing:

- **`serviceAccount.name` is the identity.** The subject of the token names it, and that
  is what the platform resolves to an instance, so the orchestrator sets it to the name
  it knows that instance by.
- **Only expiry invalidates a token.** Validating it offline cannot tell that the pod is
  gone, so `github.tokenExpirationSeconds` is the window in which a leaked one still
  works. 600 is the shortest the kubelet honours.

The pod also runs with `automountServiceAccountToken: false`: the default mount is a
token the API server accepts, nothing in the pod talks to it, and the projected one is
good for the platform and for nothing else.

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
