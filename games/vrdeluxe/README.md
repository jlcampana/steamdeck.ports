# Virtua Racing Deluxe Enhanced (32X) — `vrdeluxe`

- Repo: https://github.com/PokaMilkTea/VirtuaRacingDeluxeEnhanced
- Release usada: **el código fuente** de la etiqueta (`@source` en
  `ports.tsv`): solo publica binarios de Windows y macOS; para Linux hay que
  compilar con su `Makefile` (`docs/how-to-build.md`).
- Versión probada al descargar: v1.2.2
- Datos: la ROM USA del 32X, `isos/VirtuaRacingDeluxe.32x`
  (SHA-1 `18dfdeb50780c2623e60a6587d7ed701a1cf81f1`, la que pide el README)
- En la Deck: Linux nativo (SDL2 + OpenGL 3.3)

No es una recompilación: es el emulador PicoDrive con los gráficos de la
carrera rehechos en la GPU (HLE): más resolución, MSAA, 60 fps o más,
panorámico y más distancia de dibujado.

## Contenido de la release (código)

- `src/` (el front end `vrde`, el HLE), `third_party/picodrive/` (núcleo de
  PicoDrive, cambios marcados `VRDE:`), `tools/`, `docs/`, `Makefile`.
- `make build/vrde` enlaza con SDL2, libGL y zlib del sistema (en Ubuntu:
  `libsdl2-dev`, `libgl-dev`, `zlib1g-dev`, añadidos a la imagen de build).

## Datos del juego

Sin argumentos, `vrde` juega el primer `.32x` de su propia carpeta, así que
`build.sh` copia la ROM junto al ejecutable (después de comprobar el SHA-1).

## Build

```
games/vrdeluxe/build.sh [-f] [rom.32x]
```

~1 min (compila en el contenedor), 7,1 MB. Paquete `tar.zst`: 2,8 MB.
Deja solo `vrde`, la ROM, `steamdeck.sh` y las licencias (`LICENSE`,
`COPYING.picodrive`: uso no comercial). Necesita SDL2, libGL y zlib (SteamOS
y el runtime del Steam Flatpak los traen) y glibc ≥ 2.38, como los demás
compilados en Ubuntu 24.04.

Comprobado desde otra ruta con su modo de prueba (`vrde -d 1500 -p …`:
1500 fotogramas en una ventana oculta, pulsando Start): arranca el 32X y
llega a la selección de coche; la composición de la GPU coincide con la del
núcleo en todos los fotogramas.

## Jugar

- **Instalar en la Deck:** `tools/package.sh vrdeluxe` y, en la Deck, doble
  clic en `Instalar <Nombre>.desktop`. Nombre en Steam, ejecutable y Proton:
  `game.conf`.
- **Usar `steamdeck.sh`** (punto de entrada común): hace `cd` a la carpeta
  del juego y lanza `vrde`. En Linux, `vrde.ini` (ajustes) y `vrde.mds`
  (estado guardado) van a la carpeta actual, o sea, a la del juego.
- Mando: gatillos para acelerar y frenar (analógicos), stick para girar,
  Back/Guide abre el menú (resolución, fps, 16:9, pantalla completa, guardar
  y cargar estado, salir). Alt+Enter: pantalla completa (se recuerda).

## Imagen Ubuntu 24.04 (contenedor de build)

Usa la imagen común `steamdeck-ports/ubuntu-build:24.04`
([`tools/docker/ubuntu-build.Dockerfile`](../../tools/docker/ubuntu-build.Dockerfile)),
a la que se añadieron `libsdl2-dev`, `libgl-dev` y `zlib1g-dev` para este
juego. `build.sh` ejecuta en ella `make build/vrde`.
