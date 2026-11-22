En ports.md encontrarás los nombres de los juegos y los enlaces a las releases de sus repos.
El objetivo es hacer un script de actualizacion y varios scripts custom por cada uno de estos ports para poder jugarlos en una SteamDeck. 

- El primer script: update.sh irá a las releases de los repos y descargará la ultima version en la carpeta latest. Quizás podríamos llevar un control de las versiones con una base de datos sqlite)
- Después de descargarlos, los descomprimirá (algunos son zip otro son tar...). No sé en qué carpeta (proponme una)
- En la carpeta games habrá una carpeta por juego (por ejemplo games/doa2u) y allí dentro estará su script build.sh 
- El script que descarga los juegos podría descomprimir el juego en games/xxxx/latest

## scripts de build

Tendremos que crear un script por cada juego. Cada script requiere cosas diferentes, incluso alguno necesita de paquetes externos para descomprimir. Esas herramientas se instalarán en la carpeta tools. En esa carpeta también habrá un script para instalar todas esas dependencias necesarias.

Para hacer el build de steam deck algunos juegos mencionan de usar una versión de ubuntu. Si necesitas una imagen de docker, crea el dockerfile o los diferentes dockerfiles dentro de cada juego. Los juegos que no tienen version de linux, usaremos proton en la steam deck. 

El build, junto con los assets descomprimidos quedarían en games/xxxx/build listo para poder ser jugado en una steam deck.

Las ISO de los juegos están en la carpeta isos (la tendríamos que meter en el .gitignore). Para el Castlevania SON yo mismo extraeré los assets