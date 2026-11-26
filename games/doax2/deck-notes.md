- **Es la versión de Windows y va con Proton.** Después de instalarlo, en
  Steam: el juego → ⚙ → Propiedades → Compatibilidad → «Forzar el uso de una
  herramienta de compatibilidad» → Proton (la más reciente).
- Al abrirlo sale el **lanzador** del port: elige 30 o 60 FPS y pulsa
  **PLAY** (con la pantalla táctil o el trackpad). En **Graphics Settings**,
  el renderizador: **Vulkan (Native)** suele ir mejor en Linux; si algo se ve
  mal, prueba DX12 (Native) o Emulated. Ponlo a pantalla completa.
- No uses la página **Update** del lanzador: actualiza los archivos a mano y
  la próxima reinstalación los pisaría. Las versiones nuevas llegan con un
  paquete nuevo.
- Partidas en `userdata/` (el lanzador hace copia en `save-backup/` cada vez
  que se abre), ajustes en `config/launcher.ini` y fotos en `photos/`. El
  instalador las conserva al reinstalar.
- El juego no usa la red (el port bloquea todas las conexiones).
