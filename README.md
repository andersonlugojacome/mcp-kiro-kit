# MCPKiroKit para Windows 11

> One command. Any agent. Any OS. The MCPKiroKit ecosystem -- configured and ready.

**Version: 1.0.0**

Paquete listo para dejar tu entorno de Kiro funcionando en Windows 11 con una instalacion guiada por **un solo script**.

## Que instala y configura

Este paquete automatiza:

- **Scoop** como gestor de paquetes en Windows.
- **Git** para clonar repositorios y trabajar con control de versiones.
- **Node.js LTS** (incluye npm).
- **NPX** para ejecutar herramientas Node sin instalarlas globalmente.
- **Configuracion MCP para Kiro** con servidores de **Context7** y **Engram**.
- Archivos base de **steering** y **skills** para trabajar con mejores practicas en flujos asistidos por IA.

## Instalacion rapida

> Requisito: PowerShell 7+ o Windows PowerShell 5.1.

### Opcion A: SIN clonar (one-liner recomendado)

```powershell
iwr -useb "https://raw.githubusercontent.com/andersonlugojacome/mcp-kiro-kit/main/install-mcp-kiro.ps1" -OutFile "$env:TEMP\install-mcp-kiro.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\install-mcp-kiro.ps1"
```

### Opcion B: script online (`install-online.ps1`)

```powershell
iwr -useb "https://raw.githubusercontent.com/andersonlugojacome/mcp-kiro-kit/main/install-online.ps1" -OutFile "$env:TEMP\install-online.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\install-online.ps1"
```

`install-online.ps1` descarga `install-mcp-kiro.ps1` al directorio temporal y lo ejecuta con manejo de errores, TLS 1.2 y salida en UTF-8.

Si la descarga falla, verifica la conexion a internet, que la URL este bien escrita y que no haya un bloqueo de red/proxy.

### Opcion C: descargar ZIP desde GitHub

```powershell
# 1) Descarga y extrae el ZIP desde GitHub en una carpeta local
# 2) Entra a la carpeta PACKAGE del proyecto extraido
cd C:\ruta\al\proyecto\PACKAGE
powershell -ExecutionPolicy Bypass -File .\install-mcp-kiro.ps1
```

### Verificacion

Al terminar, ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File .\verify-package.ps1
```

Si todo sale bien, el script de verificacion confirma dependencias y configuracion MCP.

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

## Troubleshooting rapido

- **ExecutionPolicy bloquea scripts**
  - Ejecuta PowerShell con permisos de tu usuario y usa:
    ```powershell
    powershell -ExecutionPolicy Bypass -File .\install-mcp-kiro.ps1
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

## Seguridad

- No subas secretos (tokens, API keys, credenciales) al repositorio.
- Usa variables de entorno para inyectar secretos en tiempo de ejecucion.
- Si compartis configuraciones, publica solo placeholders (por ejemplo: `ENGRAM_API_KEY=<tu_valor>`).

## Licencia

Se sugiere publicar este proyecto bajo licencia **MIT**.
