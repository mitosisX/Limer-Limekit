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

# Limer targets the Limekit 2.0 engine (app.json declares "api": "2.0").
# The old `python3 -c "from limekit import runner"` starts the 1.x engine,
# which injects flat globals and has no module system -- Limer would die on
# its first require("limekit.ui").
python3 -m limekit .
