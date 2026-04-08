---
inclusion: always
---

# MCP Workflow (Context7 + Engram)

## Objetivo
Tener Kiro operativo con MCP de forma segura, portable e idempotente.

## Flujo Recomendado
1. Verificar base del entorno: `git`, `node`, `npx` disponibles.
2. Validar conectividad minima (internet y resolucion npm).
3. Confirmar `~/.kiro/settings/mcp.json` con servidores `context7` y `engram`.
4. Probar cada server con `cmd /c npx -y <package> --help` para detectar fallos temprano.
5. Reiniciar Kiro para levantar configuracion nueva.
6. Ejecutar una consulta de humo: docs en Context7 + registro en Engram.

## Buenas Practicas
- Mantener JSON limpio y valido, sin comentarios.
- Evitar rutas absolutas de una sola maquina en skills y steering.
- No persistir secretos en archivos de equipo.
- Si `engram-mcp-server` falla, usar fallback `@modelcontextprotocol/server-memory`.

## Troubleshooting Rapido
- `npx` falla: reinstalar/validar `nodejs-lts` y abrir nueva terminal.
- Package MCP no responde: probar conectividad npm y volver a ejecutar con `-y`.
- Kiro no detecta cambios: verificar ruta `~/.kiro/settings/mcp.json` y reiniciar app.
