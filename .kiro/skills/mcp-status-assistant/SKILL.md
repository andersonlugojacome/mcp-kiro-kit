---
name: mcp-status-assistant
description: >
  Muestra un estado rapido de MCPKiroKit: servidores MCP activos, estado de Context7 y Engram,
  tipo de base de datos de Engram y tamano en disco.
  Trigger: cuando el usuario pida "estatus", "estado mcp", "status", "resumen de mcp".
license: MIT
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Objetivo

Entregar en el chat un resumen tecnico y claro del estado MCP local.

## Que debe verificar

1. Configuracion MCP en `~/.kiro/settings/mcp.json`:
   - confirmar existencia de `context7` y `engram` en `mcpServers`.
   - mostrar command/args principales de cada server.

2. Estado de Engram local:
   - ruta: `~/.engram/engram.db`.
   - tipo de DB (esperado: SQLite 3.x).
   - tamano total de `~/.engram` y tamano por archivo (`engram.db`, `engram.db-wal`, `engram.db-shm`).

3. Estado de runtime MCP:
   - `node -v`
   - `npx -v`
   - chequeo rapido:
     - `cmd /c npx -y @upstash/context7-mcp --help`
     - `cmd /c npx -y engram-mcp-server --help`

## Formato de respuesta

Responder con secciones cortas:

- `Configuracion MCP`
- `Engram DB`
- `Runtime`
- `Estado final` (`OK`, `WARN` o `BLOQUEO`)

Siempre incluir datos concretos (rutas y tamano) y una accion recomendada si hay WARN.

## Regla de claridad

- No inventar valores.
- Si algo no se puede leer, marcarlo como `WARN` con motivo.
- Mantener respuesta breve y accionable para usuario no tecnico.
