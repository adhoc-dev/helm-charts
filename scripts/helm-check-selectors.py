#!/usr/bin/env python3
"""Verifica que todo selector de pods del chart matchee labels que el chart emite.

Lee un render de `helm template` por stdin y falla si algún selector no puede
matchear ningún pod producido por ese mismo chart. Un selector así no rompe el
deploy — simplemente no selecciona nada, y el recurso queda inerte.

Motivación: dos NetworkPolicies del chart adhoc-odoo quedaron huérfanas porque su
selector se armó con el helper de NOMBRE (`adhoc-odoo.fullname` -> "<release>-adhoc-odoo")
en vez del de SELECCIÓN (`.Release.Name`). No seleccionaban ningún pod, así que no
protegían nada, y eso pasó desapercibido en las 327 bases de la flota.

Valida el selector que define A QUIÉN aplica un recurso. Los podSelector dentro de
las reglas from/to de una NetworkPolicy quedan fuera a propósito: pueden apuntar
legítimamente a pods de otros charts, y validarlos daría falsos positivos.
"""

import sys

import yaml

# Workloads cuyo pod template describe los labels que van a tener los pods.
POD_TEMPLATE_KINDS = {"Deployment", "StatefulSet", "DaemonSet", "Job", "ReplicaSet"}

# Dónde vive el selector que define a qué pods aplica cada recurso.
SELECTOR_PATHS = {
    "Service": ("spec", "selector"),
    "Deployment": ("spec", "selector", "matchLabels"),
    "StatefulSet": ("spec", "selector", "matchLabels"),
    "DaemonSet": ("spec", "selector", "matchLabels"),
    "PodDisruptionBudget": ("spec", "selector", "matchLabels"),
    "NetworkPolicy": ("spec", "podSelector", "matchLabels"),
    "PodMonitor": ("spec", "selector", "matchLabels"),
    "ServiceMonitor": ("spec", "selector", "matchLabels"),
}


def dig(doc, path):
    """Devuelve doc[path[0]][path[1]]... o None si algún tramo falta."""
    cur = doc
    for key in path:
        if not isinstance(cur, dict):
            return None
        cur = cur.get(key)
    return cur


def emitted_label_sets(docs):
    """Conjuntos de labels que van a tener los pods que este chart produce."""
    sets = []
    for doc in docs:
        kind = doc.get("kind")
        if kind in POD_TEMPLATE_KINDS:
            labels = dig(doc, ("spec", "template", "metadata", "labels"))
            if labels:
                sets.append((f"{kind}/{dig(doc, ('metadata', 'name'))}", dict(labels)))
        elif kind == "CronJob":
            labels = dig(doc, ("spec", "jobTemplate", "spec", "template", "metadata", "labels"))
            if labels:
                sets.append((f"CronJob/{dig(doc, ('metadata', 'name'))}", dict(labels)))
        elif kind == "Pod":
            labels = dig(doc, ("metadata", "labels"))
            if labels:
                sets.append((f"Pod/{dig(doc, ('metadata', 'name'))}", dict(labels)))
        elif kind == "Cluster" and "postgresql.cnpg.io" in str(doc.get("apiVersion", "")):
            # Los pods de CNPG no están en el render: los crea el operador. Sus labels
            # son los de inheritedMetadata más los que el operador deriva del Cluster.
            name = dig(doc, ("metadata", "name"))
            labels = dict(dig(doc, ("spec", "inheritedMetadata", "labels")) or {})
            labels.update(
                {
                    "cnpg.io/cluster": name,
                    "cnpg.io/podRole": "instance",
                    "cnpg.io/instanceRole": "primary",
                    "role": "primary",
                }
            )
            sets.append((f"Cluster/{name} (pods vía operador CNPG)", labels))
    return sets


def collect_selectors(docs):
    """Selectores que definen a qué pods aplica cada recurso."""
    found = []
    for doc in docs:
        kind = doc.get("kind")
        path = SELECTOR_PATHS.get(kind)
        if not path:
            continue
        selector = dig(doc, path)
        # Selector vacío o ausente: matchea todo o el recurso no selecciona pods.
        if not selector:
            continue
        found.append((kind, dig(doc, ("metadata", "name")), dict(selector)))
    return found


def main():
    try:
        docs = [d for d in yaml.safe_load_all(sys.stdin.read()) if isinstance(d, dict)]
    except yaml.YAMLError as exc:
        print(f"ERROR: no se pudo parsear el render de helm: {exc}", file=sys.stderr)
        return 2

    label_sets = emitted_label_sets(docs)
    if not label_sets:
        return 0

    failures = []
    for kind, name, selector in collect_selectors(docs):
        matched = [
            origin
            for origin, labels in label_sets
            if all(labels.get(k) == v for k, v in selector.items())
        ]
        if not matched:
            failures.append((kind, name, selector))

    if not failures:
        return 0

    print("", file=sys.stderr)
    print("ERROR: hay selectores que no matchean ningún pod de este chart.", file=sys.stderr)
    print("Un recurso así no falla el deploy: queda inerte y no hace nada.", file=sys.stderr)
    for kind, name, selector in failures:
        print(f"\n  {kind}/{name}", file=sys.stderr)
        print(f"    selector: {selector}", file=sys.stderr)
        for key, value in selector.items():
            candidates = sorted({labels[key] for _, labels in label_sets if key in labels})
            if candidates and value not in candidates:
                print(f"    '{key}': el chart emite {candidates}, no '{value}'", file=sys.stderr)
    print(
        "\nPista habitual: usar el helper de NOMBRE (fullname) donde va el de SELECCIÓN.",
        file=sys.stderr,
    )
    print("Los selectores se arman con selectorLabels / .Release.Name.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
