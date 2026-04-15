#!/usr/bin/env bash

set -euo pipefail

installed_version=""
force="false"
quiet_if_checked_today="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --installed-version)
    installed_version="${2:-}"
    shift 2
    ;;
  --force)
    force="true"
    shift
    ;;
  --quiet-if-checked-today)
    quiet_if_checked_today="true"
    shift
    ;;
  *)
    shift
    ;;
  esac
done

write_info() {
  printf '[INFO] %s\n' "$1"
}

write_warn() {
  printf '[WARN] %s\n' "$1"
}

normalize_version() {
  local value="$1"
  value="${value#v}"
  printf '%s' "$value"
}

compare_versions() {
  python3 - "$1" "$2" <<'PY'
import sys

def parse(v):
    parts = [p for p in v.strip().split('.') if p != '']
    out = []
    for item in parts:
        try:
            out.append(int(item))
        except Exception:
            out.append(0)
    while len(out) < 3:
        out.append(0)
    return tuple(out[:3])

a = parse(sys.argv[1])
b = parse(sys.argv[2])

if a < b:
    raise SystemExit(0)
raise SystemExit(1)
PY
}

user_home="$HOME"
state_dir="$user_home/.kiro/state"
state_path="$state_dir/mcpkirokit-update-check.json"
install_meta_path="$user_home/.kiro/mcpkirokit-install.json"
today="$(date +%F)"

mkdir -p "$state_dir"

if [[ "$force" != "true" && -f "$state_path" ]]; then
  last_date="$(python3 - "$state_path" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding='utf-8'))
except Exception:
    print('')
    raise SystemExit(0)

print(data.get('lastCheckDate', ''))
PY
)"

  if [[ "$last_date" == "$today" ]]; then
    if [[ "$quiet_if_checked_today" != "true" ]]; then
      write_info "Chequeo de actualizaciones ya ejecutado hoy."
    fi
    exit 0
  fi
fi

if [[ -z "$installed_version" && -f "$install_meta_path" ]]; then
  installed_version="$(python3 - "$install_meta_path" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding='utf-8'))
except Exception:
    print('')
    raise SystemExit(0)

print(data.get('installedVersion', ''))
PY
)"
fi

latest_tag=""
if latest_tag="$(curl -fsSL -H "User-Agent: MCPKiroKit-UpdateChecker" "https://api.github.com/repos/andersonlugojacome/mcp-kiro-kit/releases/latest" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name",""))' 2>/dev/null)"; then
  :
else
  write_warn "No se pudo consultar la version mas reciente."
  exit 0
fi

installed_normalized="$(normalize_version "$installed_version")"
latest_normalized="$(normalize_version "$latest_tag")"
result="unknown"

if [[ -n "$installed_normalized" && -n "$latest_normalized" ]]; then
  if compare_versions "$installed_normalized" "$latest_normalized"; then
    result="update-available"
    write_warn "Nueva version disponible: v$latest_normalized (instalada: v$installed_normalized)."
    write_info "Ejecuta: actualizame"
  else
    result="up-to-date"
    write_info "MCPKiroKit al dia (v$installed_normalized)."
  fi
else
  write_info "Version instalada: $installed_normalized"
  write_info "Version mas reciente: $latest_tag"
fi

python3 - "$state_path" "$today" "$installed_normalized" "$latest_tag" "$result" <<'PY'
import datetime as dt
import json
import pathlib
import sys

state_path = pathlib.Path(sys.argv[1])
today = sys.argv[2]
installed = sys.argv[3]
latest = sys.argv[4]
result = sys.argv[5]

payload = {
    'lastCheckDate': today,
    'checkedAt': dt.datetime.now(dt.timezone.utc).isoformat(),
    'installedVersion': installed,
    'latestTag': latest,
    'result': result,
}

state_path.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + '\n', encoding='utf-8')
PY

exit 0
