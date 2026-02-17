#!/bin/bash
# ============================================================
#   LIMER BUILD SCRIPT (FOLDER MODE)
#   Builds as folder - faster startup than single file
# ============================================================

echo ""
echo "============================================================"
echo "  LIMER BUILD SYSTEM (FOLDER MODE)"
echo "============================================================"
echo ""

# Change to script directory
cd "$(dirname "$0")"

# Activate venv if it exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python3 is not installed or not in PATH"
    exit 1
fi

echo "Python version: $(python3 --version)"
echo ""

# Run the folder build script
python3 build_folder.py --console --clean
BUILD_RESULT=$?

echo ""
echo "============================================================"
if [ $BUILD_RESULT -ne 0 ]; then
    echo "  BUILD FAILED - See errors above"
else
    echo "  BUILD COMPLETE - Check the 'dist' folder"
fi
echo "============================================================"
echo ""

exit $BUILD_RESULT
