# SoulCalibur (Dreamcast) — `soulcalibur`

- Repo: https://github.com/enrique363/voldorium (Voldorium)
- Release usada: `Voldorium-<v>-linux.tar.gz` (ejecutable listo; también
  hay `-windows.zip`)
- Versión probada al descargar: v1.2.3
- Datos: el disco USA como `isos/SoulCalibur.chd` (GD-ROM)
- En la Deck: Linux nativo (SDL2 + OpenGL; glibc ≥ 2.28)

No hay paquete específico para Steam Deck: el README dice que vale la
versión de Linux (o la de Windows con Proton), sin probar aún en una Deck
real.

## Contenido de la release

- `voldorium`: el motor (SDL2, OpenGL). **No trae el juego:** el código del
  juego es `sc_game.so`, que se genera a partir del disco del usuario.
- `builder/`: `first_run.sh` y `tools/build.py` (descarga Zig 0.14.1 y dos
  archivos de Flycast con SHA-256 fijo, extrae `1ST_READ.BIN` del disco,
  lo traduce a C y compila `sc_game.so`).
- `voldorium.ini` (ajustes, con notas), `savestate_ranges.tsv` (rollback),
  `textures/`, `art16x9/`, `README.txt`.

## Datos del juego

Pide un volcado `.gdi` (pistas de 2352 bytes; comprueba el SHA-1 de
`IP.BIN` y `1ST_READ.BIN`). `build.sh` convierte el CHD con
`chdman extractcd` a `disc/SoulCalibur.gdi` + 3 pistas (1,3 GB). El juego
lee el disco también al jugar, así que va en el paquete.

## Build

```
games/soulcalibur/build.sh [-f] [disco.chd|disco.gdi]
```

Lo que el juego haría en su primer arranque se hace en el PC: en el
contenedor, `build.py --download --only module` (el mismo paso que
`builder/first_run.sh`) deja `sc_game.so` junto a `voldorium`. Así la Deck
no descarga ni compila nada. Luego borra el compilador y los intermedios
(`builder/toolchain`, `work`, `extracted`, `port/build`) y escribe
`disc = disc/SoulCalibur.gdi` en `voldorium.ini` (ruta relativa a la carpeta
actual; `steamdeck.sh` hace `cd` a la del juego).

~3 min (conversión + 2 min 45 s de `build.py`), 1,3 GB. Paquete: 707 MB.
Comprobado desde otra ruta con `steamdeck.sh --seconds 25` (en ventana):
lee el disco, carga `sc_game.so`, audio, 749 fotogramas.

## Jugar

- **Instalar en la Deck:** `tools/package.sh soulcalibur` y, en la Deck,
  doble clic en `Instalar <Nombre>.desktop`. Nombre en Steam, ejecutable y
  Proton: `game.conf`.
- **Usar `steamdeck.sh`** (punto de entrada común): `cd` a la carpeta del
  juego y lanza `voldorium`.
- El primer arranque elige los gráficos según la máquina (en la Deck, sin
  imágenes HI-RES y con TEXT ORIGINAL) y los guarda en `voldorium.ini`.
- Partidas: `vmu_a1.bin` (tarjeta de memoria) junto al ejecutable.
- Online Versus (lobby, rollback) con jugadores de la misma versión, de
  Linux o Windows: hace falta el mismo `sc_game.so`, que sale igual en todos
  los PC porque el compilador está fijado.
- `sc_game.so` es código del juego: no compartirlo.

## Imagen Ubuntu 24.04 (contenedor de build)

Usa la imagen común `steamdeck-ports/ubuntu-build:24.04`
([`tools/docker/ubuntu-build.Dockerfile`](../../tools/docker/ubuntu-build.Dockerfile))
solo para Python 3: `build.py` descarga su propio compilador (Zig) en
`builder/toolchain/`. No hace falta ningún paquete más.
