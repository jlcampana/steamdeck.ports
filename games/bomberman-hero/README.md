# Bomberman Hero (N64) — `bomberman-hero`

- Repo: https://github.com/RevoSucks/BMHeroRecomp (N64: Recompiled + RT64)
- Release usada: `BMHeroRecompiled-Linux-X64-Release.zip` (binario Linux x86-64 listo)
- Versión probada al descargar: v0.7.1 (**solo prereleases**: `update.sh` coge la más reciente)
- Datos: ROM USA 1.0 en `isos/BombermanHero.z64` (`.z64`)
- En la Deck: Linux nativo

No hay versión específica para Steam Deck: la release trae también AppImage y
Flatpak, pero el README del port dice que el binario de Linux vale en la
Deck, y es el que usamos (sin instalar nada en el sistema).

## Contenido de la release

Un zip con `BMHeroRecompiled.tar.gz` dentro: `BMHeroRecompiled` (ejecutable; RUNPATH
`/usr/local/lib`, que no molesta), `assets/` (menús RmlUi, fuentes) y
`recompcontrollerdb.txt`. Usa SDL2, GTK 3 y FreeType del sistema (SteamOS
los trae) y Vulkan (RT64).

## Datos del juego

El port no es un emulador: solo acepta **la ROM USA 1.0 sin modificar** y la
comprueba con XXH3-64 (`rom_hash` en `src/main/main.cpp`:
`0x89134c0e1f16e0f8`). Normalmente se elige en su menú de inicio y la guarda como
`bmhero.z64` en su carpeta de datos (`~/.config/BMHeroRecompiled`, o la carpeta
actual si hay `portable.txt`).
bomberman-hero0
## Build

```
games/bomberman-hero/build.sh [-f] [rom]
```

Con [`tools/n64recomp.sh`](../../tools/n64recomp.sh) (común a los ports de
N64Recomp): comprueba la ROM (XXH3 con `xxhsum -H3` o el módulo
`xxhash` de Python; si no hay ninguno, SHA-1 de una ROM ya comprobada),
descomprime el `.tar.gz`, copia la ROM como `bmhero.z64` y crea
`portable.txt` y `steamdeck.sh`. Así el juego **no pide la ROM**.
Segundos; ~34 MB (paquete 16 MB).

## Jugar

- **Instalar en la Deck:** `tools/package.sh bomberman-hero` y «Ports por red» o el
  `.desktop` del paquete.
- **Usar `steamdeck.sh`** (hace `cd` a su carpeta: `portable.txt` se
  busca en la carpeta actual). **Sin Proton.**
- Menú de ajustes propio (gráficos, FPS, controles, sonido, mods), con mando.
- Partidas en `saves/`, ajustes en `*.json` y mods en `mods/`, en la
  carpeta del juego (`KEEP` de `game.conf`).

## Imagen Ubuntu 24.04 (contenedor de build)

Este juego **no usa contenedor ni Dockerfile**: la release ya viene compilada
y `build.sh` solo copia archivos.
