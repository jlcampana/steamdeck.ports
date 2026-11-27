# Bayonetta 3 (B3-Express / ScarletNX): la imagen de los ports de ReXGlue
# (clang 23 de apt.llvm.org) más lo que pide source/docs/BUILD.md para
# Linux: los archivos de desarrollo de LLVM 23 (llvm-config: el
# recompilador enlaza su API de C), NASM (FFmpeg), Perl (OpenSSL), patch
# (su copia de hactool) y wayland-protocols (SDL3). SDL3, FFmpeg, OpenSSL
# y hactool los descarga y compila CMake (versiones con SHA-256).
FROM steamdeck-ports/rexglue-build:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        llvm-23-dev libzstd-dev libxml2-dev zlib1g-dev \
        nasm perl patch wayland-protocols binutils \
    && rm -rf /var/lib/apt/lists/* \
    && llvm-config-23 --version

CMD ["bash"]
