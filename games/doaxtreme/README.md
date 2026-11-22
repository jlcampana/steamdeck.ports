# Dead or Alive Xtreme Beach Volleyball — `doaxtreme`

- Repo: https://github.com/NoRain211/doaxbv-re (antes `doaxvb-re`, GitHub redirige)
- Release usada: `DOAXBV-<v>-Linux.zip` (código + herramientas, sin juego compilado)
- Versión probada al descargar: v0.7.0
- ISO: `isos/DOAXtreme.iso` (versión USA de Xbox)
- En la Deck: Linux nativo (Vulkan vía SDL3)

## Build

Se compila en Ubuntu 24.04 (Docker en el PC):

```
./build_game.sh /ruta/DOAXtreme.iso      # equivale a --iso <iso>
```

- `tools/setup_env.sh` prepara Python y Capstone en `private/venv`.
- `--extractor <extract-xiso>` si no está en el PATH.
- `--generate-only` para parar antes de compilar (diagnóstico).
- Al terminar escribe `private/setup-*/build-receipt.json` con estado
  `built-unverified`.
- El zip de Linux trae un launcher precompilado
  (`tools/artifacts/launcher-linux-x86_64`, solo necesita glibc 2.34) que
  `launcher.sh` usa sin Python ni compilador.

## Jugar

- `./launcher.sh`: opciones (resolución, MSAA, niebla, volumen, trajes
  desbloqueados, cámara libre…) y **Play**. Guarda en `private/launcher.json`.
- `./run_game.sh`: arranca directamente con las opciones guardadas.
- Añadir `launcher.sh` a Steam como juego no de Steam. Con un mando para dos
  puertos, desactivar Steam Input.

Docs del repo: `docs/building.md` (sección *Linux and SteamOS build*),
`docs/recomp-controls.md`.
