#!/usr/bin/env bash
set -euo pipefail

LOG_TAG="[STAGE-2-ENV]"
STATE_FILE="$HOME/.kotlin_bootstrap_stage"

ANDROID_HOME="$HOME/Android/Sdk"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
ANDROID_API_LEVEL="android-35"
BUILD_TOOLS_VERSION="35.0.0"
SYSTEM_IMAGE="system-images;${ANDROID_API_LEVEL};google_apis;x86_64"
AVD_NAME="Pixel_API_35"
DEVICE_PROFILE="pixel_6"

# ------------------------------------------------------------------------------
# 1. SDKMAN & JVM Toolchain
# ------------------------------------------------------------------------------
export SDKMAN_DIR="$HOME/.sdkman"
if [ ! -d "$SDKMAN_DIR" ]; then
    echo "$LOG_TAG Installing SDKMAN!..."
    curl -s "https://get.sdkman.io?rcupdate=false" | bash
fi

CONFIG_FILE="$SDKMAN_DIR/etc/config"
if [ -f "$CONFIG_FILE" ]; then
    sed -i 's/^sdkman_auto_answer=.*/sdkman_auto_answer=true/' "$CONFIG_FILE"
    sed -i 's/^sdkman_selfupdate_feature=.*/sdkman_selfupdate_feature=false/' "$CONFIG_FILE"
    sed -i 's/^sdkman_curl_continue=.*/sdkman_curl_continue=true/' "$CONFIG_FILE"
fi

set +u
# shellcheck disable=SC1091
source "$SDKMAN_DIR/bin/sdkman-init.sh"
sdk install java 21.0.4-tem || true
sdk install kotlin || true
sdk install gradle || true
set -u

# Ensure SDKMAN is present in ~/.bashrc
if ! grep -q "sdkman-init.sh" "$HOME/.bashrc"; then
    cat << 'EOF' >> "$HOME/.bashrc"

# SDKMAN!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
EOF
fi

# ------------------------------------------------------------------------------
# 2. Android Command-Line Tools
# ------------------------------------------------------------------------------
mkdir -p "$ANDROID_HOME/cmdline-tools"

if [ ! -f "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
    echo "$LOG_TAG Downloading Android Command-Line Tools..."
    TMP_ZIP=$(mktemp /tmp/cmdline-tools.XXXXXX.zip)
    TMP_DIR=$(mktemp -d /tmp/cmdline-extract.XXXXXX)

    curl -L "$CMDLINE_TOOLS_URL" -o "$TMP_ZIP"
    unzip -q "$TMP_ZIP" -d "$TMP_DIR"

    rm -rf "$ANDROID_HOME/cmdline-tools/latest"
    mv "$TMP_DIR/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
    rm -rf "$TMP_ZIP" "$TMP_DIR"
fi

export ANDROID_HOME
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

if ! grep -q "ANDROID_HOME" "$HOME/.bashrc"; then
    cat << 'EOF' >> "$HOME/.bashrc"

# Android SDK Environment
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
EOF
fi

# ------------------------------------------------------------------------------
# 3. SDK Packages, System Image & AVD Creation
# ------------------------------------------------------------------------------
echo "$LOG_TAG Accepting licenses and installing platform components..."
set +o pipefail
yes | sdkmanager --licenses > /dev/null
set -o pipefail

sdkmanager --install \
    "platform-tools" \
    "platforms;${ANDROID_API_LEVEL}" \
    "build-tools;${BUILD_TOOLS_VERSION}" \
    "emulator" \
    "${SYSTEM_IMAGE}"

echo "$LOG_TAG Generating AVD ($AVD_NAME)..."
echo "no" | avdmanager --verbose create avd \
    --force \
    --name "$AVD_NAME" \
    --package "${SYSTEM_IMAGE}" \
    --tag "google_apis" \
    --abi "x86_64" \
    --device "$DEVICE_PROFILE"

AVD_CONFIG="$HOME/.android/avd/${AVD_NAME}.avd/config.ini"
if [ -f "$AVD_CONFIG" ]; then
    echo "$LOG_TAG Applying performance overrides to AVD config..."
    sed -i 's/^hw.keyboard=.*/hw.keyboard=yes/' "$AVD_CONFIG" || echo "hw.keyboard=yes" >> "$AVD_CONFIG"
    sed -i 's/^hw.ramSize=.*/hw.ramSize=4096/' "$AVD_CONFIG" || echo "hw.ramSize=4096" >> "$AVD_CONFIG"
    sed -i 's/^hw.gpu.enabled=.*/hw.gpu.enabled=yes/' "$AVD_CONFIG" || echo "hw.gpu.enabled=yes" >> "$AVD_CONFIG"
    sed -i 's/^hw.gpu.mode=.*/hw.gpu.mode=host/' "$AVD_CONFIG" || echo "hw.gpu.mode=host" >> "$AVD_CONFIG"
fi

# Cleanup stage flag
rm -f "$STATE_FILE"
echo "$LOG_TAG Stage 2 finished successfully."
