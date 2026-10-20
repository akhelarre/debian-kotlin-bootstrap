#!/usr/bin/env bash
set -euo pipefail

LOG_TAG="[PIPELINE]"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration & arguments
APP_DIR="${1:-$HOME/workspace/u3-kotlin}"
APP_NAME="${2:-MiAppModular}"
APP_PKG="${3:-com.miempresa.miapp}"

# Detect which scaffold script exists in the directory
if [[ -f "$SCRIPT_DIR/scaffold-kotlin-app.sh" ]]; then
    SCAFFOLD_SCRIPT="$SCRIPT_DIR/scaffold-kotlin-app.sh"
elif [[ -f "$SCRIPT_DIR/stage3-scaffold.sh" ]]; then
    SCAFFOLD_SCRIPT="$SCRIPT_DIR/stage3-scaffold.sh"
else
    echo "$LOG_TAG Error: No scaffolding script found in $SCRIPT_DIR" >&2
    exit 1
fi

echo "$LOG_TAG === Starting Kotlin Bootstrap Pipeline ==="

# ------------------------------------------------------------------------------
# 1. Provision Debian Environment
# ------------------------------------------------------------------------------
echo "$LOG_TAG [1/4] Provisioning system & dependencies..."
chmod +x "$SCRIPT_DIR/setup.sh" "$SCAFFOLD_SCRIPT"
"$SCRIPT_DIR/setup.sh"

# ------------------------------------------------------------------------------
# 2. Load SDKMAN into Current Subshell
# ------------------------------------------------------------------------------
echo "$LOG_TAG [2/4] Loading SDKMAN environment..."
SDKMAN_INIT="$HOME/.sdkman/bin/sdkman-init.sh"
if [[ -s "$SDKMAN_INIT" ]]; then
    set +u
    # shellcheck disable=SC1090
    source "$SDKMAN_INIT"
    set -u
else
    echo "$LOG_TAG Warning: SDKMAN init script not found at $SDKMAN_INIT" >&2
fi

# ------------------------------------------------------------------------------
# 3. Project Scaffolding
# ------------------------------------------------------------------------------
echo "$LOG_TAG [3/4] Scaffolding Kotlin application..."
mkdir -p "$(dirname "$APP_DIR")"
"$SCAFFOLD_SCRIPT" "$APP_DIR" "$APP_NAME" "$APP_PKG"

# ------------------------------------------------------------------------------
# 4. Build Validation & Cache Warming
# ------------------------------------------------------------------------------
echo "$LOG_TAG [4/4] Compiling and warming Gradle dependency cache..."
cd "$APP_DIR"
./gradlew run --no-daemon

echo "$LOG_TAG === Pipeline completed successfully! Project ready at: $APP_DIR ==="
