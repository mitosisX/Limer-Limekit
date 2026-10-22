"""
Limer Portable Build
Assembles Limer as a folder that runs on a machine with no Python installed:

    Windows                   Linux                  macOS
    Limer/                    Limer/                 Limer.app/Contents/
      Limer.exe (launcher)      Limer (launcher)       MacOS/Limer (launcher)
      python/                   launcher.py            Resources/
      limer/                    python/                  launcher.py
      LICENSE                   limer/                   python/
                                LICENSE                  limer/

python/ is a portable CPython with Limekit and its dependencies; limer/ is
Limer's own Lua project.

Limer is not frozen with PyInstaller. A real interpreter ships instead, so
`sys.executable` is a Python that can run a project (`-m limekit`) and build
one into an app (`-m PyInstaller`, which ships in the bundle). A frozen
Limer can do neither: there, `sys.executable` is Limer.exe itself.

Usage (from Limer's folder):
    python packaging/package_portable.py [options]

Options:
    --limekit PATH  Limekit checkout to install (default: ../Limekit)
    --output DIR    Where to assemble Limer (default: dist)
    --zip           Also package it for release: Limer-<version>-<os>.zip, or
                    .tar.gz on Linux (tar keeps the launcher executable)
"""

import argparse
import fnmatch
import hashlib
import io
import json
import os
import platform
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
# Pinned by release, verified by checksum -- each sha256 below is both GitHub's
# asset digest and the release's own SHA256SUMS entry.
_PBS = ("https://github.com/astral-sh/python-build-standalone/releases/download/"
        "20261003/cpython-3.13.16%2B20261003-{}-install_only_stripped.tar.gz")
PYTHON_BUILDS = {
    ("windows", "x86_64"): (_PBS.format("x86_64-pc-windows-msvc"),
                            "ec43f1a85c29f147d7ae2d13218c52c70b24a983a82ab22d6c607c0593060e10"),
    ("linux", "x86_64"): (_PBS.format("x86_64-unknown-linux-gnu"),
                          "4595c5589fff7bf0cb158d9a88a797e0d791fa33830770fcb7bf3f4b104feeae"),
    ("macos", "arm64"): (_PBS.format("aarch64-apple-darwin"),
                         "9e01f63bbb08576cd9c8bc2d0564d098cb30c8453a0cd4bcf6aef458f6d2a147"),
    ("macos", "x86_64"): (_PBS.format("x86_64-apple-darwin"),
                          "b4dad38ba6a344555ccb71a1b08caad0a6c0dda88c5803658bc95bd7f04e9f5c"),
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

# The same parts on Linux and macOS, where PySide6 keeps Qt under Qt/ and
# names libraries libQt6X.so / QtX.framework. Matched against file and
# folder *names* anywhere under PySide6, since the two layouts differ.
PYSIDE_TRIM_POSIX_NAMES = [
    "*WebEngine*", "resources", "translations", "qml", "*Qml*", "*Quick*",
    "qmltooling", "scenegraph", "*3D*", "*Graphs*", "sceneparsers", "assetimporters",
    "renderers", "*Multimedia*", "multimedia", "libav*", "libsw*", "*Pdf*", "*qpdf*",
    "*Designer*", "designer", "assistant", "Assistant.app", "linguist", "Linguist.app",
    "*.pyi",
]

# The parts of CPython Limekit has no use for. Scripts/ holds pip's console
# launchers, which carry absolute paths to the machine that built this and
# stop working once the folder moves.
PYTHON_TRIM = [
    "tcl", "Lib/tkinter", "Lib/idlelib", "Lib/turtledemo", "Lib/turtle.py",
    "DLLs/_tkinter.pyd", "DLLs/tcl*.dll", "DLLs/tk*.dll", "Scripts",
]
PYTHON_TRIM_POSIX = [
    "lib/python3.13/tkinter", "lib/python3.13/idlelib", "lib/python3.13/turtledemo",
    "lib/python3.13/turtle.py", "lib/python3.13/lib-dynload/_tkinter*",
    "lib/libtcl*", "lib/libtk*", "lib/tcl*", "lib/tk*", "lib/itcl*", "lib/thread*", "share",
]
# What stays in python/bin: the interpreter. pip's console scripts there carry
# the build machine's absolute path in their shebangs, as Scripts/ does above.
POSIX_BIN_KEEP = ("python", "python3", "python3.13")

# Runs inside Limer.exe. The launcher finds python\pythonw.exe beside itself
# (the `<launcher_dir>` shebang), starts it with -I, and hands it this file.
# On Linux and macOS it is launcher.py, started by the shell script below.
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

# Linux and macOS: a shell script starts the Python beside it on the same
# launcher code. PYTHON* is cleared here as well as in launcher.py, because
# -I does not stop PYTHONHOME from deciding where the standard library is.
POSIX_LAUNCHER = """\
#!/bin/sh
# Limer: runs on the Python that ships beside it.
here="$(cd "$(dirname "$0")" && pwd)"
{resources}
unset PYTHONPATH PYTHONHOME PYTHONSTARTUP PYTHONUSERBASE
export PYTHONNOUSERSITE=1
exec "$here/python/bin/python3" -I "$here/launcher.py" "$@"
"""

INFO_PLIST = """\
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Limer</string>
  <key>CFBundleDisplayName</key><string>Limer</string>
  <key>CFBundleIdentifier</key><string>com.navetotech.limer</string>
  <key>CFBundleVersion</key><string>{version}</string>
  <key>CFBundleShortVersionString</key><string>{version}</string>
  <key>CFBundleExecutable</key><string>Limer</string>
  <key>CFBundleIconFile</key><string>limer.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
"""


def os_label():
    if sys.platform == "win32":
        return "windows"
    if sys.platform == "darwin":
        return "macos"
    return "linux"


def arch_label():
    machine = platform.machine().lower()
    if machine in ("amd64", "x86_64"):
        return "x86_64"
    if machine in ("arm64", "aarch64"):
        return "arm64"
    return machine


def python_exe(python_dir):
    if os_label() == "windows":
        return python_dir / "python.exe"
    return python_dir / "bin" / "python3"


def site_packages(python_dir):
    if os_label() == "windows":
        return python_dir / "Lib" / "site-packages"
    return python_dir / "lib" / "python3.13" / "site-packages"


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
    if path.is_symlink():
        return 0
    if path.is_file():
        return path.stat().st_size
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file() and not p.is_symlink())


def remove(path):
    """Delete a file, folder or symlink -- a link as a link, never followed."""
    if path.is_symlink() or path.is_file():
        path.unlink()
    else:
        shutil.rmtree(path)


def fetch_python(dest):
    url, expected = PYTHON_BUILDS[(os_label(), arch_label())]
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
    pyside = site_packages(python_dir) / "PySide6"
    freed = 0

    if os_label() == "windows":
        for base, patterns in ((pyside, PYSIDE_TRIM), (python_dir, PYTHON_TRIM)):
            for pattern in patterns:
                for path in base.glob(pattern):
                    freed += size_of(path)
                    remove(path)
        return freed

    # Top-down, so a removed folder's contents are not visited again.
    for dirpath, dirnames, filenames in os.walk(pyside):
        for name in list(dirnames) + filenames:
            if any(fnmatch.fnmatch(name, pattern) for pattern in PYSIDE_TRIM_POSIX_NAMES):
                path = Path(dirpath) / name
                freed += size_of(path)
                remove(path)
                if name in dirnames:
                    dirnames.remove(name)
    for pattern in PYTHON_TRIM_POSIX:
        for path in python_dir.glob(pattern):
            freed += size_of(path)
            remove(path)
    for path in (python_dir / "bin").iterdir():
        if path.name not in POSIX_BIN_KEEP:
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
    launcher = site_packages(python_dir) / "pip" / "_vendor" / "distlib" / "w64.exe"
    exe = root / "Limer.exe"
    shutil.copyfile(launcher, exe)
    set_icon(exe)

    payload = io.BytesIO()
    with zipfile.ZipFile(payload, "w") as z:
        z.writestr("__main__.py", LAUNCHER_MAIN)
    with open(exe, "ab") as f:
        f.write(SHEBANG + payload.getvalue())


def write_posix_launcher(path, resources=""):
    path.write_text(POSIX_LAUNCHER.format(resources=resources), encoding="utf-8", newline="\n")
    path.chmod(0o755)


def write_icns(path):
    """Limer's icon for the .app. Needs Pillow on the build machine."""
    try:
        from PIL import Image
    except ImportError:
        print("  (no Pillow here -- Limer.app keeps the generic icon)")
        return
    Image.open(HERE / "images" / "lime.png").convert("RGBA").resize((512, 512)).save(path)


def limer_version():
    with open(HERE / "app.json", encoding="utf-8") as f:
        return json.load(f)["project"]["version"]


def package(bundle):
    """The release archive, in the format each OS needs.

    Linux gets .tar.gz, which keeps the launcher executable. macOS gets a zip
    made by `ditto`, which keeps the frameworks' symlinks and the signature
    that a plain zip would break.
    """
    label = os_label()
    if label == "macos" and arch_label() == "x86_64":
        label = "macos-intel"
    base = bundle.parent / f"Limer-{limer_version()}-{label}"
    if os_label() == "linux":
        return Path(shutil.make_archive(str(base), "gztar", root_dir=bundle.parent, base_dir=bundle.name))
    if os_label() == "macos":
        # Not base.with_suffix(): in "Limer-2.0.1-macos" the "suffix" is
        # ".1-macos", and both Mac builds came out as Limer-2.0.zip.
        archive = Path(f"{base}.zip")
        subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent",
                        str(bundle), str(archive)], check=True)
        return archive
    return Path(shutil.make_archive(str(base), "zip", root_dir=bundle.parent, base_dir=bundle.name))


def main():
    parser = argparse.ArgumentParser(description="Build portable Limer")
    parser.add_argument("--limekit", type=str, default=str(HERE.parent / "Limekit"),
                        help="Limekit checkout to install")
    parser.add_argument("--output", type=str, default=str(HERE / "dist"), help="Output directory")
    parser.add_argument("--zip", action="store_true", help="Package the result for release")
    args = parser.parse_args()

    target = (os_label(), arch_label())
    if target not in PYTHON_BUILDS:
        raise SystemExit(f"no portable Python pinned for {target[0]} on {target[1]}")

    limekit = Path(args.limekit).resolve()
    if not (limekit / "setup.py").exists():
        raise SystemExit(f"no Limekit checkout at {limekit} -- pass --limekit")

    out = Path(args.output).resolve()
    if os_label() == "macos":
        bundle = out / "Limer.app"
        root = bundle / "Contents" / "Resources"
    else:
        bundle = root = out / "Limer"
    python_dir = root / "python"

    print("=" * 60)
    print(f"  LIMER PORTABLE BUILD  ({target[0]}, {target[1]})")
    print("=" * 60)
    print(f"Limekit: {limekit}")
    print(f"Output:  {bundle}")
    print()

    if bundle.exists():
        shutil.rmtree(bundle)
    root.mkdir(parents=True)

    print("[1/5] Portable Python")
    fetch_python(python_dir)

    print("[2/5] Limekit and its dependencies")
    install_limekit(python_exe(python_dir), limekit)

    print("[3/5] Trimming what Limekit never uses")
    freed = trim(python_dir)
    print(f"  freed {freed / 1048576:.0f} MB")

    print("[4/5] Limer")
    copy_limer(root / "limer")
    shutil.copy2(HERE / "LICENSE", root / "LICENSE")
    if os_label() == "windows":
        write_launcher(root, python_dir)
    else:
        (root / "launcher.py").write_text(LAUNCHER_MAIN, encoding="utf-8", newline="\n")
        if os_label() == "linux":
            write_posix_launcher(root / "Limer")
        else:
            contents = bundle / "Contents"
            (contents / "MacOS").mkdir()
            # The launcher sits in MacOS/; everything it starts is in Resources/.
            write_posix_launcher(contents / "MacOS" / "Limer", 'here="$here/../Resources"')
            (contents / "Info.plist").write_text(
                INFO_PLIST.format(version=limer_version()), encoding="utf-8")
            write_icns(root / "limer.icns")
            # Unsigned code downloaded from the internet does not open at all
            # on Apple silicon; an ad-hoc signature lets it, after the usual
            # right-click -> Open the first time.
            subprocess.run(["codesign", "--force", "--deep", "--sign", "-", str(bundle)], check=True)

    print("[5/5] Done")
    print(f"  {bundle}  ({size_of(bundle) / 1048576:.0f} MB)")
    if args.zip:
        archive = package(bundle)
        print(f"  {archive}  ({archive.stat().st_size / 1048576:.0f} MB)")


if __name__ == "__main__":
    main()
