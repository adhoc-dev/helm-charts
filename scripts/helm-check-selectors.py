#!/usr/bin/env python3
"""Verifica que todo selector del chart matchee algo que el chart emite.

Lee un render de `helm template` por stdin y falla si algún selector no puede
matchear ningún pod (o Service) producido por ese mismo chart. Un selector así no
rompe el deploy — simplemente no selecciona nada, y el recurso queda inerte.

Motivación: dos NetworkPolicies del chart adhoc-odoo quedaron huérfanas porque su
selector se armó con el helper de NOMBRE (`adhoc-odoo.fullname` -> "<release>-adhoc-odoo")
en vez del de SELECCIÓN (`.Release.Name`). No seleccionaban ningún pod, así que no
protegían nada, y eso pasó desapercibido en las 327 bases de la flota.

Alcance deliberado:
- Valida el selector que define A QUIÉN aplica un recurso. Los podSelector dentro de
  las reglas from/to de una NetworkPolicy quedan fuera: pueden apuntar legítimamente a
  pods de otros charts y darían falsos positivos.
- Se reconocen los controladores que este repo usa. Un chart que renderice pods vía un
  CRD de terceros (Argo Rollout, DeploymentConfig, Knative) no aporta sus labels y sus
  selectores darían falso positivo; sumar el kind acá es el arreglo.
"""

import sys

import yaml

# Workloads cuyo pod template describe los labels que van a tener los pods.
POD_TEMPLATE_KINDS = {"Deployment", "StatefulSet", "DaemonSet", "Job", "ReplicaSet", "ReplicationController"}

# Selector que define a qué pods aplica cada recurso.
POD_SELECTOR_PATHS = {
    "Service": ("spec", "selector"),
    "Deployment": ("spec", "selector"),
    "StatefulSet": ("spec", "selector"),
    "DaemonSet": ("spec", "selector"),
    "ReplicationController": ("spec", "selector"),
    "PodDisruptionBudget": ("spec", "selector"),
    "NetworkPolicy": ("spec", "podSelector"),
    "PodMonitor": ("spec", "selector"),
}

# ServiceMonitor selecciona Services, no pods: se compara contra otro pool.
SERVICE_SELECTOR_PATHS = {"ServiceMonitor": ("spec", "selector")}

# Selectores que Kubernetes acepta como mapa plano, sin matchLabels/matchExpressions.
FLAT_SELECTOR_KINDS = {"Service", "ReplicationController"}

# Labels que inyecta el runtime (no el chart): no se pueden validar contra el render.
RUNTIME_INJECTED_EXACT = {
    "pod-template-hash",
    "controller-revision-hash",
    "statefulset.kubernetes.io/pod-name",
    "apps.kubernetes.io/pod-index",
    "job-name",
    "controller-uid",
}
RUNTIME_INJECTED_PREFIXES = (
    "security.istio.io/",  # tlsMode, lo pone el sidecar injector
    "service.istio.io/",  # canonical-name / canonical-revision
    "batch.kubernetes.io/",  # job-name, controller-uid
)


def is_runtime_injected(key):
    return key in RUNTIME_INJECTED_EXACT or key.startswith(RUNTIME_INJECTED_PREFIXES)


def dig(doc, path):
    """Devuelve doc[path[0]][path[1]]... o None si algún tramo falta o no es dict."""
    cur = doc
    for key in path:
        if not isinstance(cur, dict):
            return None
        cur = cur.get(key)
    return cur


def as_label_map(raw):
    """Normaliza a {str: str}. Devuelve None si no es un mapa de labels válido."""
    if not isinstance(raw, dict):
        return None
    return {str(k): str(v) for k, v in raw.items()}


def parse_selector(doc, kind, path):
    """Devuelve (matchLabels, matchExpressions) o None si el selector está vacío."""
    raw = dig(doc, path)
    if not isinstance(raw, dict) or not raw:
        return None
    if kind in FLAT_SELECTOR_KINDS:
        labels = as_label_map(raw)
        return (labels, []) if labels else None
    labels = as_label_map(raw.get("matchLabels")) or {}
    exprs = raw.get("matchExpressions")
    exprs = exprs if isinstance(exprs, list) else []
    if not labels and not exprs:
        return None
    return labels, exprs


def satisfies(labels, match_labels, match_expressions):
    """True si el conjunto de labels satisface el selector."""
    for key, value in match_labels.items():
        if is_runtime_injected(key):
            continue
        if labels.get(key) != value:
            return False
    for expr in match_expressions:
        if not isinstance(expr, dict):
            continue
        key = str(expr.get("key", ""))
        if not key or is_runtime_injected(key):
            continue
        operator = expr.get("operator")
        values = [str(v) for v in (expr.get("values") or [])]
        present = key in labels
        if operator == "In" and (not present or labels[key] not in values):
            return False
        if operator == "NotIn" and present and labels[key] in values:
            return False
        if operator == "Exists" and not present:
            return False
        if operator == "DoesNotExist" and present:
            return False
    return True


def cnpg_label_sets(doc):
    """Los pods de CNPG no están en el render: los crea el operador.

    Se derivan del Cluster: inheritedMetadata más los cnpg.io/* que el operador arma
    con su nombre. Se emiten primary y replica porque un selector hacia réplicas es
    igual de legítimo.
    """
    name = dig(doc, ("metadata", "name"))
    inherited = as_label_map(dig(doc, ("spec", "inheritedMetadata", "labels"))) or {}
    sets = []
    for role in ("primary", "replica"):
        labels = dict(inherited)
        labels.update(
            {
                "cnpg.io/cluster": str(name),
                "cnpg.io/podRole": "instance",
                "cnpg.io/instanceRole": role,
                "role": role,
            }
        )
        sets.append((f"Cluster/{name} ({role}, pods vía operador CNPG)", labels))
    return sets


def collect_pools(docs):
    """Conjuntos de labels de pods y de Services que este chart produce."""
    pods, services = [], []
    for doc in docs:
        kind = doc.get("kind")
        name = dig(doc, ("metadata", "name"))
        if kind in POD_TEMPLATE_KINDS:
            labels = as_label_map(dig(doc, ("spec", "template", "metadata", "labels")))
            if labels:
                pods.append((f"{kind}/{name}", labels))
        elif kind == "CronJob":
            labels = as_label_map(dig(doc, ("spec", "jobTemplate", "spec", "template", "metadata", "labels")))
            if labels:
                pods.append((f"CronJob/{name}", labels))
        elif kind == "Pod":
            labels = as_label_map(dig(doc, ("metadata", "labels")))
            if labels:
                pods.append((f"Pod/{name}", labels))
        elif kind == "Cluster" and "postgresql.cnpg.io" in str(doc.get("apiVersion", "")):
            pods.extend(cnpg_label_sets(doc))
        if kind == "Service":
            labels = as_label_map(dig(doc, ("metadata", "labels")))
            if labels:
                services.append((f"Service/{name}", labels))
    return pods, services


def collect_selectors(docs):
    """(kind, nombre, matchLabels, matchExpressions, pool) por cada selector."""
    found = []
    for doc in docs:
        kind = doc.get("kind")
        for paths, pool in ((POD_SELECTOR_PATHS, "pods"), (SERVICE_SELECTOR_PATHS, "services")):
            path = paths.get(kind)
            if not path:
                continue
            parsed = parse_selector(doc, kind, path)
            if parsed:
                found.append((kind, dig(doc, ("metadata", "name")), parsed[0], parsed[1], pool))
    return found


def main():
    try:
        docs = [d for d in yaml.safe_load_all(sys.stdin.read()) if isinstance(d, dict)]
    except yaml.YAMLError as exc:
        print(f"ERROR: no se pudo parsear el render de helm: {exc}", file=sys.stderr)
        return 2

    pods, services = collect_pools(docs)
    if not pods and not services:
        return 0

    failures = []
    for kind, name, match_labels, exprs, pool in collect_selectors(docs):
        candidates = pods if pool == "pods" else services
        # Sin nada del pool en el render no hay con qué comparar: no es evidencia de error.
        if not candidates:
            continue
        if not any(satisfies(labels, match_labels, exprs) for _, labels in candidates):
            failures.append((kind, name, match_labels, exprs, candidates, pool))

    if not failures:
        return 0

    print("", file=sys.stderr)
    print("ERROR: hay selectores que no matchean nada de lo que emite este chart.", file=sys.stderr)
    print("Un recurso así no falla el deploy: queda inerte y no hace nada.", file=sys.stderr)
    for kind, name, match_labels, exprs, candidates, pool in failures:
        print(f"\n  {kind}/{name}  (selecciona {pool})", file=sys.stderr)
        if match_labels:
            print(f"    matchLabels: {match_labels}", file=sys.stderr)
        if exprs:
            print(f"    matchExpressions: {exprs}", file=sys.stderr)
        for key, value in match_labels.items():
            if is_runtime_injected(key):
                continue
            emitted = sorted({labels[key] for _, labels in candidates if key in labels})
            if emitted and value not in emitted:
                print(f"    '{key}': el chart emite {emitted}, no '{value}'", file=sys.stderr)
    print(
        "\nPista habitual: usar el helper de NOMBRE (fullname) donde va el de SELECCIÓN.",
        file=sys.stderr,
    )
    print("Los selectores se arman con selectorLabels / .Release.Name.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
