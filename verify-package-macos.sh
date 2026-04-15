#!/usr/bin/env bash

set -euo pipefail

failed=0
user_home="$HOME"

write_ok() {
  printf '[OK] %s\n' "$1"
}

write_fail() {
  printf '[FAIL] %s\n' "$1"
}

write_warn() {
  printf '[WARN] %s\n' "$1"
}

required_paths=(
  "$user_home/.kiro"
  "$user_home/.kiro/settings"
  "$user_home/.kiro/settings/mcp.json"
  "$user_home/.kiro/steering"
  "$user_home/.kiro/skills"
)

for path in "${required_paths[@]}"; do
  if [[ -e "$path" ]]; then
    write_ok "Existe: $path"
  else
    write_fail "Falta: $path"
    failed=1
  fi
done

mcp_path="$user_home/.kiro/settings/mcp.json"
if [[ -f "$mcp_path" ]]; then
  if python3 - "$mcp_path" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
servers = data.get("mcpServers")
if not isinstance(servers, dict):
    raise SystemExit(1)
PY
  then
    write_ok "mcp.json es JSON valido y contiene mcpServers"
  else
    write_fail "mcp.json invalido o sin nodo mcpServers"
    failed=1
  fi
fi

if command -v git >/dev/null 2>&1; then
  write_ok "Git detectado: $(command -v git)"
else
  write_fail "No se detecto git en PATH"
  failed=1
fi

if command -v node >/dev/null 2>&1; then
  write_ok "Node detectado: $(node --version 2>/dev/null || echo 'sin version')"
else
  write_fail "No se detecto node en PATH"
  failed=1
fi

if command -v npx >/dev/null 2>&1 && npx --version >/dev/null 2>&1; then
  write_ok "npx detectado: v$(npx --version)"
else
  write_fail "No se detecto npx operativo en PATH"
  failed=1
fi

if command -v kiro-cli >/dev/null 2>&1; then
  write_ok "Kiro CLI detectado: kiro-cli ($(command -v kiro-cli))"
elif command -v kiro >/dev/null 2>&1; then
  write_ok "Comando Kiro detectado: kiro ($(command -v kiro))"
else
  write_warn "No se detecto comando Kiro en PATH (comandos probados: kiro-cli, kiro)."
fi

skills_root="$user_home/.kiro/skills"
if [[ -d "$skills_root" ]]; then
  skill_count="$(python3 - "$skills_root" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
print(sum(1 for p in root.rglob("SKILL.md") if p.is_file()))
PY
)"

  if [[ "$skill_count" -gt 0 ]]; then
    write_ok "Skills detectadas: $skill_count"
  else
    write_fail "No se detectaron skills instaladas (SKILL.md)."
    failed=1
  fi
fi

if [[ "$failed" -eq 1 ]]; then
  printf 'Verificacion final: FAIL\n'
  exit 1
fi

printf 'Verificacion final: OK\n'
exit 0
