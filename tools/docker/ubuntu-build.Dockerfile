# Imagen única de compilación (steamdeck-ports/ubuntu-build:24.04) para los
# ports que se compilan: doaxtreme, doa3 y doa2u (NoRain211). Ubuntu 24.04, el
# mismo que proponen sus build_steamdeck.sh; paquetes según su
# docs/building.md ("Linux and SteamOS"). La construye run_in_container
# (tools/lib.sh). Si un juego necesitara paquetes extra, crear un Dockerfile
# en games/<id>/ que haga FROM de esta imagen.
# libarchive-tools (bsdtar): doa3 >= 0.8.1 descarga trajes de mods y algunos
# vienen en RAR; sin bsdtar se salta ese paquete de trajes.
FROM docker.io/library/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential clang cmake ninja-build git ca-certificates curl \
        python3 python3-venv python3-pip pkg-config file unzip xz-utils \
        libarchive-tools \
        libshaderc1 libvulkan1 libvulkan-dev mesa-vulkan-drivers \
        libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev \
        libxss-dev libxtst-dev libxkbcommon-dev libwayland-dev libdecor-0-dev libegl-dev \
        libasound2-dev libpulse-dev libpipewire-0.3-dev libudev-dev libdbus-1-dev \
    && rm -rf /var/lib/apt/lists/*

CMD ["bash"]
