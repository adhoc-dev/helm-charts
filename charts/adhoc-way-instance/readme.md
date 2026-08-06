# adhoc-way-instance

Ephemeral per-user instance of the "way" platform: a pod with a third-party web
tool (an IDE / agent UI) and the `adhocwayAuthProxy` sidecar that only lets the
owning user in. Requires [`adhoc-way-platform`](../adhoc-way-platform) in the same
namespace.

## What it installs

- Deployment with **2 containers**: `auth-proxy` (the only exposed port) + `tool` (listens on `127.0.0.1`).
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

## Main values

| Key | Default | Description |
|---|---|---|
| `host` | `""` (required) | pod FQDN, `<prefix>.<platform-domain>` |
| `user.id` / `user.email` | `""` | owning user (annotations) |
| `tool.image.tag` | `open-code-server-20260701-1` | tool image (default: openCode) |
| `tool.port` | `4096` | tool localhost port |
| `tool.publicUrlEnvVar` | `OPENCODE_PUBLIC_URL` | env for the tool's public URL (`https://<host>`); `""` to skip |
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
