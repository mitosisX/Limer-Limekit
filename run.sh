#!/bin/bash
# ============================================================
#   LIMER RUN SCRIPT
#   Run Limer in development mode
# ============================================================

# Change to script directory
cd "$(dirname "$0")"

# Activate venv if it exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Run the application
python3 -c "from limekit import runner"
