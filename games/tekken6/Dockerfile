# Tekken 6 (tekken6-recomp, versión Linux): la imagen de los ports de ReXGlue
# más lo que pide su README (sección Linux): clang 19 y lld 19 (los que usa
# tools/build_linux.sh) y NASM. Las demás librerías de desarrollo ya están
# en la imagen común.
FROM steamdeck-ports/rexglue-build:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        clang-19 lld-19 nasm \
    && rm -rf /var/lib/apt/lists/* \
    && clang-19 --version

CMD ["bash"]
