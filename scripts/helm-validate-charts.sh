#!/usr/bin/env bash
set -euo pipefail

# Valida charts Helm ejecutando:
# - helm lint
# - helm template (render)
#
# Uso:
#   bash scripts/helm-validate-charts.sh                 # valida todos los charts en ./charts
#   bash scripts/helm-validate-charts.sh <paths...>      # valida sólo los charts afectados por esos paths

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
charts_root="$repo_root/charts"

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: 'helm' no está instalado/en PATH" >&2
  exit 1
fi

find_chart_dir() {
  local input="$1"
  local p="$input"

  if [[ "$p" != /* ]]; then
    p="$repo_root/$p"
  fi

  if [[ -d "$p" ]]; then
    :
  elif [[ -f "$p" ]]; then
    p="$(dirname "$p")"
  else
    return 0
  fi

  while [[ "$p" != "/" ]]; do
    if [[ -f "$p/Chart.yaml" ]]; then
      printf '%s\n' "$p"
      return 0
    fi
    p="$(dirname "$p")"
  done
}

collect_all_charts() {
  find "$charts_root" -mindepth 2 -maxdepth 2 -type f -name Chart.yaml -print0 \
    | xargs -0 -n1 dirname
}

collect_target_charts() {
  if [[ "$#" -eq 0 ]]; then
    collect_all_charts
    return 0
  fi

  local chart
  for arg in "$@"; do
    chart="$(find_chart_dir "$arg" || true)"
    if [[ -n "${chart:-}" ]] && [[ "$chart" == "$charts_root"/* ]]; then
      printf '%s\n' "$chart"
    fi
  done
}

mapfile -t charts < <(collect_target_charts "$@" | sort -u)

if [[ "${#charts[@]}" -eq 0 ]]; then
  echo "No se detectaron charts para validar." >&2
  exit 0
fi

echo "Charts a validar:" >&2
printf ' - %s\n' "${charts[@]##$repo_root/}" >&2

for chart in "${charts[@]}"; do
  echo >&2
  echo "==> helm lint ${chart##$repo_root/}" >&2
  helm lint "$chart"

  echo "==> helm template ${chart##$repo_root/}" >&2
  helm template "$chart" >/dev/null

done

echo >&2
echo "OK: validación de Helm completada." >&2
