"""
Limer Portable Build
Assembles Limer as a folder that runs on a machine with no Python installed:

    Limer/
      Limer.exe    ~100 KB launcher that starts the Python beside it
      python/      portable CPython, with Limekit and its dependencies
      limer/       Limer's own Lua project
      LICENSE

Limer is not frozen with PyInstaller. A real interpreter ships instead, so
`sys.executable` is a Python that can run a project (`-m limekit`) and build
one into an app (`-m PyInstaller`, which ships in the bundle). A frozen
Limer can do neither: there, `sys.executable` is Limer.exe itself.

Usage (from Limer's folder):
    python packaging/package_portable.py [options]

Options:
    --limekit PATH  Limekit checkout to install (default: ../Limekit)
    --output DIR    Where to assemble Limer (default: dist)
    --zip           Also package it as Limer-<version>-<os>.zip

Windows only for now.
"""

import argparse
import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path

# Limer's own folder: this script lives in packaging/, one level down.
HERE = Path(__file__).resolve().parents[1]
CACHE = HERE / "build" / "portable-cache"

# python-build-standalone: the portable CPython builds that uv installs.
# Pinned by release, verified by checksum -- the sha256 below is both GitHub's
# asset digest and the release's own SHA256SUMS entry.
PYTHON_BUILDS = {
    "windows": (
        "https://github.com/astral-sh/python-build-standalone/releases/download/"
        "20261003/cpython-3.13.16%2B20261003-x86_64-pc-windows-msvc-install_only_stripped.tar.gz",
        "ec43f1a85c29f147d7ae2d13218c52c70b24a983a82ab22d6c607c0593060e10",
    ),
}

# Limekit uses QtCore, QtGui, QtWidgets, QtCharts, QtPrintSupport, QtNetwork
# and QtSvg (QtUiTools via a theme package). Everything here is something it
# never touches: the browser engine, QML and Quick, 3D, multimedia, PDF,
# Designer tooling, translations it never loads, and type stubs nothing
# imports at runtime. Globs, relative to site-packages/PySide6. Removing
# something Limekit does need fails the test suite run on the trimmed build.
PYSIDE_TRIM = [
    "Qt6WebEngine*", "QtWebEngine*", "resources",
    "translations",
    "qml", "Qt6Qml*", "QtQml*", "Qt6Quick*", "QtQuick*",
    "plugins/qmltooling", "plugins/scenegraph",
    "Qt63D*", "Qt3D*", "Qt6Graphs*", "QtGraphs*",
    "plugins/sceneparsers", "plugins/assetimporters", "plugins/renderers",
    "Qt6Multimedia*", "QtMultimedia*", "plugins/multimedia",
    "avcodec*.dll", "avformat*.dll", "avutil*.dll", "swresample*.dll", "swscale*.dll",
    "Qt6Pdf*", "QtPdf*", "plugins/imageformats/qpdf.dll",
    "Qt6Designer*", "QtDesigner*", "designer.exe", "assistant.exe", "linguist.exe",
    "*.pyi",
]

# The parts of CPython Limekit has no use for. Scripts/ holds pip's console
# launchers, which carry absolute paths to the machine that built this and
# stop working once the folder moves.
PYTHON_TRIM = [
    "tcl", "Lib/tkinter", "Lib/idlelib", "Lib/turtledemo", "Lib/turtle.py",
    "DLLs/_tkinter.pyd", "DLLs/tcl*.dll", "DLLs/tk*.dll", "Scripts",
]

# Runs inside Limer.exe. The launcher finds python\pythonw.exe beside itself
# (the `<launcher_dir>` shebang), starts it with -I, and hands it this file.
LAUNCHER_MAIN = '''\
"""Limer's launcher: runs Limer on the Python that ships beside it."""
import os
import sys

root = os.path.dirname(os.path.abspath(sys.argv[0]))

# -I already isolates this process from the machine's own Python. Clearing
# these keeps every project Limer starts isolated too: they inherit this
# environment, not the flag.
for name in ("PYTHONPATH", "PYTHONHOME", "PYTHONSTARTUP", "PYTHONUSERBASE"):
    os.environ.pop(name, None)
os.environ["PYTHONNOUSERSITE"] = "1"

# pythonw has no console, so anything Limer prints -- a crash included --
# would vanish. Keep it in a log the user can find.
if sys.stdout is None or sys.stderr is None:
    log_dir = os.path.join(os.environ.get("LOCALAPPDATA") or root, "Limer")
    os.makedirs(log_dir, exist_ok=True)
    log = open(os.path.join(log_dir, "limer.log"), "w", encoding="utf-8", buffering=1)
    sys.stdout = sys.stdout or log
    sys.stderr = sys.stderr or log

from limekit.__main__ import main

sys.exit(main([os.path.join(root, "limer")]))
'''

SHEBANG = b'#!"<launcher_dir>\\python\\pythonw.exe" -I\r\n'


def os_label():
    if sys.platform == "win32":
        return "windows"
    if sys.platform == "darwin":
        return "macos"
    return "linux"


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def clean_env():
    """The host's own Python settings must not leak into the bundled one."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("PYTHON")}
    env["PYTHONNOUSERSITE"] = "1"
    return env


def size_of(path):
    if path.is_file():
        return path.stat().st_size
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())


def remove(path):
    if path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink()


def fetch_python(dest):
    url, expected = PYTHON_BUILDS[os_label()]
    CACHE.mkdir(parents=True, exist_ok=True)
    archive = CACHE / url.rsplit("/", 1)[1].replace("%2B", "+")

    if not archive.exists() or sha256(archive) != expected:
        print(f"Downloading {archive.name}")
        partial = archive.with_suffix(".part")
        with urllib.request.urlopen(url) as response, open(partial, "wb") as f:
            shutil.copyfileobj(response, f)
        partial.replace(archive)

    if sha256(archive) != expected:
        archive.unlink()
        raise SystemExit(f"checksum mismatch for {archive.name} -- refusing to use it")

    # The archive holds a single top-level python/ folder, which is `dest`.
    with tarfile.open(archive) as tar:
        if hasattr(tarfile, "data_filter"):
            tar.extractall(dest.parent, filter="data")
        else:
            tar.extractall(dest.parent)


def install_limekit(python, limekit):
    # [build] brings PyInstaller: with a real interpreter in the bundle,
    # Limer's Build button runs `python -m PyInstaller` exactly as it does
    # from source. About 17 MB unpacked.
    subprocess.run(
        [str(python), "-I", "-m", "pip", "install",
         "--no-warn-script-location", "--disable-pip-version-check",
         "-c", str(Path(__file__).with_name("portable-constraints.txt")), f"{limekit}[build]"],
        check=True, env=clean_env(),
    )


def trim(python_dir):
    pyside = python_dir / "Lib" / "site-packages" / "PySide6"
    freed = 0
    for base, patterns in ((pyside, PYSIDE_TRIM), (python_dir, PYTHON_TRIM)):
        for pattern in patterns:
            for path in base.glob(pattern):
                freed += size_of(path)
                remove(path)
    return freed


def copy_limer(dest):
    ignore = shutil.ignore_patterns("__pycache__", ".preview")
    for name in ("scripts", "images", "misc"):
        shutil.copytree(HERE / name, dest / name, ignore=ignore)
    shutil.copy2(HERE / "app.json", dest / "app.json")


def set_icon(exe):
    """Give Limer.exe Limer's icon, if the tools to do it are installed.

    Must run before the launcher payload is appended: rewriting an exe's
    resources drops anything stored after its last section.
    """
    try:
        from PIL import Image
        from PyInstaller import config
        from PyInstaller.utils.win32.icon import CopyIcons
    except ImportError:
        print("  (no Pillow/PyInstaller here -- Limer.exe keeps the generic icon)")
        return
    # CopyIcons expects to run inside a PyInstaller build, which sets this.
    config.CONF.setdefault("workpath", str(CACHE))
    ico = CACHE / "limer.ico"
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64)]
    Image.open(HERE / "images" / "lime.png").save(ico, sizes=sizes)
    CopyIcons(str(exe), str(ico))


def write_launcher(root, python_dir):
    # pip's own script launcher -- the one behind every pip.exe -- taken from
    # the pip that ships in the bundled Python, so it always matches it.
    launcher = python_dir / "Lib" / "site-packages" / "pip" / "_vendor" / "distlib" / "w64.exe"
    exe = root / "Limer.exe"
    shutil.copyfile(launcher, exe)
    set_icon(exe)

    payload = io.BytesIO()
    with zipfile.ZipFile(payload, "w") as z:
        z.writestr("__main__.py", LAUNCHER_MAIN)
    with open(exe, "ab") as f:
        f.write(SHEBANG + payload.getvalue())


def package_zip(root):
    with open(HERE / "app.json", encoding="utf-8") as f:
        version = json.load(f)["project"]["version"]
    base = root.parent / f"{root.name}-{version}-{os_label()}"
    return Path(shutil.make_archive(str(base), "zip", root_dir=root.parent, base_dir=root.name))


def main():
    parser = argparse.ArgumentParser(description="Build portable Limer")
    parser.add_argument("--limekit", type=str, default=str(HERE.parent / "Limekit"),
                        help="Limekit checkout to install")
    parser.add_argument("--output", type=str, default=str(HERE / "dist"), help="Output directory")
    parser.add_argument("--zip", action="store_true", help="Package the result as a release zip")
    args = parser.parse_args()

    if os_label() not in PYTHON_BUILDS:
        raise SystemExit(f"portable builds are Windows-only for now, not {os_label()}")

    limekit = Path(args.limekit).resolve()
    if not (limekit / "setup.py").exists():
        raise SystemExit(f"no Limekit checkout at {limekit} -- pass --limekit")

    root = Path(args.output).resolve() / "Limer"
    python_dir = root / "python"

    print("=" * 60)
    print("  LIMER PORTABLE BUILD")
    print("=" * 60)
    print(f"Limekit: {limekit}")
    print(f"Output:  {root}")
    print()

    if root.exists():
        shutil.rmtree(root)
    root.mkdir(parents=True)

    print("[1/5] Portable Python")
    fetch_python(python_dir)

    print("[2/5] Limekit and its dependencies")
    install_limekit(python_dir / "python.exe", limekit)

    print("[3/5] Trimming what Limekit never uses")
    freed = trim(python_dir)
    print(f"  freed {freed / 1048576:.0f} MB")

    print("[4/5] Limer")
    copy_limer(root / "limer")
    shutil.copy2(HERE / "LICENSE", root / "LICENSE")
    write_launcher(root, python_dir)

    print("[5/5] Done")
    print(f"  {root}  ({size_of(root) / 1048576:.0f} MB)")
    if args.zip:
        archive = package_zip(root)
        print(f"  {archive}  ({archive.stat().st_size / 1048576:.0f} MB)")


if __name__ == "__main__":
    main()
