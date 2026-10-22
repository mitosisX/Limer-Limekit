"""
Limer Build Script (Folder Mode)
Builds Limer into a folder with executable + dependencies.
Faster startup than single-file mode.

NOT FOR RELEASES. A PyInstaller-frozen Limer cannot run projects: its
sys.executable is Limer itself, with no interpreter to start one with. Release
builds come from package_portable.py, which ships a real Python instead.

Usage:
    python build_folder.py [options]

Options:
    --console       Show console window in built app
    --clean         Clean build artifacts before building
    --output DIR    Custom output directory
    --zip           Also package the build as Limer-<version>-<os>.zip
"""

import sys
import os
import json
import shutil
import argparse

# Add limekit to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from limekit.build.builder import AppBuilder


def os_label():
    if sys.platform == "win32":
        return "windows"
    if sys.platform == "darwin":
        return "macos"
    return "linux"


def package_zip(output_path, project_path):
    """Zip the built folder so it unpacks to a single Limer/ directory.

    A zip, never a rar: every OS opens a zip without installing anything,
    which is the whole point of shipping Limer as one download.
    """
    with open(os.path.join(project_path, "app.json"), encoding="utf-8") as f:
        version = json.load(f)["project"]["version"]

    build_folder = os.path.dirname(output_path)
    parent, name = os.path.split(build_folder)
    archive_base = os.path.join(parent, f"{name}-{version}-{os_label()}")
    return shutil.make_archive(archive_base, "zip", root_dir=parent, base_dir=name)


def main():
    parser = argparse.ArgumentParser(description="Build Limer into a folder")
    parser.add_argument("--console", action="store_true", help="Show console window")
    parser.add_argument("--clean", action="store_true", help="Clean before building")
    parser.add_argument("--output", type=str, help="Output directory")
    parser.add_argument("--zip", action="store_true", help="Package the build as a release zip")
    args = parser.parse_args()

    project_path = os.path.dirname(os.path.abspath(__file__))

    print("=" * 60)
    print("  LIMER BUILD SYSTEM (FOLDER MODE)")
    print("=" * 60)
    print(f"Project: {project_path}")
    print(f"Console Mode: {args.console}")
    print(f"Build Type: Folder (faster startup)")
    print()

    # Create builder with onefile=False for folder mode
    options = {
        "console": args.console,
        "onefile": False,
    }

    if args.output:
        options["output_dir"] = args.output

    builder = AppBuilder(project_path, output_dir=args.output, options=options)

    # Clean if requested
    if args.clean:
        print("Cleaning previous build artifacts...")
        builder.clean()
        print()

    # Build
    print("Starting build process...")
    print("-" * 60)

    success, message, output_path = builder.build(console_mode=args.console)

    print("-" * 60)

    if success:
        print()
        print("BUILD SUCCESSFUL!")
        print(f"Output: {output_path}")
        if args.zip:
            print(f"Release zip: {package_zip(output_path, project_path)}")
    else:
        print()
        print("BUILD FAILED!")
        print(f"Error: {message}")
        sys.exit(1)

    print()
    print("=" * 60)


if __name__ == "__main__":
    main()
