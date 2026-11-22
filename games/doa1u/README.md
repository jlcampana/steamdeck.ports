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

- Añadir `DOA1U.exe` a Steam como juego no de Steam y forzar Proton.
- Ajustes con F10: modo de pantalla, resolución interna (25–400 %), V-Sync,
  filtrado anisotrópico, sustitución/volcado de texturas
  (`textures/replacement`, `textures/dumps`).
- Dejar el framerate en 60: desbloquearlo acelera el juego.
- Un `splash.png` junto al exe se muestra al arrancar.
