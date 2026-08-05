# adhoc-way-platform

Singleton chart for the "way" platform. Installs the shared, cluster-wide
components: the signer service `adhocwayAuthSvc`, a dedicated Istio Gateway and a
wildcard certificate for the platform domain. Install once per cluster. Per-user
instances are deployed by [`adhoc-way-instance`](../adhoc-way-instance).

## What it installs

- `adhocwayAuthSvc` (Deployment + Service) — `POST /grant` mints entry tokens.
- Secret with `signing-key` (Ed25519) + `grant-token` (or `existingSecret`).
- ConfigMap `adhoc-way-platform-entry-pubkey` — the public key consumed by the sidecars.
- Istio Gateway for `*.<domain>` (binds to the ingress gateway).
- cert-manager Certificate (wildcard) — TLS secret in `istio-system`.

## Bootstrap (once)

Generate the keypair with the signer image:
```sh
docker run --rm <auth-svc-image> keygen
# WAY_SIGNING_KEY  -> Secret (signing-key)
# WAY_ENTRY_PUBKEY -> value entryPubKey
```

## Install

```sh
helm install adhoc-way-platform charts/adhoc-way-platform -n <ns> --create-namespace \
  --set domain=<platform-domain> \
  --set entryPubKey="$WAY_ENTRY_PUBKEY" \
  --set authSvc.existingSecret=<secret-name>
```
Dev (no `existingSecret`): `--set authSvc.secret.signingKey=... --set authSvc.secret.grantToken=...`.

> Deployment-specific values (domain, cert issuer, DNS, secret store) are provided
> at deploy time (Pulumi) and documented in the private devops docs — not here.

## Main values

| Key | Default | Description |
|---|---|---|
| `domain` | `way.example.com` | platform domain for the gateway/cert |
| `entryPubKey` | `""` | signer Ed25519 public key |
| `authSvc.image.tag` | `adhocwayAuthSvc-2026.08.04.1` | signer image |
| `authSvc.existingSecret` | `""` | Secret with `signing-key` + `grant-token` |
| `gateway.credentialName` | `way-wildcard-tls` | TLS secret read by the gateway |
| `certificate.issuerRef.name` | `letsencrypt-dns` | cert-manager ClusterIssuer (DNS-01) |

## Key rotation

Re-run `keygen`, update the Secret (`signing-key`) and the ConfigMap (`entryPubKey`);
ephemeral pods pick up the new public key when recreated.
