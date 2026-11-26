- **Solo hay un jugador.** El juego lee un único mando, el primero que le
  da Steam, y la Deck ya cuenta como mando aunque conectes otro. Si un mando
  externo no responde en el juego (pero sí en el menú F1/Back, que acepta
  cualquiera), cambia el orden en Steam: botón **⋯** → *Reordenar
  controladores* (o Ajustes → Controlador). Va al revés de lo esperado:
  con la **Deck la primera**, el juego coge el **mando externo** (probado
  con un HORIPAD for Steam por Bluetooth, 2026-11-26).
- **Menú del juego:** F1, o Back/Select del mando: pantalla, gráficos,
  audio, controles y presets (empieza en *Performance*).
- `steamdeck.sh` pone `SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1`: sin eso, en
  el modo Juego, el juego no recibe los botones del mando.
