"""
Limer Build Script (Folder Mode)
Builds Limer into a folder with executable + dependencies.
Faster startup than single-file mode.

Usage:
    python build_folder.py [options]

Options:
    --console       Show console window in built app
    --clean         Clean build artifacts before building
    --output DIR    Custom output directory
"""

import sys
import os
import argparse

# Add limekit to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from limekit.build.builder import AppBuilder


def main():
    parser = argparse.ArgumentParser(description="Build Limer into a folder")
    parser.add_argument("--console", action="store_true", help="Show console window")
    parser.add_argument("--clean", action="store_true", help="Clean before building")
    parser.add_argument("--output", type=str, help="Output directory")
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
    else:
        print()
        print("BUILD FAILED!")
        print(f"Error: {message}")
        sys.exit(1)

    print()
    print("=" * 60)


if __name__ == "__main__":
    main()
