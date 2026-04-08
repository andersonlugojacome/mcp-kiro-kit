# Kiro AGENTS (MCP + Verificacion)

## Objetivo
Guiar a Kiro para trabajar con alta confiabilidad tecnica, minimo consumo de tokens y seguridad MCP en equipos Windows sin privilegios de admin.

## Reglas Operativas
- Verifica primero: no afirmes nada tecnico sin comprobar archivos, comandos o docs.
- Cambios idempotentes: si se ejecuta dos veces, no rompe ni duplica configuracion.
- Seguridad MCP: no hardcodees secretos, tokens, paths personales ni credenciales en prompts o archivos.
- Menos ruido, mas señal: respuestas compactas, accionables y con evidencia.
- No edites fuera del alcance pedido; evita side effects en el workspace.

## Politica de Seguridad
- Nunca escribas API keys en `.kiro/settings/mcp.json` ni en steering.
- Usa variables de entorno para credenciales cuando un server lo requiera.
- Redacta logs sin datos sensibles.
- Si detectas material sensible en texto plano, reportalo y propone remediacion.

## Verificacion Tecnica Obligatoria
1. Confirmar prerequisitos (`git`, `node`, `npx`).
2. Validar JSON antes de guardar configuraciones.
3. Probar comandos MCP con `cmd /c npx -y <paquete> --help` cuando aplique.
4. Informar resultado con estado claro: OK, warning o bloqueo.

## Eficiencia de Tokens
- Prioriza contexto local y archivos del proyecto antes de buscar afuera.
- Evita repetir diagnosticos; reusa hallazgos ya verificados.
- Resume salidas largas y conserva solo lineas relevantes.
- Para tareas grandes, dividir en pasos cortos con checkpoints.

## Uso de Contexto Local
- Leer primero `.kiro/steering/` y `.kiro/skills/` del repo activo.
- Si hay conflicto entre global y local, priorizar local del equipo.
- Mantener rutas portables dentro de `.kiro/skills`.

## Criterio de Calidad de Entrega
- Configuracion reproducible para teammates nuevos.
- Documentacion corta, verificable y sin ambiguedades.
- Scripts con mensajes claros de error y recuperacion.
