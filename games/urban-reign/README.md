# Urban Reign (PS2) — `urban-reign`

- Repo: https://github.com/thiagordsfx/urban-reign-recomp
- Release usada: `UrbanReignPC-<v>-linux-x86_64.tar.gz` (binario listo,
  compilado en el Steam Runtime; también publican un `.deb`)
- Versión probada al descargar: v1.4.1
- Datos: el disco USA (`SLUS-21209`) como `isos/UrbanReign.chd` (DVD)
- En la Deck: Linux nativo

## Contenido de la release

- `urban-reign`: script de arranque. Sin argumentos abre el launcher
  (`launcher/urban_launcher.py`, Python + GTK + WebKit); con `--game` lanza el
  juego directamente.
- `game/urban` (RUNPATH `$ORIGIN`) con sus `.so` (SDL3, `libpcsx2gs.so`: el
  renderizador de PCSX2 en Vulkan, libpng, shaderc), `resources/` (shaders),
  `mods/` (`CoopTool`, hasta 8 jugadores; `ExampleMod`) y `textures/`.
- `install-shortcut.sh`, `README.txt`, licencias.

## Datos del juego

El port necesita la imagen del disco en **`.iso`** y la busca en
`config.ini` (`[Game] Iso=`) o, si está vacío, como cualquier `*.iso` en
`game/`. La nuestra es un CHD de DVD, así que `build.sh` la convierte con
`chdman extractdvd` (paquete `mame-tools`, lo instala `tools/install.sh`) a
`game/UrbanReign.iso` (3,9 GB) y comprueba que es `SLUS_212.09`. Con una
`.iso`, la copia.

## Build

```
games/urban-reign/build.sh [-f] [imagen .chd o .iso]
```

~1 min (la conversión del CHD), 3,8 GB. Paquete `tar.zst`: 1,5 GB.
Comprobado desde otra ruta: arranca, lee el disco, abre Vulkan (PCSX2 GS) y
reproduce la intro; `libSDL3` sale de la propia carpeta. El `config.ini`
que crea no guarda rutas absolutas.

## Jugar

- **Instalar en la Deck:** `tools/package.sh urban-reign` y, en la Deck,
  doble clic en `Instalar <Nombre>.desktop`. Nombre en Steam, ejecutable y
  Proton: `game.conf`.
- **Usar `steamdeck.sh`** (punto de entrada común): lanza
  `urban-reign --game`, sin el launcher. El launcher necesita Python con GTK
  y WebKit (`gi`), que SteamOS no trae de serie; el juego no lo necesita.
- Ajustes en `game/config.ini` (resolución interna, relación de aspecto,
  renderizador, `StartFullscreen`) y `game/controls.ini` (mandos, formato de
  PCSX2); se crean con comentarios en el primer arranque. Tarjetas de memoria
  en `game/memcards/`.
- En el juego: F11 pantalla completa, F2 menú del juego (mods), F5/F9
  guardar/cargar estado.
- Texturas HD: un pack de PCSX2 en `game/textures/SLUS-21209`.

## Imagen Ubuntu 24.04 (contenedor de build)

Este juego **no usa contenedor ni Dockerfile**: la release ya viene compilada
y `build.sh` solo convierte la imagen del disco en el propio PC. La imagen
Ubuntu 24.04 solo la usan los ports que se compilan (doaxtreme, doa3, doa2u),
con un Dockerfile compartido en
[`tools/docker/ubuntu-build.Dockerfile`](../../tools/docker/ubuntu-build.Dockerfile).
