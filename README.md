# MCPKiroKit para Windows 11

> One command. Any agent. Any OS. The MCPKiroKit ecosystem -- configured and ready.

**Version: 1.0.2**

Paquete listo para dejar tu entorno de Kiro funcionando en Windows 11 con una instalacion guiada por **un solo script**.

## Que instala y configura

Este paquete automatiza:

- **Scoop** como gestor de paquetes en Windows.
- **Git** para clonar repositorios y trabajar con control de versiones.
- **Node.js LTS** (incluye npm).
- **NPX** para ejecutar herramientas Node sin instalarlas globalmente.
- **Configuracion MCP para Kiro** con servidores de **Context7** y **Engram**.
- Sincronizacion de **steering** y **skills** oficiales del repo a `~/.kiro` para que no quede vacio.

## Instalacion rapida

> Requisito: PowerShell 7+ o Windows PowerShell 5.1.

### Opcion A: SIN clonar (one-liner recomendado)

```powershell
iwr -useb "https://raw.githubusercontent.com/andersonlugojacome/mcp-kiro-kit/main/install-mcp-kiro.ps1" -OutFile "$env:TEMP\install-mcp-kiro.ps1"; powershell -ExecutionPolicy RemoteSigned -File "$env:TEMP\install-mcp-kiro.ps1"
```

### Opcion B: script online (`install-online.ps1`)

```powershell
iwr -useb "https://raw.githubusercontent.com/andersonlugojacome/mcp-kiro-kit/main/install-online.ps1" -OutFile "$env:TEMP\install-online.ps1"; powershell -ExecutionPolicy RemoteSigned -File "$env:TEMP\install-online.ps1"
```

`install-online.ps1` descarga `install-mcp-kiro.ps1` al directorio temporal, lo ejecuta con manejo de errores/TLS 1.2/salida UTF-8 y luego corre `verify-package.ps1` en modo amigable.

Resultado de verificacion online:

- **OK**: instalacion y validacion final correctas.
- **WARN**: la validacion detecto algo para revisar, pero la instalacion ya quedo aplicada.

Si la descarga falla, verifica la conexion a internet, que la URL este bien escrita y que no haya un bloqueo de red/proxy.

### Opcion C: descargar ZIP desde GitHub

```powershell
# 1) Descarga y extrae el ZIP desde GitHub en una carpeta local
# 2) Entra a la carpeta PACKAGE del proyecto extraido
cd C:\ruta\al\proyecto\PACKAGE
powershell -ExecutionPolicy RemoteSigned -File .\install-mcp-kiro.ps1
```

### Verificacion manual (opcional)

Al terminar, ejecuta:

```powershell
powershell -ExecutionPolicy RemoteSigned -File .\verify-package.ps1
```

Si todo sale bien, el script de verificacion confirma dependencias y configuracion MCP.

Tambien valida que haya skills reales instaladas (`SKILL.md`) en `~/.kiro/skills`.

### Preflight MCP al finalizar instalacion

El instalador `install-mcp-kiro.ps1` ahora corre un **preflight MCP** al final para validar ejecucion real de runtime:

- Verifica disponibilidad de `node` y `npx` en la sesion actual.
- Ejecuta chequeo rapido de Context7 con `cmd /c npx -y @upstash/context7-mcp --help` (con timeout).
- Ejecuta chequeo rapido del servidor de memoria configurado (`engram-mcp-server` o `@modelcontextprotocol/server-memory`) con la misma estrategia.

Interpretacion del resultado:

- **OK**: checks de runtime respondieron bien; la instalacion queda lista para uso inmediato.
- **WARN**: uno o mas checks fallaron o expiraron, pero la instalacion **no se corta**. Segui las sugerencias en consola (reiniciar terminal, revisar proxy/cert corporativo, o usar fallback `@modelcontextprotocol/server-memory`).

## Que es `npx` (explicado simple)

`npx` es una herramienta de Node.js que permite ejecutar paquetes directamente (por ejemplo, servidores MCP) sin tener que instalarlos globalmente en tu sistema.

## Estructura del paquete

```text
PACKAGE/
|- .kiro/
|  |- steering/
|  \- skills/
|- scoop/
|  \- mcp-kiro-kit.json
|- install-mcp-kiro.ps1
|- install-online.ps1
|- verify-package.ps1
\- README.md
```

## Distribucion con Scoop bucket

Tambien podes distribuir **MCPKiroKit** via Scoop sin pedir al usuario que clone este repo.

```powershell
scoop bucket add mcpkirokit https://github.com/andersonlugojacome/scoop-bucket
scoop install mcp-kiro-kit
```

Importante: esta opcion requiere un repositorio de bucket separado (por ejemplo `scoop-bucket`) con el manifiesto `mcp-kiro-kit.json`.

## Cambiar Engram por fallback `@modelcontextprotocol/server-memory`

Si queres usar memoria local fallback en lugar de Engram, edita la configuracion MCP que deja el instalador (normalmente en `.kiro/mcp.json` o el archivo equivalente de Kiro) y cambia el servidor de memoria.

Ejemplo de bloque de servidor fallback:

```json
{
  "memory": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-memory"]
  }
}
```

Luego reinicia Kiro para que recargue los servidores MCP.

## Despues de instalar: configuracion a nivel proyecto

Una vez que ya configuraste los agentes en Kiro, en cada proyecto conviene registrar contexto inicial para que el orquestador trabaje con mejor precision.

| Comando | Qué hace | Cuándo volver a ejecutarlo |
| --- | --- | --- |
| `/sdd-init` | Detecta stack, capacidades de testing y activa Strict TDD Mode si esta disponible. | Cuando arranques un proyecto nuevo o cambie la base tecnica del repo. |
| `skill-registry` | Escanea skills instaladas y convenciones del proyecto, y construye el registro. | Cuando agregues/borres skills o cambien convenciones relevantes del proyecto. |

Nota: esto no es obligatorio para uso basico. El orquestador SDD ejecuta `/sdd-init` automaticamente si no detecta contexto, pero si cambio el proyecto (por ejemplo, nuevo test runner o nuevas dependencias) conviene re-ejecutarlo manualmente para mantener el contexto actualizado.

## Actualizacion rapida

Cuando salga una mejora de MCPKiroKit, podes actualizar en pocos pasos.

### Opcion recomendada (online)

```powershell
iwr -useb "https://raw.githubusercontent.com/andersonlugojacome/mcp-kiro-kit/main/install-online.ps1" -OutFile "$env:TEMP\install-online.ps1"; powershell -ExecutionPolicy RemoteSigned -File "$env:TEMP\install-online.ps1"
```

Esta opcion vuelve a sincronizar configuracion MCP, steering y skills sin romper lo que ya tenes.

### Si ves errores viejos (cache), forzar update limpio

```powershell
$script = "$env:TEMP\install-mcp-kiro.ps1"
Remove-Item $script -ErrorAction SilentlyContinue
$ts = [int][double]::Parse((Get-Date -UFormat %s))
$url = "https://raw.githubusercontent.com/andersonlugojacome/mcp-kiro-kit/main/install-mcp-kiro.ps1?nocache=$ts"
iwr -UseBasicParsing -Headers @{ "Cache-Control"="no-cache"; "Pragma"="no-cache" } $url -OutFile $script -ErrorAction Stop
powershell -ExecutionPolicy RemoteSigned -File $script
```

Este flujo evita ejecutar una copia vieja guardada en `%TEMP%` o cacheada por proxy.

### Opcion manual (si ya tenes el paquete descargado)

```powershell
cd C:\ruta\al\proyecto\PACKAGE
powershell -ExecutionPolicy RemoteSigned -File .\install-mcp-kiro.ps1
```

### Verificacion post-actualizacion

```powershell
powershell -ExecutionPolicy RemoteSigned -File .\verify-package.ps1
```

Si estas dentro de un proyecto, despues de actualizar conviene re-ejecutar `/sdd-init` y `skill-registry` para refrescar el contexto del agente.

## Desinstalacion

Si en algun momento queres remover todo lo instalado por este paquete, segui estos pasos.

> Advertencia: hace backup antes de borrar archivos de configuracion.
> Ejemplo rapido:
> ```powershell
> Copy-Item "$env:USERPROFILE\.kiro\settings\mcp.json" "$env:USERPROFILE\.kiro\settings\mcp.json.bak" -ErrorAction SilentlyContinue
> ```

1) **Quitar configuracion MCP de Kiro**

- Si queres remover todo el archivo MCP creado por este setup:
  ```powershell
  Remove-Item "$env:USERPROFILE\.kiro\settings\mcp.json" -ErrorAction SilentlyContinue
  ```
- Si preferis conservar el archivo, editalo y elimina solo las entradas de `context7` y `engram` (o el bloque de memoria fallback que hayas agregado), manteniendo el resto de servidores que uses.

2) **Eliminar steering y skills instaladas por este paquete**

- Borra solo los directorios/archivos relacionados con MCPKiroKit dentro de `~/.kiro/steering/` y `~/.kiro/skills/`.
- Si identificas carpetas creadas para este kit, podes quitarlas de forma explicita:
  ```powershell
  Remove-Item "$env:USERPROFILE\.kiro\steering\mcp-kiro-kit" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item "$env:USERPROFILE\.kiro\skills\mcp-kiro-kit" -Recurse -Force -ErrorAction SilentlyContinue
  ```

3) **(Opcional) Desinstalar herramientas de Scoop**

- Hace este paso solo si `git` y/o `nodejs-lts` se instalaron exclusivamente para este fin y no los usas en otros proyectos.
- Verifica primero si estan instalados:
  ```powershell
  scoop list git
  scoop list nodejs-lts
  ```
- Si corresponde, desinstala:
  ```powershell
  scoop uninstall git
  scoop uninstall nodejs-lts
  ```

4) **Limpiar script temporal de instalacion online**

- Si usaste `install-online.ps1`, elimina los archivos temporales descargados:
  ```powershell
  Remove-Item "$env:TEMP\install-online.ps1" -ErrorAction SilentlyContinue
  Remove-Item "$env:TEMP\install-mcp-kiro.ps1" -ErrorAction SilentlyContinue
  ```

Al finalizar, reinicia Kiro para confirmar que ya no cargue servidores o recursos removidos.

## Roadmap (futuro)

### KIRO Powers

Lista inicial por features para evolucionar el kit:

- **Power 1: Contexto inteligente por proyecto**
  - Deteccion automatica de stack, frameworks y runner de tests.
  - Recomendaciones de comandos segun tipo de repo.

- **Power 2: Reuso con memoria (Engram-first)**
  - Buscar soluciones previas antes de proponer cambios nuevos.
  - Resumen de decisiones anteriores para evitar retrabajo.

- **Power 3: Soporte de documentacion viva (Context7)**
  - Consulta automatica de docs actualizadas para librerias detectadas.
  - Referencias de fuente en respuestas tecnicas clave.

- **Power 4: Health check ampliado**
  - Verificacion de skills instaladas, conectividad MCP y estado de mcp.json.
  - Reporte final en formato simple: OK, WARN, BLOQUEO.

- **Power 5: Actualizacion guiada**
  - Update seguro de instalador, steering y skills con cache-busting.
  - Notas de cambios cortas para usuarios no tecnicos.

- **Power 6: Perfil de equipo (Team preset)**
  - Presets de reglas y flujo por tipo de equipo/proyecto.
  - Configuracion reproducible para onboarding rapido.

### KIRO Powers for Teams

- **Power 7: Team governance**
  - Politicas por equipo para definir herramientas permitidas, acciones restringidas y niveles de aprobacion.
  - Reglas claras para auditoria y uso seguro en ambientes corporativos.

- **Power 8: Perfiles por tipo de proyecto**
  - Plantillas listas (`frontend`, `backend`, `data`, `mobile`) con steering y skills recomendadas.
  - Menos configuracion manual y mejor consistencia entre equipos.

- **Power 9: Memoria con trazabilidad**
  - Cuando se reutilice una solucion de Engram, mostrar origen resumido (que, cuando y en que contexto).
  - Evita retrabajo y mejora transferencia de conocimiento.

- **Power 10: Canales de actualizacion**
  - Canal `stable` para adopcion general y canal `canary` para pruebas tempranas.
  - Reduce riesgo al desplegar mejoras de instalacion y skills.

- **Power 11: Diagnostico corporativo previo**
  - Chequeo de conectividad, proxy/certificados y resolucion npm antes de ejecutar MCP.
  - Recomendaciones automaticas para resolver bloqueos frecuentes.

- **Power 12: Reporte final para soporte**
  - Salida estandar `OK`, `WARN` o `BLOQUEO` con causa principal y siguiente paso sugerido.
  - Facilita soporte de mesa de ayuda y seguimiento tecnico.

## Troubleshooting rapido

- **ExecutionPolicy bloquea scripts**
  - Ejecuta PowerShell con permisos de tu usuario y usa:
    ```powershell
    powershell -ExecutionPolicy RemoteSigned -File .\install-mcp-kiro.ps1
    ```
- **`npx` no se reconoce**
  - Cierra y abre la terminal.
  - Verifica Node y npx:
    ```powershell
    node -v
    npx -v
    ```
  - Si `node` responde pero `npx` no, reinstala Node LTS con Scoop y vuelve a abrir la sesion.
- **Kiro no detecta MCP**
  - Revisa que la configuracion MCP exista y sea JSON valido.
  - Reinicia Kiro por completo.
  - Ejecuta `verify-package.ps1` para validar rutas y comandos.
- **`SKILL.md not for skill` en `_shared`**
  - Si aparece `~/.kiro/skills/_shared/SKILL.md`, es un archivo legado no valido.
  - Borralo y corre update:
    ```powershell
    Remove-Item "$env:USERPROFILE\.kiro\skills\_shared\SKILL.md" -ErrorAction SilentlyContinue
    iwr -useb "https://raw.githubusercontent.com/andersonlugojacome/mcp-kiro-kit/main/install-online.ps1" -OutFile "$env:TEMP\install-online.ps1"; powershell -ExecutionPolicy RemoteSigned -File "$env:TEMP\install-online.ps1"
    ```

## Seguridad

- No subas secretos (tokens, API keys, credenciales) al repositorio.
- Usa variables de entorno para inyectar secretos en tiempo de ejecucion.
- Si compartis configuraciones, publica solo placeholders (por ejemplo: `ENGRAM_API_KEY=<tu_valor>`).

## Licencia

Se sugiere publicar este proyecto bajo licencia **MIT**.
