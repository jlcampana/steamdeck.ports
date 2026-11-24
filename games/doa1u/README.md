# Dead or Alive 1 Ultimate — `doa1u`

- Repo: https://github.com/vini1264/DOA1U-XBERecomp (basado en Xbox XBE Recomp)
- Release usada: `DOA1U-XBERecomp.zip` (solo Windows)
- Versión probada al descargar: DOA1U-XBERecomp-V2
- ISO: **`isos/DOA2U.iso`**. No hay ISO de DOA1U por separado: el disco de
  DOA2U trae `Doa1.xbe` y `DOA2.xbe` en la raíz.
- En la Deck: **Proton** (necesita Direct3D 12 → vkd3d-proton)

## Contenido de la release

`DOA1U.exe`, `compiler/` (compilador incluido), DLLs del runtime de MSVC y
`d3dcompiler_47.dll`, `recomplauncher.json`, `assets/` (vacía) y `textures/`.

## Build

No se compila aquí. Hay que poner los datos del juego en `assets/`: la ISO o
los archivos extraídos, con `Doa1.xbe` en la raíz de `assets/` y las carpetas
del juego al lado.

**La primera vez que se arranca `DOA1U.exe`, compila el código del juego**
para el PC (solo una vez). En la Deck ocurrirá en el primer arranque con Proton.

## Jugar

- **Instalar en la Deck:** `tools/package.sh doa1u` y, en la Deck, doble clic en
  `Instalar <Nombre>.desktop` (ver «Distribución a la Steam Deck» en el README
  principal). Nombre en Steam, ejecutable y Proton: `game.conf`.
- En Steam hay que forzar Proton (Propiedades → Compatibilidad); el instalador
  lo recuerda al terminar.
- Ajustes con F10: modo de pantalla, resolución interna (25–400 %), V-Sync,
  filtrado anisotrópico, sustitución/volcado de texturas
  (`textures/replacement`, `textures/dumps`).
- Dejar el framerate en 60: desbloquearlo acelera el juego.
- Un `splash.png` junto al exe se muestra al arrancar.

## Imagen Ubuntu 24.04 (contenedor de build)

Este juego **no usa contenedor ni Dockerfile**: la release ya viene compilada
y `build.sh` solo copia archivos y prepara `assets/` en el propio PC. La
imagen Ubuntu 24.04 solo la usan los ports que se compilan (doaxtreme, doa3,
doa2u), con un Dockerfile compartido en
[`tools/docker/ubuntu-build.Dockerfile`](../../tools/docker/ubuntu-build.Dockerfile).
