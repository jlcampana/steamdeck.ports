# CLAUDE.md

Guía para Claude Code (y para cualquiera) sobre este proyecto. Toda la
documentación y el registro de trabajo van en el repo, **no** en la memoria de
`~/.claude`. La documentación para usuarios está en `README.md` y en
`games/<id>/README.md`; los requisitos originales, en `leeme.md`.

## Objetivo

Scripts para jugar en una Steam Deck ports (recompilaciones estáticas) de
juegos de Xbox/Xbox 360:

- `update.sh`: descarga la última release de cada repo (`ports.tsv`) en
  `latest/<id>/`, la descomprime en `games/<id>/latest/` y registra versiones en
  `ports.db` (SQLite).
- `games/<id>/build.sh`: genera `games/<id>/build/` (port + assets) listo para la
  Deck. Si hace falta compilar, con un `Dockerfile` dentro de `games/<id>/`.
- `tools/`: herramientas externas y `tools/install.sh` para instalarlas.
- Juegos sin versión Linux → Proton en la Deck.

## Convenciones

- Idioma: español en docs, mensajes de scripts y commits.
- Ids de juego (carpeta `games/<id>`): `doaxtreme`, `doa3`, `doa2u`, `doa1u`,
  `castlevania-son`.
- Nunca subir archivos de juego: `isos/`, `latest/`, `ports.db`,
  `games/*/latest/`, `games/*/build/` están en `.gitignore`.
- Los assets de Castlevania SON los extrae el usuario a mano en
  `isos/Castlevania SON/`.

## Datos que no se deducen del código

- **DOA1U usa `isos/DOA2U.iso`**: no hay ISO propia. El disco trae `Doa1.xbe`
  y `DOA2.xbe` en la raíz (comprobado con `extract-xiso -l`).
- El repo `NoRain211/doaxvb-re` se llama ahora `doaxbv-re` (GitHub redirige);
  en `ports.tsv` está el nombre nuevo.
- Los zips "Linux" de NoRain211 (doaxtreme, doa3, doa2u) **no traen el juego
  compilado**: hay que ejecutar `build_game.sh <iso>` en Ubuntu 24.04
  (SteamOS no tiene compilador). El resultado queda en la propia carpeta
  (`private/`) y funciona en SteamOS (lleva su SDL3; usa
  `libshaderc_shared.so.1` del sistema).
- DOA1U es solo Windows: `assets/` + `DOA1U.exe`, que compila el juego en el
  primer arranque. Necesita D3D12 (Proton/vkd3d).
- Castlevania SON: binario Linux listo. Los paquetes STFS se extraen con
  `scripts/extract_game.py` del repo (no viene en la release; solo stdlib) a
  `assets/xbla-world` y `assets/xbla-jp`. El title update (`addon/TU_…`) **no
  hace falta**: sus cambios están portados en `src/hooks/tu_hooks.cpp`.

## Entorno del PC de build

Fedora (btrfs en `/home`, ~61 GB libres el 2026-11-22), con `docker`,
`podman`, `extract-xiso` v2.7.1 (`~/.local/bin`), `sqlite3`, `jq`, `unzip`,
`curl`, `gh`. Sin `distrobox`. En btrfs, `cp --reflink=auto` copia ISOs sin
gastar espacio.

## Registro de trabajo

### 2026-11-22

1. Leídos `leeme.md` y `ports.md`; propuesta de estructura aceptada.
2. Consultadas las releases de los 5 repos (`gh api …/releases/latest`):
   doaxtreme v0.7.0, doa3 v0.7.1, doa2u v0.4.0, doa1u DOA1U-XBERecomp-V2,
   castlevania-son v1.5.2. Solo hay zip y tar.gz.
3. Escrito `ports.tsv` + `update.sh` (curl + jq + sqlite3; verifica el SHA-256
   con el `digest` de GitHub; aplana la carpeta raíz del archivo). Probado: los
   5 descargados y descomprimidos.
4. Leídos los README y `docs/building.md` de cada repo; revisados los
   `build_game.sh` de NoRain y `extract_game.py` de NocturneRecomp.
5. Documentación: `README.md`, `games/<id>/README.md`, `.gitignore`, este
   `CLAUDE.md`.

### Pendiente

- [ ] `tools/install.sh`.
- [ ] `build.sh` + `Dockerfile` (Ubuntu 24.04) para doaxtreme, doa3, doa2u.
- [ ] `build.sh` de doa1u (extraer la ISO de DOA2U a `assets/`, o copiarla).
- [ ] `build.sh` de castlevania-son (descargar `extract_game.py` del tag,
      extraer world + japan, crear `portable.txt`).
- [ ] Comprobar si los builds de NoRain guardan rutas absolutas (se compilan
      en el PC y se juegan desde otra ruta en la Deck). Si es así, compilar en
      la ruta destino o con distrobox en la Deck.
- [ ] Probar en la Deck.
