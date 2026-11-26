- **Versión nativa de Linux, sin Proton**, compilada desde el código del port
  (el port solo publica la de Windows). No fuerces Proton en Steam.
- **No hay lanzador** (el del port es de Windows): `steamdeck.sh` arranca el
  juego directamente con las opciones por defecto del lanzador, pero con
  **Vulkan (Native)**, **60 FPS** y pantalla completa. Para cambiarlas, en
  Steam → Propiedades → Opciones de lanzamiento, p. ej.
  `DOAX2_FPS=30 %command%` (30 FPS, la velocidad original),
  `DOAX2_SHADOWS=0`, `DOAX2_FPS_OVERLAY=1`, `DOAX2_WIDTH=1280 DOAX2_HEIGHT=800`,
  `DOAX2_SCALE=2`. Lista completa al principio de `steamdeck.sh`.
- Es un build no oficial: el port solo prueba Windows. Si algo falla, mira
  `logs/` en la carpeta del juego, o usa *Dead or Alive Xtreme 2* (la de
  Proton); las dos pueden estar instaladas a la vez, pero las partidas no se
  comparten (cada una en su `userdata/`).
- Partidas en `userdata/`, fotos en `photos/`. El instalador las conserva al
  reinstalar.
- Teclado: Enter = Start, Espacio = A, Retroceso = B, WASD = stick
  izquierdo, flechas = cruceta.
