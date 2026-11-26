# Imagen de compilación de los ports hechos con el ReXGlue SDK (doa4-linux,
# doax2-linux): la común más lo que pide el job de CI de Linux de doa4-online
# (.github/workflows/linux-build.yml): clang 23 de apt.llvm.org (con su
# script llvm.sh), libstdc++ 14 (<print>), GTK 3, x11-xcb, ibus, drm/gbm y
# glslc/glslang (FidelityFX). Cada juego la enlaza como games/<id>/Dockerfile
# y run_in_container (tools/lib.sh) la construye como steamdeck-ports/<id>:24.04
# (las capas son las mismas: no ocupa más).
FROM steamdeck-ports/ubuntu-build:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget gnupg lsb-release software-properties-common \
    && wget -q -O /tmp/llvm.sh https://apt.llvm.org/llvm.sh \
    && bash /tmp/llvm.sh 23 \
    && apt-get install -y --no-install-recommends clang-23 \
        autoconf libstdc++-14-dev \
        libx11-xcb-dev libgtk-3-dev libibus-1.0-dev libdrm-dev libgbm-dev libegl1-mesa-dev \
        glslc glslang-tools \
    && rm -rf /var/lib/apt/lists/* /tmp/llvm.sh \
    && clang-23 --version

CMD ["bash"]
