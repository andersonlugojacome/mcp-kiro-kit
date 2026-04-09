---
name: kiro-update-assistant
description: >
  Guia actualizaciones de MCPKiroKit en Kiro con instrucciones simples y seguras.
  Trigger: Cuando el usuario diga "actualizame", "actualiza", "update" o pida actualizar el setup.
license: MIT
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Objetivo

Responder con pasos claros para actualizar MCPKiroKit sin friccion.

## Comportamiento esperado

1. Si el usuario pide actualizar, devolver primero el comando online recomendado:

```powershell
iwr -useb "https://raw.githubusercontent.com/andersonlugojacome/mcp-kiro-kit/main/install-online.ps1" -OutFile "$env:TEMP\install-online.ps1"; powershell -ExecutionPolicy RemoteSigned -File "$env:TEMP\install-online.ps1"
```

2. Si menciona errores viejos o comportamiento inconsistente, devolver el flujo de update con cache-busting:

```powershell
$script = "$env:TEMP\install-mcp-kiro.ps1"
Remove-Item $script -ErrorAction SilentlyContinue
$ts = [int][double]::Parse((Get-Date -UFormat %s))
$url = "https://raw.githubusercontent.com/andersonlugojacome/mcp-kiro-kit/main/install-mcp-kiro.ps1?nocache=$ts"
iwr -UseBasicParsing -Headers @{ "Cache-Control"="no-cache"; "Pragma"="no-cache" } $url -OutFile $script -ErrorAction Stop
powershell -ExecutionPolicy RemoteSigned -File $script
```

3. Al final, sugerir verificacion manual:

```powershell
powershell -ExecutionPolicy RemoteSigned -File "$env:TEMP\verify-package.ps1"
```

## Mensaje de salida sugerido

- Estado corto: que comando correr ahora.
- Explicacion breve: por que usar update online o cache-busting.
- Cierre: "reinicia Kiro" y confirmar `OK/WARN` de la verificacion.

## Regla de claridad

- Priorizar instrucciones de una sola copia/pegado.
- Evitar bloques largos si el usuario no los pidio.
- No mencionar politicas internas; enfocarse en guia tecnica.
