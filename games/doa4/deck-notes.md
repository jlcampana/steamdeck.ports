- **Es la versión de Windows y va con Proton.** Después de instalarlo, en
  Steam: el juego → ⚙ → Propiedades → Compatibilidad → «Forzar el uso de una
  herramienta de compatibilidad» → Proton (la más reciente).
- **`post-install.sh`** escribe en `dead_or_alive_4.toml` dónde están los
  datos del juego (`game/`) y dónde guardar las partidas (`user_data/`).
  Así arranca directamente, sin pantalla de configuración. Si mueves la
  carpeta del juego, vuelve a ejecutar el instalador (o corrige esas dos
  líneas del `.toml`: `Z:` es la raíz `/` de la Deck).
- **Congelación al arrancar (hasta alpha-v0.3.7).** El juego abre el puerto
  UDP 1000 y en Linux solo root puede abrir puertos por debajo de 1024, así
  que en Proton se queda colgado tras el arranque. `post-install.sh` ofrece
  permitirlo con `net.ipv4.ip_unprivileged_port_start=1000` en
  `/etc/sysctl.d/99-doa4.conf` (pide la contraseña de sudo; si no tienes,
  créala con `passwd` en una terminal). Está arreglado para la 0.3.8, que ya
  no lo necesita. Para quitarlo:
  `sudo rm /etc/sysctl.d/99-doa4.conf` y reiniciar.
- **Menú del juego:** Esc (en la Deck, asígnalo a un botón o usa el teclado
  en pantalla) para gráficos, pantalla, controles, idioma y juego online.
- **Online:** solo con otros jugadores que tengan **la misma versión**
  (pestaña Online: Host / Join con el código).
- **Trajes de DOAX2** (opcionales): necesitan una ISO **USA** de Dead or
  Alive Xtreme 2. Menú Esc → Extras → *Import DOAX2 swimsuits…*.
- Fotos: carpeta *Imágenes* del prefijo de Proton, salvo que la pestaña
  Photo indique otra.
