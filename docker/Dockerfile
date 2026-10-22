# ============================================================
#   LIMER LINUX BUILD IMAGE
#   Ubuntu 22.04 on purpose: PyInstaller links against the host
#   glibc and does not bundle it, so the build host must be the
#   OLDEST distro we support. Building on a newer Ubuntu produces
#   a binary that dies with "GLIBC_2.xx not found" everywhere else.
# ============================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# python3-dev + build-essential: lupa compiles a Lua runtime from source
# when no matching wheel exists.
# The libxcb/libegl/libxkb family: PySide6 dlopens these at window creation,
# not at import, and PyInstaller only bundles what it can see. Installing
# them here lets the build smoke-test itself before we ship it.
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-dev python3-pip python3-venv \
        build-essential binutils patchelf file \
        libgl1 libegl1 libdbus-1-3 libfontconfig1 \
        libxkbcommon-x11-0 libxcb-cursor0 libxcb-icccm4 libxcb-keysyms1 \
        libxcb-shape0 libxcb-randr0 libxcb-render-util0 libxcb-xinerama0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Deps install as their own layer so editing Lua or Python source does not
# reinstall PySide6 (~200MB) on every build.
COPY Limekit/requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --no-cache-dir -r /tmp/requirements.txt pyinstaller

COPY . /src

WORKDIR /src/Limer-Limekit
ENTRYPOINT ["python3", "build.py"]
CMD ["--console", "--clean"]
