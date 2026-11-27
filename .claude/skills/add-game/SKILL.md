---
name: add-game
description: Añade un port nuevo al proyecto steamdeck.ports (entrada en ports.tsv, games/<id>/build.sh, verificación y documentación). Usar cuando el usuario diga que hay un juego nuevo, lo haya añadido a ports.md, o invoque /add-game.
argument-hint: "[nombre del juego o URL de releases]"
---

# /add-game — añadir un port nuevo

Argumento (opcional): $ARGUMENTS. Si no viene, busca en `ports.md` la entrada
que no esté todavía en `ports.tsv`. Si hay varias o ninguna, pregunta.

Lee antes `CLAUDE.md` (convenciones, datos clave) y `tools/lib.sh` (funciones
disponibles). Usa como referencia el `build.sh` existente más parecido:

| Tipo de port | Referencia |
|---|---|
| Código que se compila en Linux con una ISO de Xbox | `games/doa3/build.sh` |
| Igual, pero el build pide un venv/pip | `games/doa2u/build.sh` |
| Binario Linux listo + paquetes STFS de Xbox 360 | `games/castlevania-son/build.sh` |
| Solo Windows (Proton) + ISO extraída en `assets/` | `games/doa1u/build.sh` |
| Solo Windows (Proton) + ISO de Xbox 360 + rutas en un `.toml` al instalar | `games/doa4/build.sh` y `deck-post-install.sh` |
| Port de ReXGlue solo Windows, pero con código portable: versión Linux compilada aquí (SDK + codegen + juego) | `games/doax2-linux/build.sh` (o `games/doa4-linux/build.sh` si el código generado viene en el repo) |
| Port de N64: Recompiled (RT64) con binario Linux: ROM `.z64` + `portable.txt` | `games/bomberman-hero/build.sh` (`tools/n64recomp.sh`) |

Todo en español: mensajes de los scripts, docs y commits.

## Pasos

1. **Id y `ports.tsv`.** Elige un id en minúsculas con guiones (`games/<id>`).
   Consulta la última release (`gh api repos/<repo>/releases/latest --jq
   '.tag_name, .assets[].name'`). Si el repo se ha renombrado, usa el nombre
   nuevo. Añade a `ports.tsv` la línea `id<TAB>owner/repo<TAB>regex`: la regex
   elige el archivo de Linux x86-64, o el de Windows si no hay versión Linux
   (→ Proton). Si el juego aún no está en `ports.md`, añádelo con el mismo
   formato que los demás.
   **Comprueba si hay versión específica para Steam Deck/SteamOS** además de
   la de Linux: archivos de la release, README, docs (sección SteamOS) o
   scripts como `build_steamdeck.sh`. Si la hay, valora usarla en vez de la
   de Linux/Windows y cuéntaselo al usuario antes de seguir.

2. **Descarga.** `GITHUB_TOKEN=$(gh auth token) ./update.sh <id>` y mira qué
   trae `games/<id>/latest`: ¿un binario listo para usar o código para compilar?

3. **Investiga el port.** Lee el README del repo
   (`gh api repos/<repo>/readme -H "Accept: application/vnd.github.raw"`) y su
   doc de build (p. ej. `docs/building.md`, sección Linux/SteamOS). Lee los
   scripts de la release (`build_game.sh`, `run_game.sh`…). Anota: qué datos
   del juego pide (ISO, `.xbe`, paquete STFS…), dónde los busca, cómo se lanza,
   dependencias y si su documentación contradice al código.

4. **Datos del juego.** Mira `isos/` y confirma con el usuario qué ISO o
   paquete corresponde. Puede ser compartida (DOA1U usa `DOA2U.iso`). Verifica
   el contenido (`tools/bin/extract-xiso -l <iso>`). Nunca subas archivos de
   juego a git.

5. **`games/<id>/build.sh`.** Cabecera con lo que hace y el uso
   (`[-f] [ruta]`). Usa `tools/lib.sh`:
   `require_latest`, `require_file`, `prepare_build "$FORCE"`,
   `run_in_container …` si hay que compilar (imagen
   `steamdeck-ports/ubuntu-build:24.04`), `check_absolute_paths`,
   `write_steamdeck_launcher <ejecutable>` si el juego es Linux (punto de
   entrada común `steamdeck.sh`) y `finish_build`.
   - Si faltan paquetes en la imagen: añádelos a
     `tools/docker/ubuntu-build.Dockerfile` si son genéricos; si no, crea
     `games/<id>/Dockerfile` con `FROM steamdeck-ports/ubuntu-build:24.04` y
     solo lo suyo. Toda imagen sale de un Dockerfile versionado.
   - La cabecera es la ayuda de `-h/--help` (la muestra `tools/lib.sh`):
     incluye `-h, --help  muestra esta ayuda` en el bloque de uso.
   - Si el build usa contenedor y recibe una ruta, `require_container_path`.
   - `chmod +x` y `bash -n`.

6. **Ejecuta y verifica.** Lanza el build (en segundo plano si va a tardar
   minutos). Comprueba:
   - que termina bien y deja `build/.release-tag`;
   - que no quedan rutas del PC (`check_absolute_paths`; los RUNPATH absolutos
     los cubre `steamdeck.sh`);
   - que funciona desde otra ruta: `cp -a --reflink=always build build-movido`,
     cambia el `exec` final de su `steamdeck.sh` por un `ldd` del ejecutable,
     comprueba que las librerías salen de `build-movido` y borra la copia;
   - que lo que se ejecuta en la Deck (p. ej. `run_game.py`) solo usa
     dependencias que tenga SteamOS.
   Si algo falla, investiga la causa en el log antes de tocar nada.

7. **`games/<id>/game.conf` y paquete.** Copia el de un juego parecido:
   `NAME` (nombre en Steam), `EXEC` (`steamdeck.sh`, o el `.exe` si es
   Windows), `PROTON` (1 si es Windows), `STEAMGRIDDB` (el enlace
   `SteamGridDB:` de `ports.md`, si lo hay), `SAVES` (texto para el README
   del paquete) y `KEEP` (las partidas y ajustes que el instalador copia de
   la instalación anterior al reinstalar; mira en el README del port dónde
   guarda; `KEEP_EXCLUDE` para saltarse archivos de esas carpetas que trae
   el paquete). Si hay `STEAMGRIDDB_API_KEY`
   (env o `local.conf`), `tools/fetch-art.sh <id>`. Prueba
   `tools/package.sh -o <scratchpad> <id>` y el instalador en el PC con un HOME
   falso: `HOME=<tmp> <scratchpad>/<id>/instalar.sh <tmp>/Games </dev/null`
   (el scratchpad es tmpfs: para juegos grandes, instala en otro disco).
   Si en la Deck hace falta algo tras descomprimir (rutas absolutas en la
   configuración, ajustes del sistema), escribe `games/<id>/deck-post-install.sh`
   (recibe la carpeta del juego y `VERSION`). Lo que deba saber quien instala
   va en `games/<id>/deck-notes.md` (sale en el README del paquete).

   **Menú de opciones (siempre):** todo juego nuevo lleva un menú de
   opciones antes de jugar, aunque tenga el suyo dentro del juego
   (`tools/deck/opciones.py` + `opciones.json` + `deck-launch.sh`; modelos:
   `games/tekken6` con opciones de arranque, `games/rumble-roses-xx` con
   su `.toml`, `games/bayonetta2` con `.ini`; ver `CLAUDE.md`,
   Convenciones). `opciones.conf` en `KEEP` y fuera del borrado de
   `prepare_build`.

8. **Documenta.**
   - `games/<id>/README.md` con las mismas secciones que los demás: datos del
     repo y la release, contenido, datos del juego, Build, Jugar (indicando
     `steamdeck.sh` o Proton) e "Imagen Ubuntu 24.04 (contenedor de build)".
   - `README.md`: fila en la tabla de juegos y en la de `build.sh` (tiempo y
     tamaño).
   - `CLAUDE.md`: ids en Convenciones, datos que no se deducen del código y
     una entrada con fecha en el registro de trabajo.

9. **Resumen y git.** Resume al usuario qué se ha hecho, el tamaño y si queda
   algo sin verificar. Pregunta antes de hacer commit y push. Comprueba con
   `git status` que no se cuela nada de `isos/`, `latest/`, `build/`,
   `art/`, `dist/` ni `tools/bin/`.
