- **Versión Linux en pruebas** del port (B2recomp `linux-test-N`): la
  estable es solo de Windows.
- **Ajustes de gráficos y mandos:** el lanzador del port, en el modo
  escritorio: `./steamdeck.sh --opciones` en la carpeta del juego (se usa
  con el ratón o la pantalla táctil; no con el mando). Guarda en
  `config/graphics.ini` y `config/controllers.ini`, que también se pueden
  editar a mano. Para la Deck vienen a pantalla completa y a la resolución
  del propio juego (`resolution_scale = 1.0`, 1280x720).
- **La primera vez que el lanzador se abre** se añade al menú de
  aplicaciones del escritorio («B2recomp»). Se quita con
  `./B2recomp --remove-from-menu`.
- Los primeros minutos (y cada sitio nuevo) pueden dar tirones: los shaders
  se preparan la primera vez y se guardan en `cache/`.
- Sin las fuentes de la consola, el juego usa una del sistema (Noto Sans,
  DejaVu…): algunos símbolos de Nintendo no salen.
- Log del juego: `build-linux/play/stdout.txt`.
