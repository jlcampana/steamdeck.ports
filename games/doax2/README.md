# Dead or Alive Xtreme 2 Recomp — `doax2`

> **Obsoleto** (2026-11-27): lo sustituye [`doax2-linux`](../doax2-linux/README.md),
> nativo y con menú de opciones con mando. Se conserva (`DEPRECATED=1` en
> `game.conf`): `update.sh`, `package.sh`, `fetch-art.sh` y `serve.sh` se lo
> saltan salvo que se nombre.

- Repo: https://github.com/hibikifukui22/Dead-or-Alive-Xtreme-2-Recompilation
  (recompilación estática con el ReXGlue SDK v0.10.0 más un parche propio:
  renderizadores nativos D3D12/Vulkan, 60 FPS)
- Release usada: `DOAX2-Recomp-v<x.y.z>-win64.zip` (solo Windows). La release
  trae también `-source.zip` (código + SDK), que usa
  [`doax2-linux`](../doax2-linux/README.md).
- Versión al añadirlo: v1.2.2.
- ISO: `isos/DOAX2.iso`, disco retail de Xbox 360 (title ID `544307D2`,
  `default.xex` con SHA-256
  `c4a14853e1f7af951be34f380604113703638780b36d5e74e674fe7431992870`,
  comprobado por `build.sh`). Sin title updates.
- En la Deck: **Proton**.

## Contenido de la release

`DOAX2 Recomp Launcher.exe` (lanzador Win32), `out/game/doax2.exe` con
`rexruntime.dll`, `rexgpu-xenos.dll` y el runtime de VC++,
`extracted game files here/` (vacía), `README.txt`, licencias.

Ojo: el zip usa `\` en las rutas (`unzip` avisa y sale con 1) y la carpeta
`out/game` viene sin permiso de lectura. `update.sh` acepta el 1 de `unzip`
y hace `chmod -R u+rwX` al descomprimir.

## Datos del juego y configuración

- `build.sh` extrae la ISO en `extracted game files here/`, donde la busca el
  lanzador.
- El lanzador arranca `out/game/doax2.exe` con unas 50 opciones
  (`--game_data_root`, `--user_data_root=userdata`, renderizador,
  resolución, 30/60 FPS…; ver `src/launcher_public.cpp`, `Launch()`), todas
  con rutas relativas a su carpeta: no hace falta `post-install.sh`.
- Partidas: `userdata/` (copia en `save-backup/` al abrir el lanzador);
  ajustes: `config/launcher.ini`; fotos: `photos/`. Van en `KEEP`.
- La página **Update** del lanzador se actualiza sola desde GitHub: mejor no
  usarla (las versiones llegan por `update.sh` y el paquete).

## Build

```
games/doax2/build.sh            # isos/DOAX2.iso
games/doax2/build.sh -f otra.iso
```

No compila nada: copia la release y extrae la ISO (~40 s; 6,3 GB; paquete
2,9 GB).

## Jugar

- En Steam hay que forzar Proton. Se abre el lanzador: 30/60 FPS y PLAY.
  **Vulkan (Native)** en *Graphics Settings* es el que recomienda el port.
- Notas del paquete: `deck-notes.md`. Imágenes: de momento las más votadas
  de SteamGridDB (`tools/pick-art.sh doax2 …` para cambiarlas).
- Sin probar todavía con Proton (ni en el PC ni en la Deck).

## Imagen Ubuntu 24.04 (contenedor de build)

Este juego **no usa contenedor**: `build.sh` solo copia archivos y extrae la
ISO. La versión nativa, `doax2-linux`, sí compila (imagen
`tools/docker/rexglue-build.Dockerfile`).
