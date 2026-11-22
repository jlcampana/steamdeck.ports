# Castlevania: Symphony of the Night (Xbox 360 Arcade) — `castlevania-son`

- Repo: https://github.com/birabittoh/NocturneRecomp (basado en ReXGlue SDK)
- Release usada: `nocturnerecomp-<v>-linux-amd64.tar.gz` (binario ya compilado)
- Versión probada al descargar: v1.5.2
- Datos: paquetes XBLA `LIVE`/STFS (sin extensión) en `isos/Castlevania SON/`,
  extraídos por el usuario de su copia.
- En la Deck: Linux nativo

## Contenido de la release

`nocturnerecomp`, `librexruntime.so`, `libTracyClient.so`, `shaders/`, `game/`
(vacía) y `README.md`.

## Datos del juego

| Paquete | Destino en la biblioteca | Aporta |
|---|---|---|
| `world version/9F2DAA064D494AA82B43B65362C59E9B89A88F8F58` | `assets/xbla-world` | juego base (obligatorio si no hay JP) |
| `japan version/EB9399B31E4A9181AA7F8F6B7F6ABD3263DDA24058` | `assets/xbla-jp` | vídeos, voces japonesas, arte de Dracula X |
| `addon/TU_1C42227_000010G000000.00000000000G4` | — | no hace falta (title update ya portado en `src/hooks/tu_hooks.cpp`) |

Con los dos instalados se usan juntos; F4 → General permite *Force English
Voices* y elegir el arte (Auto / JP / World).

Formas de instalarlos:

1. Desde el juego: pantalla de inicio → **Select File** → **Extract**.
2. Sin interfaz: `scripts/extract_game.py` del repo (no viene en la release;
   se descarga en el mismo tag). Solo usa la librería estándar de Python:

   ```
   python3 extract_game.py "<paquete>" --assets <build>/assets [--force]
   ```

   Identifica la versión por el SHA-256 del `default.xex` y, para World, copia
   `default.xex` a `assets/default.xex`.

## Jugar

- Un `portable.txt` vacío junto al binario guarda partidas, opciones y caché
  al lado del juego.
- Rutas configurables en `nocturnerecomp.toml` o con `--nombre=valor`:
  `game_data_root` (assets), `user_data_root`, `cache_root`, `mods_data_root`,
  `mods_dump_root`, `update_data_root`.
- **En la Deck, usar `steamdeck.sh`** (lo genera `build.sh`), el punto de
  entrada común de todos los juegos Linux: lanza `nocturnerecomp` desde su
  carpeta. Añadirlo a Steam como juego no de Steam.
- `build.sh` crea `portable.txt`, así que partidas y opciones quedan dentro
  de la carpeta del juego.

## Imagen Ubuntu 24.04 (contenedor de build)

Este juego **no usa contenedor ni Dockerfile**: la release ya viene compilada
y `build.sh` solo copia archivos y prepara `assets/` en el propio PC. La
imagen Ubuntu 24.04 solo la usan los ports que se compilan (doaxtreme, doa3,
doa2u), con un Dockerfile compartido en
[`tools/docker/ubuntu-build.Dockerfile`](../../tools/docker/ubuntu-build.Dockerfile).
