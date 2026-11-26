- **Versión de Linux hecha aquí** (el port solo publica la de Windows): el
  código del juego lleva un parche nuestro y algo puede fallar donde en
  Windows no. El log sale por la salida de `steamdeck.sh` (`--log_file=<archivo>`
  lo guarda en un archivo).
- **Iconos de botones:** siempre los del mando de Xbox, también al jugar con
  teclado (los de teclado y ratón solo se dibujan en Windows).
- **Ajustes de PC** (pantalla, gráficos, audio, cámara, controles): menú
  *PC SETTINGS* del juego, con el mando. **F6** abre los trucos.
- Los primeros minutos pueden dar tirones: los shaders se compilan la
  primera vez y se guardan en `cache/`.
