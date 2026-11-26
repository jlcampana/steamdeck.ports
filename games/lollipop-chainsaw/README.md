# Lollipop Chainsaw Recomp (Xbox 360), Linux nativo — `lollipop-chainsaw`

Recompilación estática del Lollipop Chainsaw de Xbox 360 con el ReXGlue SDK,
**compilada por nosotros como programa nativo de Linux**, sin Proton. El
port solo publica un lanzador de Windows (WPF/.NET) que compila el juego en
el PC del jugador con LLVM y las bibliotecas de Microsoft. No hay versión
ni guía de Linux, y el código del juego usa partes de Windows (GDI+,
recursos `.rc`, BCrypt, `makecab.exe`): las porta a Linux un parche nuestro.

- Repo: https://github.com/kxrxh/lollipop-chainsaw-recomp
- Release usada: el código de la última release (`@source` en `ports.tsv`;
  la release solo trae `Lollipop-Chainsaw-Launcher.exe`). Versión al
  añadirlo: v0.1.12.
- SDK: [rexglue/rexglue-sdk](https://github.com/rexglue/rexglue-sdk)
  v0.11.0 en el commit que fija el port (`scripts/sdk-package.ps1`:
  `a3e1d82`) + sus 5 parches (`patches/rexglue-*.patch`, lista en
  `Get-SdkPatches`) + los nuestros (`patches/rexglue-sdk/`). Cabeceras de
  Vulkan 1.4.313 y VMA 3.3.0 en los commits del port (Ubuntu 24.04 trae
  Vulkan 1.3 y el SDK pide 1.4.313).
- ISO: `isos/LollipopChainsaw.iso` (disco de Xbox 360, title ID
  `565707D0`; `default.xex` con SHA-256 `a687f47d…df26`, el que pide el port).
- En la Deck: Linux nativo (`steamdeck.sh`), Vulkan.

## Build

```
games/lollipop-chainsaw/build.sh [-f] [ruta.iso]
LOLLIPOP_JOBS=2 games/lollipop-chainsaw/build.sh
```

Lo mismo que `build-sdk.ps1` y `build.ps1` del port, en el contenedor
`rexglue-build` (Ubuntu 24.04, clang 20; el port usa LLVM 20.1.8):

1. `latest/` → `work/src` + `patches/game/0001-linux.patch` (nuestro).
2. SDK en el commit del port + parches → `work/rexglue-sdk/out/install`.
3. Disco extraído en `work/game` (se comprueba el `default.xex`).
4. `rexglue codegen` con el manifiesto del port y las rutas de aquí →
   `work/src/out/generated` (sale del disco: no se publica).
5. El juego → `work/src/out/build/linux-release/lollipop`.

`work/` (6,8 GB) se conserva entre builds. La primera vez tarda ~20 min
(casi todo el SDK, con `-j 4`); `build/` ocupa 5,2 GB (el disco, con
reflink) y el paquete 5,1 GB.

Para tocar el parche del juego: editar en `work/src` (es un repo git con el
código original en el commit `base`) y luego
`git -C work/src diff > patches/game/0001-linux.patch` (con `git add -N`
para los archivos nuevos). `build.sh` vuelve a copiar el código y aplica el
parche cuando este cambia.

## El parche de Linux (`patches/game/0001-linux.patch`)

- `src/platform/portable.{h,cpp}` (nuevo): recursos incrustados (en Linux
  con `.incbin` de `assets/settings/*.png` y `assets/shaders/pipelines.txt`,
  los `RCDATA` de `lollipop.rc`), SHA-256 propio (en Windows, BCrypt),
  `process_id`, `replace_file` (`rename`) y la fuente del menú.
- **Iconos de teclado y ratón:** en Windows los dibuja con GDI+ y los
  comprime con `makecab.exe`. En Linux no se dibujan
  (`platform::kKeyboardPromptArtwork = false`): el juego enseña siempre los
  del mando, que es lo que se usa en la Deck. El teclado sigue funcionando.
- `prefetch_recompiled_code`: `madvise(MADV_WILLNEED)` sobre los segmentos
  ejecutables (en Windows, `PrefetchVirtualMemory`).
- Fuente del menú PC SETTINGS (en Windows, Arial Bold): Liberation Sans
  Bold en `fonts/` junto al ejecutable (la copia `build.sh` del PC; licencia
  OFL en `fonts/`), y si no, una del sistema.
- `test_bridge.cpp` (pruebas automáticas del port): BMP escrito a mano y
  RenderDoc con `dlopen`. `lollipop_dlc_tool`: `main` en vez de `wmain`.
- `CMakeLists.txt`: `gdiplus`/`bcrypt` solo en Windows.

Parches nuestros del SDK (`patches/rexglue-sdk/0001-linux-fibras-y-shm.patch`):
los mismos que en doax2-linux. `Fiber::Destroy` de POSIX solo borra la
fibra actual si es la suya (si no, cuelgue con `SIGSEGV` en bucle), y la
memoria del juego se desvincula de `/dev/shm` nada más crearla. El SDK
v0.11.0 ya borra al arrancar los restos de procesos muertos, y RenderDoc
ya solo se engancha si está cargado.

## Jugar

- **Instalar en la Deck:** `tools/package.sh lollipop-chainsaw` y «Ports
  por red» (o doble clic en `Instalar <Nombre>.desktop`).
- **Usar `steamdeck.sh`**, sin Proton. Lanza `lollipop` con las rutas de la
  instalación, como el lanzador de Windows: `--game_data_root=game`,
  `--user_data_root=user`, `--cache_root=cache` y
  `--lollipop_gpu_backend=vulkan`.
- **Menú de opciones dentro del juego:** *PC SETTINGS* (pantalla,
  gráficos, audio, cámara, controles), con el mando. F6: trucos. No hace
  falta lanzador propio.
- Partidas y `pc-settings.toml` en `user/`; shaders y menús preparados en
  `cache/`. El instalador conserva las dos al reinstalar (`KEEP`).
- Configuración avanzada: `lollipop.toml` junto al ejecutable (no existe
  por defecto).

## Probado (2026-11-26, en el PC)

Desde otra ruta: `ldd` con las `.so` de la carpeta, carga 56 MiB de
código por adelantado, vídeos de inicio y el prólogo en el motor del juego
(Vulkan, RX 6400), pulsando Start/A con el mando virtual del «test bridge»
del port (`--lollipop_test_directory=<carpeta>`: comandos en
`command.txt`, `capture` deja `capture.bmp`). Instalador probado con un
HOME falso (instalar y reinstalar conservando `user/`).

**Pendiente:** en una escena del prólogo (primer plano de Juliet) se ven
manchas naranjas y verdes en la piel. Puede ser del renderizador Vulkan (en
Windows el port usa D3D12 con ROV) o del propio efecto de la escena: hay
que compararlo. Sin probar en la Deck ni jugado más allá del prólogo.

## Imagen Ubuntu 24.04 (contenedor de build)

`games/lollipop-chainsaw/Dockerfile` es un enlace a
`tools/docker/rexglue-build.Dockerfile` (clang 20 y 23, GTK 3, x11-xcb…),
la misma imagen que doa4-linux y doax2-linux.
