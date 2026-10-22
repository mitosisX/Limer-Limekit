"""
Checks an assembled portable Limer the way a user would meet it.

    python packaging/smoke_test.py dist/Limer        (Windows, Linux)
    python packaging/smoke_test.py dist/Limer.app    (macOS)

1. The bundled Python imports every Qt module Limekit uses -- the trim must
   not have taken one away.
2. It runs a project, with a chart in it, and the project exits cleanly.
3. Limer itself starts from its launcher and is still up after a while.
4. Build turns the project into an app, and that app runs.

Exits non-zero, saying which step failed, on the first failure. Runs
off-screen, so it works on a CI machine with no display.
"""

import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

MARKER = "LIMEKIT-SMOKE-OK"

QT_MODULES = ["QtCore", "QtGui", "QtWidgets", "QtCharts", "QtPrintSupport",
              "QtNetwork", "QtSvg", "QtUiTools"]

MAIN_LUA = f"""\
local ui  = require("limekit.ui")
local sys = require("limekit.sys")

local window = ui.Window {{ title = "Smoke", size = {{ 320, 200 }} }}
local layout = ui.VLayout()
layout:addChild(ui.Label("hello"))
layout:addChild(ui.Button("press"))
window:setLayout(layout)
window:show()

sys.Timer.singleShot(800, function()
    print("{MARKER}")
    sys.System.exit(0)
end)
"""


def fail(step, detail):
    print(f"\nFAILED: {step}\n{detail}", flush=True)
    sys.exit(1)


def layout(bundle):
    """python, the launcher command and the resources folder of a bundle."""
    if sys.platform == "darwin":
        resources = bundle / "Contents" / "Resources"
        return (resources / "python" / "bin" / "python3",
                [str(bundle / "Contents" / "MacOS" / "Limer")], resources)
    if sys.platform == "win32":
        return bundle / "python" / "python.exe", [str(bundle / "Limer.exe")], bundle
    return bundle / "python" / "bin" / "python3", [str(bundle / "Limer")], bundle


def environment():
    env = {k: v for k, v in os.environ.items() if not k.startswith("PYTHON")}
    env["QT_QPA_PLATFORM"] = "offscreen"
    return env


def run(command, step, timeout=300, cwd=None):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout,
                                env=environment(), cwd=cwd)
    except subprocess.TimeoutExpired:
        fail(step, f"did not finish in {timeout}s: {command}")
    if result.returncode != 0:
        fail(step, f"exit {result.returncode}\n--- stdout\n{result.stdout[-4000:]}"
                   f"\n--- stderr\n{result.stderr[-4000:]}")
    return result


def make_project(folder):
    (folder / "scripts").mkdir(parents=True)
    (folder / "app.json").write_text(json.dumps({
        "project": {"name": "Smoke", "version": "1.0", "author": "Limer CI"},
        "api": "2.0",
    }), encoding="utf-8")
    (folder / "scripts" / "main.lua").write_text(MAIN_LUA, encoding="utf-8")
    return folder


def check_imports(python):
    code = "; ".join(f"import PySide6.{m}" for m in QT_MODULES) + "; import limekit, lupa, PyInstaller"
    run([str(python), "-I", "-c", code], "1. Qt modules import")
    print("ok  1. every Qt module Limekit uses imports")


def check_project(python, project):
    result = run([str(python), "-I", "-u", "-m", "limekit", str(project)], "2. a project runs", timeout=120)
    if MARKER not in result.stdout:
        fail("2. a project runs", f"no {MARKER} in its output:\n{result.stdout}\n{result.stderr}")
    print("ok  2. a project runs and exits cleanly")


def stop_tree(process):
    if sys.platform == "win32":
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(process.pid)], capture_output=True)
    else:
        os.killpg(process.pid, signal.SIGKILL)


def check_limer(launcher, seconds=20):
    log = Path(tempfile.mkdtemp()) / "limer-output.txt"
    with open(log, "w", encoding="utf-8") as out:
        kwargs = {"start_new_session": True} if sys.platform != "win32" else {}
        process = subprocess.Popen(launcher, stdout=out, stderr=subprocess.STDOUT,
                                   env=environment(), **kwargs)
        deadline = time.time() + seconds
        while time.time() < deadline and process.poll() is None:
            time.sleep(0.5)
        alive = process.poll() is None
        if alive:
            stop_tree(process)
    output = log.read_text(encoding="utf-8", errors="replace")
    if not alive:
        fail("3. Limer starts", f"exited with {process.returncode} within {seconds}s:\n{output[-4000:]}")
    if "Traceback" in output:
        fail("3. Limer starts", f"it is up, but printed a traceback:\n{output[-4000:]}")
    print(f"ok  3. Limer starts from its launcher and is still up after {seconds}s")


def check_build(python, project):
    out = project.parent / "built"
    code = (
        "import sys, json\n"
        "from limekit.build.builder import AppBuilder\n"
        "builder = AppBuilder(sys.argv[1], output_dir=sys.argv[2], options={'onefile': True})\n"
        "ok, message, path = builder.build(console_mode=True)\n"
        "print('BUILD:' + json.dumps([ok, message, path]))\n"
        "sys.exit(0 if ok else 1)\n"
    )
    result = run([str(python), "-I", "-c", code, str(project), str(out)], "4. Build", timeout=900)
    line = next(l for l in result.stdout.splitlines() if l.startswith("BUILD:"))
    _, _, path = json.loads(line[len("BUILD:"):])
    app = Path(path)
    if not app.exists():
        fail("4. Build", f"the build reported {app}, which does not exist")

    # The built app knows nothing of the bundled Python: run it from a
    # folder of its own, as the person it was given to would.
    shipped = Path(tempfile.mkdtemp()) / app.name
    shutil.copy2(app, shipped)
    result = run([str(shipped)], "4. the built app runs", timeout=180)
    if MARKER not in result.stdout:
        fail("4. the built app runs", f"no {MARKER} in its output:\n{result.stdout}\n{result.stderr}")
    print(f"ok  4. Build made {app.name} ({app.stat().st_size / 1048576:.0f} MB), and it runs")


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    bundle = Path(sys.argv[1]).resolve()
    python, launcher, _ = layout(bundle)
    if not python.exists():
        fail("0. layout", f"no bundled Python at {python}")

    work = Path(tempfile.mkdtemp(prefix="limer-smoke-"))
    project = make_project(work / "Smoke App")

    check_imports(python)
    check_project(python, project)
    check_limer(launcher)
    check_build(python, project)
    print("\nall smoke checks passed")


if __name__ == "__main__":
    main()
