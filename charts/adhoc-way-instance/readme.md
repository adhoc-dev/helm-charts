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
than one surface and **all of them must see the same files**, so the volume lives
in its own release — chart [`adhoc-way-user`](../adhoc-way-user/) — and this chart
only references it:

```sh
# once per user
helm install way-user-<id> adhoc-dev/adhoc-way-user -n <ns> \
  --set user.id=<id> --set user.email=<email>

# once per surface, pointing at that claim
helm install <prefix> adhoc-dev/adhoc-way-instance -n <ns> \
  --set state.existingClaim=way-user-<id> ...
```

It mounts on `/home/odoo`, where everything the user owns lives: agent state in
dotfiles and projects in `workspace/`. One mount, nothing else to wire.

### One command instead of two: `state.createIfMissing`

With `state.createIfMissing=true` this chart creates the claim itself when it is
not there yet, using Helm's `lookup`, so the orchestrator does a single install
per surface. **It works** — verified on a live cluster:

| Scenario | Result |
|---|---|
| First surface, no claim yet | creates it, with `resource-policy: keep` |
| Second surface, same user | `lookup` finds it, skips — no duplicate, no ownership error |
| `helm upgrade` of the surface that created it | claim untouched |
| `helm uninstall` of the surface that created it | **claim survives** |

Three caveats, none of which risks the data but all of which surprise:

1. **`lookup` is blind without a cluster.** `helm template` and `--dry-run`
   render the claim even when it already exists, so what CI validates is not what
   gets applied.
2. **The claim ends up owned by a release that may no longer exist.** After
   uninstalling the surface that created it, the claim keeps
   `meta.helm.sh/release-name` pointing at a gone release. Harmless while every
   other surface only reads it, but nothing manages it anymore: deleting it for
   real needs `kubectl`.
3. **Concurrent installs race.** Two surfaces of the same user created at the same
   moment both see "no claim" and both try to create it; one fails. Same thing if
   the caller lacks RBAC to *read* claims, because `lookup` returns empty instead
   of failing — and then the create hits an ownership error that says nothing
   about permissions.

So: convenient for a hand-driven install, and **the explicit
[`adhoc-way-user`](../adhoc-way-user/) release is what an orchestrator should
use** — or, better for a module that already talks to Kubernetes, create the claim
through the API, where "create if missing" is a plain 409 to swallow instead of a
render-time guess.

**Without `state.existingClaim` the state is an `emptyDir`** — fine for a smoke
test, wrong for a person: closing the workspace loses whatever they had not
pushed.

Two details that are easy to get wrong:

- **`podSecurityContext.fsGroup` must match the group of the tool image's user**
  (`1001` for `adhocWayWorkspace`). A freshly provisioned disk belongs to root, so
  without it the pod starts and dies unable to write its own home.
- **`state.subPath`** (default `home`) mounts a subdirectory instead of the volume
  root. That lets the same disk hold more than one thing later and keeps the
  filesystem's `lost+found` out of the user's home.

With `ReadWriteOnce`, two surfaces of the same user can run at once only if they
land on the same node — see the [`adhoc-way-user`](../adhoc-way-user/) readme.

## Main values

| Key | Default | Description |
|---|---|---|
| `host` | `""` (required) | pod FQDN, `<prefix>.<platform-domain>` |
| `state.existingClaim` | `""` | per-user claim (chart `adhoc-way-user`); empty = ephemeral `emptyDir` |
| `state.createIfMissing` | `false` | create the claim here if absent (see caveats above) |
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
