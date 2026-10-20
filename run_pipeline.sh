#!/usr/bin/env bash
set -euo pipefail

LOG_TAG="[PIPELINE]"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HOME/.kotlin_bootstrap_stage"

APP_DIR="${1:-$HOME/workspace/u3-kotlin}"
APP_NAME="${2:-MiAppModular}"
APP_PKG="${3:-com.miempresa.miapp}"

# Make modular scripts executable
chmod +x "$SCRIPT_DIR"/*.sh

# Determine stage: 1 (initial run), 2 (post-reboot), or done
CURRENT_STAGE=$(cat "$STATE_FILE" 2>/dev/null || echo "1")

# ------------------------------------------------------------------------------
# 1. System Provisioning (OS & Toolchains)
# ------------------------------------------------------------------------------
if [ "$CURRENT_STAGE" == "1" ]; then
    echo "$LOG_TAG Stage 1: Running OS, Multi-Arch & Virtualization setup..."
    "$SCRIPT_DIR/stage1-os.sh"
    # stage1-os.sh handles the reboot prompt and state file update
    exit 0
fi

if [ "$CURRENT_STAGE" == "2" ]; then
    echo "$LOG_TAG Stage 2: Running SDKMAN, Toolchain & Android SDK setup..."
    "$SCRIPT_DIR/stage2-env.sh"
fi

# ------------------------------------------------------------------------------
# 2. Load Toolchain Environment in Current Subshell
# ------------------------------------------------------------------------------
echo "$LOG_TAG Initializing SDKMAN & Android Environment..."
export SDKMAN_DIR="$HOME/.sdkman"
if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    set +u
    # shellcheck disable=SC1090
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
    set -u
fi

export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# ------------------------------------------------------------------------------
# 3. Project Scaffolding
# ------------------------------------------------------------------------------
SCAFFOLD_SCRIPT="$SCRIPT_DIR/scaffold-kotlin-app.sh"
[[ ! -f "$SCAFFOLD_SCRIPT" ]] && SCAFFOLD_SCRIPT="$SCRIPT_DIR/stage3-scaffold.sh"

if [[ -f "$SCAFFOLD_SCRIPT" ]]; then
    echo "$LOG_TAG Scaffolding Kotlin application..."
    mkdir -p "$(dirname "$APP_DIR")"
    "$SCAFFOLD_SCRIPT" "$APP_DIR" "$APP_NAME" "$APP_PKG"
else
    echo "$LOG_TAG No scaffold script found. Skipping template generation."
fi

# ------------------------------------------------------------------------------
# 4. Dependency Cache Warming & Verification
# ------------------------------------------------------------------------------
if [[ -f "$APP_DIR/gradlew" ]]; then
    echo "$LOG_TAG Compiling project and caching dependencies..."
    cd "$APP_DIR"
    ./gradlew run --no-daemon
fi

echo "$LOG_TAG === Pipeline completed successfully! ==="
echo "$LOG_TAG === Pipeline completed successfully! Project ready at: $APP_DIR ==="
