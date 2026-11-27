# Bomberman 64 (N64) — `bomberman64`

- Repo: https://github.com/RevoSucks/BM64Recomp (N64: Recompiled + RT64)
- Release usada: `BM64Recompiled-Linux-X64-Release.zip` (binario Linux x86-64 listo)
- Versión probada al descargar: v1.0.0
- Datos: ROM USA 1.0 en `isos/Bomberman64.z64` (`.z64`)
- En la Deck: Linux nativo

No hay versión específica para Steam Deck: la release trae también AppImage y
Flatpak, pero el README del port dice que el binario de Linux vale en la
Deck, y es el que usamos (sin instalar nada en el sistema).

## Contenido de la release

Un zip con `BM64Recompiled.tar.gz` dentro: `BM64Recompiled` (ejecutable; RUNPATH
`/usr/local/lib`, que no molesta), `assets/` (menús RmlUi, fuentes) y
`recompcontrollerdb.txt`. Usa SDL2, GTK 3 y FreeType del sistema (SteamOS
los trae) y Vulkan (RT64).

## Datos del juego

El port no es un emulador: solo acepta **la ROM USA 1.0 sin modificar** y la
comprueba con XXH3-64 (`rom_hash` en `src/main/main.cpp`:
`0xc4c0b74bbb696426`). Normalmente se elige en su menú de inicio y la guarda como
`bm64_us.z64` en su carpeta de datos (`~/.config/BM64Recompiled`, o la carpeta
actual si hay `portable.txt`).
bomberman640
## Build

```
games/bomberman64/build.sh [-f] [rom]
```

Con [`tools/n64recomp.sh`](../../tools/n64recomp.sh) (común a los ports de
N64Recomp): comprueba la ROM (XXH3 con `xxhsum -H3` o el módulo
`xxhash` de Python; si no hay ninguno, SHA-1 de una ROM ya comprobada),
descomprime el `.tar.gz`, copia la ROM como `bm64_us.z64` y crea
`portable.txt` y `steamdeck.sh`. Así el juego **no pide la ROM**.
Segundos. Aún sin build (falta la ROM buena).

## Jugar

- **Instalar en la Deck:** `tools/package.sh bomberman64` y «Ports por red» o el
  `.desktop` del paquete.
- **Usar `steamdeck.sh`** (hace `cd` a su carpeta: `portable.txt` se
  busca en la carpeta actual). **Sin Proton.**
- Menú de ajustes propio (gráficos, FPS, controles, sonido, mods), con mando.
- Partidas en `saves/`, ajustes en `*.json` y mods en `mods/`, en la
  carpeta del juego (`KEEP` de `game.conf`).

## Imagen Ubuntu 24.04 (contenedor de build)

Este juego **no usa contenedor ni Dockerfile**: la release ya viene compilada
y `build.sh` solo copia archivos.
