# Drakengard 3 (PS3) — `drakengard3`

- Repo: https://github.com/soyjxck/dod3-recomp (sobre ps3recomp)
- Release usada: `dod3-recomp-<v>-linux-x86_64.tar.gz` (binario listo;
  **solo publica prereleases**, `update.sh` coge la más reciente)
- Versión probada al descargar: v0.5.0-alpha
- Datos: disco USA (BLUS31197) en `isos/Drakengard3.iso` (**descifrada**) y
  la actualización 1.01 en
  `isos/UP0082-BLUS31197_00-DOD3PATCH0000000-A0101-V0101-PE.pkg`
- En la Deck: Linux nativo (experimental según upstream; probado por el autor
  en la Deck en modo escritorio)

## Contenido de la release

`dod3` (ejecutable e instalador; usa el SDL2 del sistema y Vulkan 1.3,
glibc ≥ 2.38), `dod3.ini` (ajustes), `shaders/override/`, `README.md` y
licencias.

## Datos del juego

`dod3` instala el juego desde los archivos originales, con interfaz (Dear
ImGui) o sin ella:

```
dod3 --install <disco .iso o carpeta> <update .pkg> [DLC .pkg…]
```

- **Disco:** solo el USA (BLUS31197) v01.00. Lo comprueba con el SHA-256 del
  `PS3_GAME/USRDIR/EBOOT.BIN`, así que una ISO cifrada (la de un lector
  normal) se rechaza. La nuestra está descifrada y coincide.
- **Update 1.01:** obligatoria y **solo como `.pkg`** (o un `EBOOT.ELF` 1.01
  ya descifrado). Una update ya instalada en carpeta (estilo RPCS3,
  `dev_hdd0/game/BLUS31197`) no sirve.
- **DLC:** opcionales (`UP0082-NPUB31251_00-….pkg`); `build.sh` coge los que
  haya en `isos/`.

Lo deja todo junto al ejecutable: `elf/EBOOT_101.ELF` (descifrado),
`game/disc/` (el disco, 14,7 GB) y `game/disc/game/BLES00000` (la update).
Los datos que el juego copiaría al disco duro en el primer arranque
(`COOKEDPS3`, `COOKEDSOUND`) los enlaza con **enlaces relativos** (en Linux),
así que la carpeta se puede mover.

## Build

```
games/drakengard3/build.sh [-f] [disco [update.pkg [dlc.pkg…]]]
```

~2 min 15 s (copia desde el disco externo), 16 GB; paquete `tar.zst` de
15 GB (~5 min: los datos del disco ya van comprimidos). Comprueba que no quedan
enlaces absolutos. Probado desde otra ruta con `DOD3_LAUNCHER=0`: abre
Vulkan, carga el juego y dibuja (~28 fps a 1280x720 en una RX 6400);
partidas y caché se crean en la propia carpeta.

## Jugar

- **Instalar en la Deck:** `tools/package.sh drakengard3` y, en la Deck,
  doble clic en `Instalar <Nombre>.desktop`. Nombre en Steam, ejecutable y
  Proton: `game.conf`.
- **Usar `steamdeck.sh`** (punto de entrada común): lanza `dod3`, que abre
  el launcher (Play, mods, DLC, ajustes). `DOD3_LAUNCHER=0 %command%` en las
  opciones de lanzamiento de Steam entra directo al juego.
- Partidas y trofeos en `gamedata/`, ajustes en `dod3.ini`, log en
  `dod3.log` (todo en la carpeta del juego).
- Guía del port: `docs/PLAYING.md` del repo (controles, ajustes, variables
  `DOD3_*`).

## Imagen Ubuntu 24.04 (contenedor de build)

Este juego **no usa contenedor ni Dockerfile**: la release ya viene compilada
y `build.sh` solo ejecuta su instalador en el propio PC. La imagen Ubuntu
24.04 solo la usan los ports que se compilan (doaxtreme, doa3, doa2u), con un
Dockerfile compartido en
[`tools/docker/ubuntu-build.Dockerfile`](../../tools/docker/ubuntu-build.Dockerfile).
