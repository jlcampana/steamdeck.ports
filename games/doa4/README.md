# Dead or Alive 4 Online — `doa4`

- Repo: https://github.com/dwreckgg/doa4-online (recompilación estática con el
  [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk); fork de
  parkerallan/doa4-recomp con juego online 1v1)
- Release usada: `DOA4-alpha-v<x.y.z>-win64.zip` (solo Windows)
- Versión probada al descargar: alpha-v0.3.7
- **Solo publica prereleases** (`alpha-v…`; las `netplay-v1.0.x` son antiguas):
  no hay release «latest», así que `update.sh` coge la más reciente que tenga
  el archivo de `ports.tsv`.
- ISO: `isos/DOA4.iso`, *Dead or Alive 4 (USA, Europe) (Rev 1)* de Xbox 360
  (7,8 GB; `default.xex` en la raíz, comprobado con `extract-xiso -l`).
- En la Deck: **Proton**.

## Contenido de la release

`dead_or_alive_4.exe`, `rexruntime.dll`, `TracyClient.dll`,
`SHA256SUMS.txt` (de los tres), `README-netplay.txt` y
`THIRD_PARTY_NOTICES.md`. Ningún dato del juego.

## Datos del juego y configuración

En el primer arranque el juego abre una pantalla de configuración para
elegir la ISO o una carpeta extraída. En la Deck eso significa usar un diálogo
de archivos, así que se evita:

- `build.sh` extrae la ISO en `build/game/` (con `default.xex` en la raíz).
- El juego busca los datos en `--game_data_root`, si se le pasa; si no, en
  `doa4_game_files` de `dead_or_alive_4.toml`, junto al exe; y si tampoco, abre
  la pantalla de configuración (`src/dead_or_alive_4_app.h`, `OnFinalizePaths`).
  Las partidas y la caché de shaders van a `doa4_user_data`, o por defecto a
  `Documents\dead_or_alive_4` (dentro del prefijo de Proton).
- Esas rutas son absolutas y de Windows (en Proton, `Z:` = `/`, con barras
  normales), así que dependen de dónde se instale. Las escribe en la Deck
  **`deck-post-install.sh`**, que `tools/package.sh` mete en el paquete como
  `post-install.sh` y que `instalar.sh` ejecuta tras descomprimir:
  `doa4_game_files = "Z:<destino>/game"` y
  `doa4_user_data = "Z:<destino>/user_data"`. Así las partidas quedan en la
  carpeta del juego, como en los demás juegos. Son claves de primer nivel del
  `.toml`; el script conserva el resto del archivo.

## Problema en Proton: congelación al arrancar (hasta alpha-v0.3.7)

En cada arranque el juego abre el puerto UDP 1000 (system link). En Linux
solo root puede abrir puertos por debajo de 1024: con Wine la apertura falla y
el juego, que no comprueba el resultado, se queda bloqueado leyendo ese socket
en el hilo principal ([issue #12](https://github.com/dwreckgg/doa4-online/issues/12)).
Está arreglado en el código para la 0.3.8 (todavía sin publicar el
2026-11-24).

Solución temporal: `net.ipv4.ip_unprivileged_port_start=1000`. El paso de
instalación lo ofrece **solo hasta alpha-v0.3.7** y lo guarda en
`/etc/sysctl.d/99-doa4.conf` (pide la contraseña de sudo de la Deck).
Efecto secundario: cualquier programa del usuario puede abrir los puertos
1000–1023. Para quitarlo: `sudo rm /etc/sysctl.d/99-doa4.conf` y reiniciar.

## Build

```
games/doa4/build.sh            # isos/DOA4.iso
games/doa4/build.sh -f otra.iso
```

No compila nada: copia la release, extrae la ISO en `game/` (~45 s; 6,8 GB) y
comprueba el `SHA256SUMS.txt` de la release.

## Jugar

- **Instalar en la Deck:** `tools/package.sh doa4` y, en la Deck, doble clic en
  `Instalar Dead or Alive 4.desktop` (ver «Distribución a la Steam Deck» en el
  README principal). Nombre en Steam, ejecutable y Proton: `game.conf`. Las
  notas que lleva el README del paquete están en `deck-notes.md`.
- En Steam hay que forzar Proton (Propiedades → Compatibilidad).
- Menú del juego con **Esc**: gráficos, pantalla, controles, idioma, online.
- Online: solo con quien tenga la misma release (pestaña Online, Host/Join).
  Una versión compilada por uno mismo solo conecta con la misma versión.
- Trajes de DOAX2 (opcionales): ISO **USA** de Dead or Alive Xtreme 2, desde
  Esc → Extras.
- Requisitos del port: CPU con AVX2 (la Deck lo tiene) y el runtime de VC++
  2015-2022 (Proton trae su implementación).

## Linux nativo (no usado)

Desde la 0.3.8 el código compila como programa nativo de Linux (sección 12 de
`docs/BUILDING.md`: clang 23, Ubuntu 24.04; hasta 4 h con `-j2`). No hay
release Linux, el arranque está poco probado y un build propio no juega online
con la release, así que se usa la de Windows con Proton.

## Imagen Ubuntu 24.04 (contenedor de build)

Este juego **no usa contenedor ni Dockerfile**: la release ya viene compilada
y `build.sh` solo copia archivos y extrae la ISO en el propio PC. La imagen
Ubuntu 24.04 solo la usan los ports que se compilan (doaxtreme, doa3, doa2u),
con un Dockerfile compartido en
[`tools/docker/ubuntu-build.Dockerfile`](../../tools/docker/ubuntu-build.Dockerfile).
