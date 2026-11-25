# Virtua Fighter 3 Team Battle (arcade Sega Model 3) — `vf3tb`

- Repo: https://github.com/mr-finster/vf3-recomp (Virtua Fighter 3 Recomp)
- Release usada: `VirtuaFighter3Recomp-deck.tar.gz`, el **paquete para Steam
  Deck / Linux x86-64** (binario listo, compilado en el Steam Runtime de Valve)
- Versión probada al descargar: v0.1.22-alpha (la «latest»; hay prereleases
  más nuevas, `v0.1.23-alpha-beta1`, que `update.sh` no coge)
- Datos: set de MAME `vf3tb` completo en `isos/VF33tb.zip`
- En la Deck: Linux nativo

## Contenido de la release

`vf3` (ejecutable, RUNPATH `$ORIGIN/lib`), `lib/libSDL3.so.0`,
`VirtuaFighter3.sh` (hace `cd` a su carpeta y lanza `vf3`), `assets/`
(fuentes, interfaz, icono), `roms/` (vacía), `README.txt` y `LICENSES.txt`.

## Datos del juego

No hay ISO: el port lee el set de MAME y **recompila el programa PowerPC de la
placa en cada arranque** (unos 0,2 s). Busca en `roms/` (o en `--roms`,
`VF3_ROMS` o `roms_folder` de `settings.ini`):

| Zip | Juego |
|---|---|
| `vf3.zip` | Virtua Fighter 3, Revision D (el principal del port) |
| `vf3tb.zip` | Team Battle. El set **completo** de MAME (39 ROM, incluye las `mpr-19xxx` de vf3) funciona solo; el «split» necesita `vf3.zip` al lado |

`isos/VF33tb.zip` es el set completo: `build.sh` lo copia como
`roms/vf3tb.zip` y comprueba que trae las ROM de Team Battle (`epr-20126…`)
y las de vf3 (`mpr-19197…`). Si se le da también un `vf3.zip`, lo pone en
`roms/` y el menú Game → Version cambia entre los dos (`--game vf3|tb` para
una sola partida).

## Build

```
games/vf3tb/build.sh [-f] [vf3tb.zip] [vf3.zip]
```

Solo copia archivos (segundos, 87 MB) y crea `portable.txt` y `steamdeck.sh`.
Comprobado desde otra ruta con `VF3_HIDDEN=1 VF3_QUIT_AFTER=600` (el port lo
admite para pruebas): carga `roms/vf3tb.zip`, recompila, usa Vulkan y sale
bien; `log.txt` dice «playing Virtua Fighter 3 Team Battle».

## Jugar

- **Instalar en la Deck:** `tools/package.sh vf3tb` y, en la Deck, doble clic
  en `Instalar <Nombre>.desktop`. Nombre en Steam, ejecutable y Proton:
  `game.conf`.
- **Usar `steamdeck.sh`** (punto de entrada común): lanza
  `VirtuaFighter3.sh`. **Sin Proton** (el README del port avisa de que
  Proton impide arrancarlo).
- Arranca a pantalla completa a 16:10 y escala 2x en la Deck; si no llega,
  baja la escala sola.
- Menú: View (Select) o L3 + R3 o clic del touchpad.
- Ajustes, clasificaciones, capturas y `log.txt` en la carpeta del juego
  (`portable.txt`).

## Imagen Ubuntu 24.04 (contenedor de build)

Este juego **no usa contenedor ni Dockerfile**: la release ya viene compilada
para la Deck y `build.sh` solo copia archivos. La imagen Ubuntu 24.04 solo la
usan los ports que se compilan (doaxtreme, doa3, doa2u), con un Dockerfile
compartido en
[`tools/docker/ubuntu-build.Dockerfile`](../../tools/docker/ubuntu-build.Dockerfile).
