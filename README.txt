PAQUETE MCP PARA KIRO (WINDOWS, SIN ADMIN)

1) Copia la carpeta `.kiro` de este PACKAGE a tu home de Windows:
   `C:\Users\<tu-usuario>\.kiro`

2) Abri PowerShell (usuario normal) dentro de esta carpeta PACKAGE y ejecuta:
   `./install-mcp-kiro.ps1`

3) Reinicia Kiro.

4) Validacion basica:
   - `cmd /c npx --version`
   - Revisa `~/.kiro/settings/mcp.json`
   - Confirma que existan `context7` y `engram`

Fallback de Engram:
- Si `engram-mcp-server` no funciona en tu entorno, cambia en `~/.kiro/settings/mcp.json`
  el paquete de `engram` a `@modelcontextprotocol/server-memory`.

Ejemplo de cambio de args de engram:
- De: `"args": ["/c", "npx", "-y", "engram-mcp-server"]`
- A:  `"args": ["/c", "npx", "-y", "@modelcontextprotocol/server-memory"]`

Que es `npx` y por que ayuda:
- `npx` ejecuta paquetes de npm sin instalarlos globalmente de forma manual.
- En equipos sin admin reduce friccion porque no depende de instalaciones globales permanentes.
- Mantiene el setup mas reproducible entre teammates: mismo comando, mismo resultado esperado.
