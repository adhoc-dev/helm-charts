# adhoc-way-instance

Ephemeral per-user instance of the "way" platform: a pod with a third-party web
tool (an IDE / agent UI) and the `adhocwayAuthProxy` sidecar that only lets the
owning user in. Requires [`adhoc-way-platform`](../adhoc-way-platform) in the same
namespace.

## What it installs

- Deployment with **2 containers**: `auth-proxy` (the only exposed port) + `tool` (listens on `127.0.0.1`).
- Service (only the proxy port) · Istio VirtualService (`{host}` → platform gateway) · NetworkPolicy.

## Install (one per user, release = host prefix)

```sh
helm install <prefix> charts/adhoc-way-instance -n <ns> \
  --set host=<prefix>.<platform-domain> \
  --set tool.image.tag=<tool-image-tag> \
  --set tool.port=<tool-port> \
  --set user.id=<user-id>
```

> The `tool` **must** listen on `127.0.0.1` (anti-bypass): its port is not exposed
> in the Service, only the sidecar reaches it. Configure its bind via
> `tool.command` / `tool.args` / `tool.env`.

## Main values

| Key | Default | Description |
|---|---|---|
| `host` | `""` (required) | pod FQDN, `<prefix>.<platform-domain>` |
| `tool.image.tag` | `openCodeServer-latest` | tool image |
| `tool.port` | `3000` | tool localhost port |
| `authProxy.image.tag` | `adhocwayAuthProxy-2026.08.04.1` | sidecar image |
| `authProxy.entryPubKeyConfigMap` | `adhoc-way-platform-entry-pubkey` | platform ConfigMap |
| `ingress.istio.gateway` | `adhoc-way-platform-gateway` | platform Gateway |

## Integration contract (for the orchestrator)

An orchestrator (an Odoo module) manages the lifecycle. Three hook points:

### 1. Activate (create the pod)

`helm install <prefix> adhoc-way-instance -n <ns> --set host=... --set tool.image...=... --set user...`
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
2. Redirect the user's browser to `entry_url` (`https://<host>/_auth?token=...`).
   The sidecar exchanges the single-use token (~60s) for the session cookie.

Full `/grant` contract and errors: see `adhocwayAuthSvc` in `ingadhoc/devops-ops-tools`.

### 3. Destroy (ephemeral)

`helm uninstall <prefix> -n <ns>` — kills the pod (and the sidecar) → access is cut.

### Notes

- The grant token is the same bearer as the platform Secret; keep it server-side (never expose it to the browser).
- `/grant` only signs for hosts under the configured suffix — validate the prefix on the caller side too.
- Immediate revocation = destroy the instance. The entry token's short `exp` (~60s) is the safety net.
- One pod = one user: the token's `aud == host` guarantees a token from another instance will not work here.
