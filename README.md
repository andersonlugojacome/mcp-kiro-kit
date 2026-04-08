# MCPKiroKit para Windows 11

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

### Opcion A: clonar el repositorio (recomendada)

```powershell
git clone https://github.com/TU-USUARIO/TU-REPO.git
cd TU-REPO\PACKAGE
powershell -ExecutionPolicy Bypass -File .\install-mcp-kiro.ps1
```

### Opcion B: descargar ZIP desde GitHub

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

## Que es `npx` (explicado simple)

`npx` es una herramienta de Node.js que permite ejecutar paquetes directamente (por ejemplo, servidores MCP) sin tener que instalarlos globalmente en tu sistema.

## Estructura del paquete

```text
PACKAGE/
|- .kiro/
|  |- steering/
|  \- skills/
|- install-mcp-kiro.ps1
|- verify-package.ps1
\- README.md
```

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
