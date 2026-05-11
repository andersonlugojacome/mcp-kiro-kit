---
inclusion: always
---

# MCP Workflow (Context7 + Engram)

## Objetivo
Tener Kiro operativo con MCP de forma segura, portable e idempotente.

Este workflow se complementa con la politica de ejecucion en background definida en `./02-sdd-orchestrator-runtime.md`.

## Politica de Orquestacion Continua (obligatoria)
1. En **cada consulta del usuario**, ejecutar primero una consulta en **Engram** para recuperar contexto previo relevante.
2. Mantener un contador de consultas de usuario en la sesion (`mcp_query_count`).
3. Refrescar **Context7 cada 4 consultas** (`mcp_query_count % 4 == 0`), incluso si ya hay contexto local.
4. Si hay incertidumbre tecnica (versiones, API, breaking changes), consultar Context7 de inmediato sin esperar al ciclo de 4.
5. Registrar en Engram decisiones, fixes y hallazgos no obvios al cerrar cada bloque de trabajo.

## Flujo Recomendado
1. Verificar base del entorno: `git`, `node`, `npx` disponibles.
2. Validar conectividad minima (internet y resolucion npm).
3. Confirmar `~/.kiro/settings/mcp.json` con servidores `context7` y `engram`.
4. Antes de actualizar Engram, detectar DB existente y generar backup versionado.
5. Intentar reutilizacion/migracion de DB hacia `~/.engram` para continuidad de memoria.
6. Probar cada server con `npx -y <package> --help` (en Windows puede usarse `cmd /c` como wrapper) para detectar fallos temprano.
7. Si falla el arranque de Engram canonico, conservar backup, pasar a `@modelcontextprotocol/server-memory` y dejar instrucciones de restauracion.
8. Reiniciar Kiro para levantar configuracion nueva.
9. Ejecutar una consulta de humo: docs en Context7 + registro en Engram.
10. Antes de iniciar tareas nuevas, revisar si ya existe solucion previa en Engram y reutilizarla.
11. Durante sesiones largas, aplicar ciclo continuo: **Engram en cada consulta + Context7 cada 4 consultas**.

## Buenas Practicas
- Mantener JSON limpio y valido, sin comentarios.
- Evitar rutas absolutas de una sola maquina en skills y steering.
- No persistir secretos en archivos de equipo.
- Usar `engram mcp` si existe el binario `engram`; si no, usar paquete npm `engram-mcp-server`.
- Si Engram falla, usar fallback `@modelcontextprotocol/server-memory` sin borrar backup de DB.
- Si Context7 no responde, continuar con contexto local + Engram y reintentar en el siguiente checkpoint de 4 consultas.
- En respuestas largas, incluir un bloque corto de "fuente usada" para dejar trazabilidad de cuando se consulto Context7.
- Para upstream/fuente canonica de Engram, referenciar `https://github.com/Gentleman-Programming/engram`.
- Para tags/releases de Engram, mantener notacion con prefijo `v` (`vX.Y.Z`).

## Troubleshooting Rapido
- `npx` falla: reinstalar/validar `nodejs-lts` y abrir nueva terminal.
- Package MCP no responde: probar conectividad npm y volver a ejecutar con `-y`.
- Kiro no detecta cambios: verificar ruta `~/.kiro/settings/mcp.json` y reiniciar app.
- Contexto desactualizado en sesiones largas: forzar refresh de Context7 y resetear contador local de ciclo (0->1).
