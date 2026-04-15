#!/usr/bin/env bash

set -euo pipefail

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

download_script() {
  local url="$1"
  local destination="$2"

  mkdir -p "$(dirname "$destination")"
  write_info "Descargando $url"
  curl -fsSL "$url" -o "$destination"

  if [[ ! -s "$destination" ]]; then
    write_error "La descarga termino sin contenido: $destination"
    exit 1
  fi
}

run_installer() {
  local installer_path="$1"

  chmod +x "$installer_path"
  if [[ -n "$WORKSPACE_PATH" ]]; then
    "$installer_path" "$WORKSPACE_PATH"
  else
    "$installer_path"
  fi
}

run_verification_friendly() {
  local verify_path="$1"

  if [[ ! -f "$verify_path" ]]; then
    write_warn "No se encontro verify-package-macos.sh. Se omite verificacion final."
    return
  fi

  chmod +x "$verify_path"
  if "$verify_path"; then
    write_info "Verificacion final: OK"
    return
  fi

  write_warn "Verificacion final: WARN. La instalacion ya quedo aplicada; revisa el detalle de verify-package-macos.sh."
}

main() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    write_error "Este script online es solo para macOS."
    exit 1
  fi

  local raw_base="https://raw.githubusercontent.com/andersonlugojacome/mcp-kiro-kit/main"
  local temp_dir
  temp_dir="$(mktemp -d)"
  local installer="$temp_dir/install-mcp-kiro-macos.sh"
  local verify="$temp_dir/verify-package-macos.sh"

  trap 'rm -rf "$temp_dir"' EXIT

  download_script "$raw_base/install-mcp-kiro-macos.sh" "$installer"
  run_installer "$installer"

  download_script "$raw_base/verify-package-macos.sh" "$verify"
  run_verification_friendly "$verify"

  write_info "Instalacion online finalizada correctamente."
}

main "$@"
