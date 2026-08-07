# adhoc-way-user

Persistent state for **one user** of the *way* platform: a single volume holding
their agent configuration and their projects.

## Why it is a separate release

An instance of the platform is a **user × surface** pair. The state is not: a user
may open Claude Code UI today and another surface tomorrow, and **both have to see
the same files**. So the volume cannot belong to the instance release.

It also makes deletion safer. Removing a surface is routine; losing a user's
unpushed work is not. With the volume in its own release, `helm uninstall` of a
surface cannot touch it — and this chart keeps the claim even when *its own*
release is uninstalled (`state.retainOnUninstall`, on by default), because there
is no backup of this data.

## Install

```sh
helm install way-user-1202 adhoc-dev/adhoc-way-user -n way \
  --set user.id=1202 --set user.email=az@adhoc.inc
```

The claim is named after the release (`way-user-1202`), which is the contract with
`adhoc-way-instance`: every surface of that user passes it as
`state.existingClaim`.

## Two surfaces at the same time

`ReadWriteOnce` does **not** mean "one pod". It means one *node*: several pods can
mount the volume as long as they are scheduled together. So:

| Situation | Works with ReadWriteOnce |
|---|---|
| One surface at a time | yes |
| Two surfaces, co-scheduled on one node | yes |
| Two surfaces on different nodes, at once | **no** — needs a ReadWriteMany class |

Co-scheduling is a scheduling constraint, not a guarantee: if the node has no room
the second surface stays `Pending`. Decide this before promising simultaneous
surfaces to users.

## Values

| Key | Default | Notes |
|---|---|---|
| `state.size` | `1Gi` | Configuration and source checkouts, not artifacts. |
| `state.storageClassName` | `""` | Cluster default. |
| `state.accessModes` | `[ReadWriteOnce]` | See above. |
| `state.retainOnUninstall` | `true` | Keeps the claim on `helm uninstall`. |
| `user.id`, `user.email` | `""` | Informational: labels and annotations. |
