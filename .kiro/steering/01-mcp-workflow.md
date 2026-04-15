---
inclusion: always
---

# MCP Workflow (Context7 + Engram)

## Objetivo
Tener Kiro operativo con MCP de forma segura, portable e idempotente.

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
4. Probar cada server con `npx -y <package> --help` (en Windows puede usarse `cmd /c` como wrapper) para detectar fallos temprano.
5. Reiniciar Kiro para levantar configuracion nueva.
6. Ejecutar una consulta de humo: docs en Context7 + registro en Engram.
7. Antes de iniciar tareas nuevas, revisar si ya existe solucion previa en Engram y reutilizarla.
8. Durante sesiones largas, aplicar ciclo continuo: **Engram en cada consulta + Context7 cada 4 consultas**.

## Buenas Practicas
- Mantener JSON limpio y valido, sin comentarios.
- Evitar rutas absolutas de una sola maquina en skills y steering.
- No persistir secretos en archivos de equipo.
- Si `engram-mcp-server` falla, usar fallback `@modelcontextprotocol/server-memory`.
- Si Context7 no responde, continuar con contexto local + Engram y reintentar en el siguiente checkpoint de 4 consultas.
- En respuestas largas, incluir un bloque corto de "fuente usada" para dejar trazabilidad de cuando se consulto Context7.

## Troubleshooting Rapido
- `npx` falla: reinstalar/validar `nodejs-lts` y abrir nueva terminal.
- Package MCP no responde: probar conectividad npm y volver a ejecutar con `-y`.
- Kiro no detecta cambios: verificar ruta `~/.kiro/settings/mcp.json` y reiniciar app.
- Contexto desactualizado en sesiones largas: forzar refresh de Context7 y resetear contador local de ciclo (0->1).
