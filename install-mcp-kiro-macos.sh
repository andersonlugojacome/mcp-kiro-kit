#!/usr/bin/env bash

set -euo pipefail

MCP_KIRO_KIT_VERSION="1.0.7"
WORKSPACE_PATH="${1:-}"

write_info() {
  printf '[INFO] %s\n' "$1"
}

write_warn() {
  printf '[WARN] %s\n' "$1"
}

write_error() {
  printf '[ERROR] %s\n' "$1" >&2
}

ensure_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    write_error "Este instalador es solo para macOS."
    exit 1
  fi
}

ensure_homebrew_shellenv() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_homebrew() {
  ensure_homebrew_shellenv
  if command -v brew >/dev/null 2>&1; then
    write_info "Homebrew ya esta instalado"
    return
  fi

  write_info "Instalando Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ensure_homebrew_shellenv

  if ! command -v brew >/dev/null 2>&1; then
    write_error "No se pudo instalar Homebrew."
    exit 1
  fi
}

ensure_brew_package() {
  local command_name="$1"
  local package_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    write_info "$command_name ya esta disponible"
    return
  fi

  write_info "Instalando $package_name con brew"
  brew install "$package_name"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    write_error "No se pudo validar $command_name despues de instalar $package_name."
    exit 1
  fi
}

ensure_npx() {
  if ! command -v npx >/dev/null 2>&1; then
    write_error "npx no esta disponible. Verifica la instalacion de node."
    exit 1
  fi

  local version
  version="$(npx --version 2>/dev/null || true)"
  if [[ -z "$version" ]]; then
    write_error "npx esta instalado pero no responde correctamente."
    exit 1
  fi

  write_info "npx OK ($version)"
}

merge_mcp_json() {
  local settings_file="$1"
  python3 - "$settings_file" <<'PY'
import json
import pathlib
import sys

settings_path = pathlib.Path(sys.argv[1])
existing = {}
if settings_path.exists():
    try:
        existing = json.loads(settings_path.read_text(encoding="utf-8"))
        if not isinstance(existing, dict):
            existing = {}
    except Exception:
        existing = {}

desired = {
    "mcpServers": {
        "context7": {
            "command": "npx",
            "args": ["-y", "@upstash/context7-mcp"],
        },
        "engram": {
            "command": "npx",
            "args": ["-y", "engram-mcp-server"],
        },
    }
}

def merge(base, incoming):
    for key, incoming_value in incoming.items():
        if key not in base:
            base[key] = incoming_value
            continue
        base_value = base[key]
        if isinstance(base_value, dict) and isinstance(incoming_value, dict):
            merge(base_value, incoming_value)
            continue
        base[key] = incoming_value

merge(existing, desired)
settings_path.write_text(json.dumps(existing, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
PY
}

ensure_kiro_mcp_settings() {
  local root_path="$1"
  local settings_dir="$root_path/.kiro/settings"
  local settings_file="$settings_dir/mcp.json"

  mkdir -p "$settings_dir"
  merge_mcp_json "$settings_file"
  write_info "MCP configurado en $settings_file"
  write_info "Servidores MCP declarados: context7, engram"
}

ensure_kiro_base_content() {
  local home_path="$1"
  local steering_dir="$home_path/.kiro/steering"
  local skill_dir="$home_path/.kiro/skills"

  mkdir -p "$steering_dir" "$skill_dir"

  if [[ ! -f "$steering_dir/AGENTS.md" ]]; then
    cat >"$steering_dir/AGENTS.md" <<'EOF'
# Kiro AGENTS (MCP + Verificacion)

## Rules
- NEVER add "Co-Authored-By" or any AI attribution to commits. Use conventional commits format only.
- Never build after changes.
- When asking user a question, STOP and wait for response. Never continue or assume answers.
- Never agree with user claims without verification. Say "dejame verificar" and check code/docs first.
- If user is wrong, explain WHY with evidence. If you were wrong, acknowledge with proof.
- Always propose alternatives with tradeoffs when relevant.
- Verify technical claims before stating them. If unsure, investigate first.

## Personality
Senior Architect, 15+ years experience, GDE & MVP. Passionate teacher who genuinely wants people to learn and grow.

## Reuso Inteligente (Engram + Context7)
- En cada consulta del usuario, consultar Engram primero para recuperar contexto relevante.
- Refrescar Context7 cada 4 consultas de usuario o antes si hay incertidumbre tecnica.

## Politica de Seguridad
- Nunca escribas API keys en `.kiro/settings/mcp.json` ni en steering.
- Usa variables de entorno para credenciales cuando un server lo requiera.

## Verificacion Tecnica Obligatoria
1. Confirmar prerequisitos (`git`, `node`, `npx`).
2. Validar JSON antes de guardar configuraciones.
3. Probar comandos MCP con `npx -y <paquete> --help`.
4. Informar resultado con estado claro: OK, warning o bloqueo.
EOF
    write_info "Creado $steering_dir/AGENTS.md"
  fi

  if [[ ! -f "$steering_dir/01-mcp-workflow.md" ]]; then
    cat >"$steering_dir/01-mcp-workflow.md" <<'EOF'
---
inclusion: always
---

# MCP Workflow

1. Validar npx.
2. Validar mcp.json.
3. Reiniciar Kiro.
EOF
    write_info "Creado $steering_dir/01-mcp-workflow.md"
  fi

  if [[ ! -f "$skill_dir/README.md" ]]; then
    printf 'Base de skills local para Kiro.\n' >"$skill_dir/README.md"
    write_info "Creado $skill_dir/README.md"
  fi
}

copy_kiro_assets() {
  local source_kiro_root="$1"
  local target_root="$2"
  local target_label="$3"

  local source_steering="$source_kiro_root/steering"
  local source_skills="$source_kiro_root/skills"
  local target_kiro_root="$target_root/.kiro"
  local target_steering="$target_kiro_root/steering"
  local target_skills="$target_kiro_root/skills"

  if [[ ! -d "$source_steering" || ! -d "$source_skills" ]]; then
    write_error "No se encontraron carpetas .kiro/steering y .kiro/skills en el paquete descargado."
    return 1
  fi

  mkdir -p "$target_steering" "$target_skills"
  cp -R "$source_steering/." "$target_steering/"
  cp -R "$source_skills/." "$target_skills/"

  local legacy_shared_skill_path="$target_skills/_shared/SKILL.md"
  if [[ -f "$legacy_shared_skill_path" ]]; then
    rm -f "$legacy_shared_skill_path"
    write_info "Removido archivo legado no valido: $legacy_shared_skill_path"
  fi

  local skill_count
  skill_count="$(python3 - "$target_skills" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
print(sum(1 for p in root.rglob("SKILL.md") if p.is_file()))
PY
)"

  write_info "Steering y skills sincronizados para $target_label en $target_kiro_root"
  write_info "Skills detectadas en $target_label: $skill_count"
}

sync_kiro_assets_from_repo() {
  local home_path="$1"
  local workspace_path="$2"
  local zip_url="https://github.com/andersonlugojacome/mcp-kiro-kit/archive/refs/heads/main.zip"
  local temp_root

  temp_root="$(mktemp -d)"
  local zip_path="$temp_root/mcp-kiro-kit-main.zip"
  local extract_path="$temp_root/extracted"

  trap 'rm -rf "$temp_root"' RETURN

  write_info "Descargando assets de steering/skills desde el repositorio..."
  if ! curl -fsSL "$zip_url" -o "$zip_path"; then
    write_warn "No se pudo descargar el paquete de assets."
    return 1
  fi

  mkdir -p "$extract_path"
  if ! unzip -oq "$zip_path" -d "$extract_path"; then
    write_warn "No se pudo extraer el paquete de assets."
    return 1
  fi

  local repo_root="$extract_path/mcp-kiro-kit-main"
  local source_kiro_root="$repo_root/.kiro"
  local source_update_checker="$repo_root/check-mcpkirokit-update.sh"
  local target_tools_dir="$home_path/.kiro/tools"
  local target_update_checker="$target_tools_dir/check-mcpkirokit-update.sh"

  if ! copy_kiro_assets "$source_kiro_root" "$home_path" "usuario"; then
    return 1
  fi

  if [[ -f "$source_update_checker" ]]; then
    mkdir -p "$target_tools_dir"
    cp "$source_update_checker" "$target_update_checker"
    chmod +x "$target_update_checker"
    write_info "Checker de actualizaciones instalado en $target_update_checker"
  fi

  if [[ -n "$workspace_path" && -d "$workspace_path" ]]; then
    copy_kiro_assets "$source_kiro_root" "$workspace_path" "workspace"
  fi

  return 0
}

save_install_metadata() {
  local home_path="$1"
  local installed_version="$2"
  local meta_path="$home_path/.kiro/mcpkirokit-install.json"

  python3 - "$meta_path" "$installed_version" <<'PY'
import datetime as dt
import json
import pathlib
import sys

meta_path = pathlib.Path(sys.argv[1])
installed_version = sys.argv[2]
meta_path.parent.mkdir(parents=True, exist_ok=True)
payload = {
    "installedVersion": installed_version,
    "installedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
}
meta_path.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
PY

  write_info "Version instalada registrada en $meta_path"
}

invoke_daily_update_notice() {
  local home_path="$1"
  local installed_version="$2"
  local checker_path="$home_path/.kiro/tools/check-mcpkirokit-update.sh"

  if [[ ! -f "$checker_path" ]]; then
    return
  fi

  if ! "$checker_path" --installed-version "$installed_version" --quiet-if-checked-today; then
    write_warn "No se pudo ejecutar el chequeo diario de actualizacion"
  fi
}

get_memory_server_package() {
  python3 - "$@" <<'PY'
import json
import pathlib
import sys

result = "engram-mcp-server"

for file_path in sys.argv[1:]:
    path = pathlib.Path(file_path)
    if not path.exists():
        continue

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        continue

    servers = data.get("mcpServers")
    if not isinstance(servers, dict):
        continue

    for server in servers.values():
        args = server.get("args") if isinstance(server, dict) else None
        if not isinstance(args, list):
            continue

        if "engram-mcp-server" in args:
            print("engram-mcp-server")
            raise SystemExit(0)

        if "@modelcontextprotocol/server-memory" in args:
            print("@modelcontextprotocol/server-memory")
            raise SystemExit(0)

print(result)
PY
}

invoke_preflight_npx_package() {
  local package_name="$1"
  local check_label="$2"
  local timeout_seconds="${3:-25}"

  if python3 - "$package_name" "$timeout_seconds" <<'PY'
import subprocess
import sys

package_name = sys.argv[1]
timeout_seconds = int(sys.argv[2])

subprocess.run(
    ["npx", "-y", package_name, "--help"],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    check=True,
    timeout=timeout_seconds,
)
PY
  then
    write_info "Preflight ${check_label}: OK"
    return 0
  fi

  write_warn "Preflight ${check_label}: WARN"
  return 1
}

invoke_mcp_preflight() {
  local memory_server_package="$1"
  local warnings=0

  write_info "Ejecutando preflight MCP (validacion rapida de runtime)"

  if command -v node >/dev/null 2>&1 && node --version >/dev/null 2>&1; then
    write_info "Preflight node: OK"
  else
    write_warn "Preflight node: WARN"
    warnings=$((warnings + 1))
  fi

  if command -v npx >/dev/null 2>&1 && npx --version >/dev/null 2>&1; then
    write_info "Preflight npx: OK"
  else
    write_warn "Preflight npx: WARN"
    warnings=$((warnings + 1))
  fi

  if ! invoke_preflight_npx_package "@upstash/context7-mcp" "Context7" 25; then
    warnings=$((warnings + 1))
  fi

  if ! invoke_preflight_npx_package "$memory_server_package" "memory server ($memory_server_package)" 25; then
    warnings=$((warnings + 1))
  fi

  if [[ $warnings -eq 0 ]]; then
    write_info "Preflight MCP finalizado: OK"
    return
  fi

  write_warn "Preflight MCP finalizado: WARN ($warnings chequeo(s) con problema). La instalacion NO se detuvo."
  write_warn "Sugerencia 1: cerrar y abrir una terminal nueva para refrescar PATH."
  write_warn "Sugerencia 2: revisar proxy/certificados TLS de npm/npx si estas en red corporativa."
  write_warn "Sugerencia 3: fallback con @modelcontextprotocol/server-memory en mcp.json si Engram falla."
}

show_kiro_cli_status() {
  if command -v kiro-cli >/dev/null 2>&1; then
    write_info "Kiro CLI detectado: kiro-cli ($(command -v kiro-cli))"
    return
  fi

  if command -v kiro >/dev/null 2>&1; then
    write_info "Comando Kiro detectado: kiro ($(command -v kiro))"
    return
  fi

  write_warn "No se detecto comando Kiro en PATH (comandos probados: kiro-cli, kiro)."
  write_warn "Verifica instalacion de Kiro y abre una terminal nueva para refrescar PATH."
}

main() {
  ensure_macos
  write_info "Inicio de instalacion MCP para Kiro en macOS"

  ensure_homebrew
  ensure_brew_package "git" "git"
  ensure_brew_package "node" "node"
  ensure_npx

  local user_home="$HOME"
  ensure_kiro_mcp_settings "$user_home"

  if [[ -n "$WORKSPACE_PATH" ]]; then
    if [[ -d "$WORKSPACE_PATH" ]]; then
      ensure_kiro_mcp_settings "$WORKSPACE_PATH"
    else
      write_warn "WorkspacePath no existe: $WORKSPACE_PATH"
    fi
  fi

  if ! sync_kiro_assets_from_repo "$user_home" "$WORKSPACE_PATH"; then
    write_warn "No se pudieron sincronizar skills/steering completos desde el repo."
    write_warn "Se mantiene configuracion base local para no bloquear la instalacion."
    ensure_kiro_base_content "$user_home"
  fi

  save_install_metadata "$user_home" "$MCP_KIRO_KIT_VERSION"
  invoke_daily_update_notice "$user_home" "$MCP_KIRO_KIT_VERSION"

  local user_settings="$user_home/.kiro/settings/mcp.json"
  local memory_server_package="engram-mcp-server"
  if [[ -n "$WORKSPACE_PATH" ]]; then
    memory_server_package="$(get_memory_server_package "$user_settings" "$WORKSPACE_PATH/.kiro/settings/mcp.json")"
  else
    memory_server_package="$(get_memory_server_package "$user_settings")"
  fi

  invoke_mcp_preflight "$memory_server_package"
  show_kiro_cli_status
  write_info "Listo. Reinicia Kiro para aplicar la configuracion MCP."
}

main "$@"
