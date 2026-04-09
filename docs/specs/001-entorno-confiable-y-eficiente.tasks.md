# Tasks - Spec 001 (Entorno confiable y eficiente)

## Enfoque

Prioridad inicial: **R2 + R3**

- R2: verificacion tecnica obligatoria
- R3: sincronizacion de skills/steering

Duracion sugerida: **1 semana**

## Semana 1 - Backlog ejecutable

### Fase 1 (Dia 1-2) - Hardening de verificacion tecnica (R2)

1. **Definir matriz de chequeos obligatorios**
   - Entradas: `node`, `npx`, `context7`, `engram`, `mcp.json`, skills instaladas.
   - Salida: formato de resultado estandar `OK | WARN | BLOQUEO`.

2. **Unificar salida de estado en instalador y verificador**
   - Alinear mensajes de `install-mcp-kiro.ps1` y `verify-package.ps1`.
   - Incluir resumen final legible para usuarios no tecnicos.

3. **Agregar pruebas de errores frecuentes**
   - Simular: JSON invalido, package MCP no responde, skill faltante, cache vieja.
   - Validar que cada error tenga remediacion clara.

4. **Criterio de salida de Fase 1**
   - El verificador detecta y clasifica errores en los escenarios definidos.
   - El usuario recibe siguiente paso accionable en menos de 3 lineas por error.

### Fase 2 (Dia 3-4) - Sincronizacion robusta de skills/steering (R3)

5. **Blindar sincronizacion desde repo**
   - Validar descarga de assets.
   - Manejar fallback local sin romper instalacion.

6. **Validar integridad de skills**
   - Confirmar presencia de `SKILL.md` en skills ejecutables.
   - Excluir `_shared` como skill ejecutable.

7. **Agregar chequeo de conteo minimo de skills**
   - Definir umbral esperado (ej. 10+ skills).
   - Marcar `WARN` si conteo queda por debajo.

8. **Criterio de salida de Fase 2**
   - Instalacion/update deja skills y steering completos en `~/.kiro`.
   - `verify-package.ps1` confirma conteo y estructura valida.

### Fase 3 (Dia 5) - Documentacion operacional y handoff

9. **Actualizar README en secciones clave**
   - Instalacion, update, troubleshooting, estado MCP.
   - Agregar tabla de validaciones y significado de estados.

10. **Crear guia corta para soporte interno**
   - "Si ves X, hace Y" para 5 incidentes comunes.
   - Version compacta para mesa de ayuda.

11. **Criterio de salida de Fase 3**
   - Cualquier integrante puede ejecutar install/update y autodiagnosticar fallos basicos.

## Definition of Done (Semana 1)

- [ ] `install-mcp-kiro.ps1` emite resumen final `OK/WARN/BLOQUEO`.
- [ ] `verify-package.ps1` valida MCP + skills + estructura.
- [ ] Sync de assets (`.kiro/steering`, `.kiro/skills`) estable y reproducible.
- [ ] README actualizado con flujos de install/update/diagnostico.
- [ ] Evidencia de al menos 3 corridas exitosas en entornos distintos.

## Riesgos y mitigaciones

- **Proxy/certificados corporativos**
  - Mitigacion: mensajes de remediacion y cache-busting.

- **Cambios de estructura en repo remoto**
  - Mitigacion: fallback local + verificacion de integridad.

- **Variabilidad de PowerShell 5 vs 7**
  - Mitigacion: pruebas de parser y sintaxis compatible.

## Siguiente iteracion recomendada (Semana 2)

- Implementar R5 completo (aviso de version + update guiada con telemetria local minima).
- Empezar medicion formal de R4 (ahorro de creditos/tokens en flujos repetidos).
