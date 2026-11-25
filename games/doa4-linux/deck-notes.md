- **Versión nativa de Linux, sin Proton**, compilada desde el código del port
  (no hay release oficial de Linux). No fuerces Proton en Steam.
- **Online:** esta versión se identifica como `dev` y **solo juega con quien
  tenga este mismo paquete**, no con la release de Windows. Para jugar online
  con todo el mundo, usa *Dead or Alive 4* (la de Proton); las dos pueden
  estar instaladas a la vez.
- El arranque nativo en Linux es nuevo en el port (0.3.8) y está poco
  probado: si algo falla, mira `logs/` en la carpeta del juego. Si se queda
  en negro o parado al arrancar, ciérralo y vuelve a abrirlo (en un PC de 4
  núcleos se congela a veces; la Deck tiene 8 y no debería pasar).
- `steamdeck.sh` le pasa `--game_data_root` (`game/`) y `--user_data_root`
  (`user_data/`), así que arranca sin pantalla de configuración aunque
  muevas la carpeta.
- **Menú del juego:** Esc (en la Deck, asígnalo a un botón o usa el teclado
  en pantalla) para gráficos, pantalla, controles, idioma y online.
- **Trajes de DOAX2** (opcionales): ISO **USA** de Dead or Alive Xtreme 2,
  menú Esc → Extras → *Import DOAX2 swimsuits…*.
