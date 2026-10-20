#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HOME/.kotlin_bootstrap_stage"
CURRENT_STAGE=$(cat "$STATE_FILE" 2>/dev/null || echo "1")

if [ "$CURRENT_STAGE" == "1" ]; then
    exec "$SCRIPT_DIR/stage1-os.sh"
else
    exec "$SCRIPT_DIR/stage2-env.sh"
fi
