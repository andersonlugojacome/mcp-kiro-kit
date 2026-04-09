# Spec 001 - Entorno confiable y eficiente para MCPKiroKit

## Objetivo

Establecer una base estandar para que cualquier integrante del equipo use Kiro con MCPKiroKit de forma estable, reproducible y con bajo costo operativo (tokens/creditos), minimizando retrabajo.

## Alcance

- Instalacion y actualizacion simple en modo usuario local.
- Configuracion MCP operativa (`context7` y `engram`) con verificacion.
- Skills y steering sincronizados en `~/.kiro`.
- Reuso de contexto previo para reducir costo por tareas repetidas.

## Fuera de alcance (por ahora)

- UI de extension nativa dentro de Kiro.
- Integraciones empresariales SSO/IdP.
- Telemetria centralizada multi-equipo.

## Requisitos

### R1. Setup reproducible en una sola ejecucion

El sistema debe permitir instalar y dejar operativo MCPKiroKit con un flujo de una sola ejecucion, sin pasos manuales avanzados.

#### Escenario: Instalacion inicial del equipo
- Dado un equipo con Kiro y PowerShell
- Cuando ejecuta el instalador recomendado
- Entonces queda configurado MCP, steering y skills en rutas de usuario
- Y se obtiene salida de estado clara (`OK` o `WARN`).

### R2. Verificacion tecnica obligatoria

El sistema debe validar precondiciones y runtime MCP antes de finalizar.

#### Escenario: Validacion de runtime
- Dado que `node` y `npx` estan presentes
- Cuando corre el preflight
- Entonces se valida Context7 y Engram con chequeo rapido
- Y se reporta estado por componente.

### R3. Sincronizacion de conocimiento operativo

El sistema debe sincronizar skills y steering oficiales para evitar entornos vacios o inconsistentes.

#### Escenario: Entorno con skills incompletas
- Dado un usuario con carpeta de skills parcial
- Cuando ejecuta update
- Entonces se sincronizan skills oficiales desde el repositorio
- Y la verificacion confirma presencia de `SKILL.md` validas.

### R4. Reuso de contexto para eficiencia de costo

El sistema debe favorecer la reutilizacion de contexto previo (Engram + skills) en tareas repetidas.

#### Escenario: Repeticion de comando SDD
- Dado que una tarea ya fue inicializada previamente
- Cuando se vuelve a ejecutar el flujo equivalente
- Entonces el agente reutiliza contexto y reduce tokens/creditos
- Y la tendencia de ahorro puede medirse en comparativas de ejecucion.

### R5. Actualizacion guiada y segura

El sistema debe ofrecer un camino de actualizacion simple, con opcion de cache-busting, y aviso de nuevas versiones.

#### Escenario: Version desactualizada detectada
- Dado un usuario con version instalada anterior
- Cuando se ejecuta el chequeo diario
- Entonces se informa que hay nueva version disponible
- Y se sugiere accion directa: `actualizame`.

## Criterios de exito

- Tiempo de onboarding tecnico reducido.
- Menos errores de configuracion reportados.
- Mayor porcentaje de instalaciones exitosas en primer intento.
- Reduccion de costo en flujos repetidos gracias al contexto persistente.

## Recomendacion para iniciar

Iniciar por **R2 + R3** (verificacion tecnica y sincronizacion de skills/steering).

Motivo:
- Son la base de confiabilidad para todo el equipo.
- Evitan falsos positivos de "instalado" cuando realmente falta contexto.
- Preparan el terreno para capturar ahorro real en R4 de forma consistente.
