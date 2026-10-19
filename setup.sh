#!/usr/bin/env bash
set -euo pipefail

LOG_TAG="[KOTLIN-BOOTSTRAP]"
STATE_FILE="$HOME/.kotlin_bootstrap_stage"
CURRENT_STAGE=$(cat "$STATE_FILE" 2>/dev/null || echo "1")

# Android SDK & Target Configuration
ANDROID_HOME="$HOME/Android/Sdk"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
ANDROID_API_LEVEL="android-35"
BUILD_TOOLS_VERSION="35.0.0"
SYSTEM_IMAGE="system-images;${ANDROID_API_LEVEL};google_apis;x86_64"
AVD_NAME="Pixel_API_35"
DEVICE_PROFILE="pixel_6"

echo "$LOG_TAG Starting Debian Kotlin & Android Env Setup (Stage $CURRENT_STAGE) n.n"

# ==============================================================================
# STAGE 1: Critical OS, Multi-Arch, & Virtualization (Requires Reboot)
# ==============================================================================
if [ "$CURRENT_STAGE" == "1" ]; then
    echo "$LOG_TAG [Stage 1/2] Configuring 32-bit architecture and updating system..."
    sudo dpkg --add-architecture i386
    sudo apt-get update && sudo apt-get upgrade -y

    echo "$LOG_TAG [Stage 1/2] Installing Tier 1: Core utilities & build tools..."
    sudo apt-get install -y \
        curl \
        wget \
        git \
        unzip \
        zip \
        tar \
        build-essential \
        fontconfig \
        libfreetype6

    echo "$LOG_TAG [Stage 1/2] Installing Tier 2: 32-bit compatibility & Emulator libraries..."
    sudo apt-get install -y \
        libc6:i386 \
        libstdc++6:i386 \
        lib32z1 \
        libbz2-1.0:i386 \
        libpulse0 \
        libnss3 \
        libxcomposite1 \
        libxcursor1 \
        libxi6 \
        libxtst6 \
        libasound2

    echo "$LOG_TAG [Stage 1/2] Installing Tier 3: System JDK fallback..."
    sudo apt-get install -y openjdk-21-jdk

    echo "$LOG_TAG [Stage 1/2] Installing Tier 4: KVM hardware acceleration..."
    sudo apt-get install -y \
        qemu-kvm \
        libvirt-daemon-system \
        libvirt-clients \
        bridge-utils

    echo "$LOG_TAG [Stage 1/2] Assigning $USER to kvm and libvirt groups..."
    sudo usermod -aG kvm "$USER"
    sudo usermod -aG libvirt "$USER"

    # Save state for resumption after reboot
    echo "2" > "$STATE_FILE"

    echo "$LOG_TAG Stage 1 complete. System changes (KVM groups & kernel modules) require a reboot."
    read -rp "$LOG_TAG Reboot now? [y/N]: " REBOOT_CHOICE
    if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
        sudo reboot
    else
        echo "$LOG_TAG Please reboot manually and re-run this script to complete Stage 2."
        exit 0
    fi
fi

# ==============================================================================
# STAGE 2: User-Space Toolchains, SDKMAN!, Android SDK & AVD (Post-Reboot)
# ==============================================================================
if [ "$CURRENT_STAGE" == "2" ]; then
    echo "$LOG_TAG [Stage 2/2] Setting up SDKMAN! user-space environment..."

    if [ ! -d "$HOME/.sdkman" ]; then
        echo "$LOG_TAG Installing SDKMAN!..."
        curl -s "https://get.sdkman.io" | bash
    else
        echo "$LOG_TAG SDKMAN! is already installed. n.n"
    fi

    CONFIG_FILE="$HOME/.sdkman/etc/config"
    if [ -f "$CONFIG_FILE" ]; then
        echo "$LOG_TAG Applying resilient non-interactive configuration to $CONFIG_FILE..."
        sed -i 's/^sdkman_auto_answer=.*/sdkman_auto_answer=true/' "$CONFIG_FILE"
        sed -i 's/^sdkman_selfupdate_feature=.*/sdkman_selfupdate_feature=false/' "$CONFIG_FILE"
        sed -i 's/^sdkman_insecure_ssl=.*/sdkman_insecure_ssl=false/' "$CONFIG_FILE"
        sed -i 's/^sdkman_curl_connect_timeout=.*/sdkman_curl_connect_timeout=5/' "$CONFIG_FILE"
        sed -i 's/^sdkman_curl_continue=.*/sdkman_curl_continue=true/' "$CONFIG_FILE"
        sed -i 's/^sdkman_curl_max_time=.*/sdkman_curl_max_time=10/' "$CONFIG_FILE"
        sed -i 's/^sdkman_curl_retry=.*/sdkman_curl_retry=3/' "$CONFIG_FILE"
        sed -i 's/^sdkman_curl_retry_max_time=.*/sdkman_curl_retry_max_time=60/' "$CONFIG_FILE"
        sed -i 's/^sdkman_beta_channel=.*/sdkman_beta_channel=false/' "$CONFIG_FILE"
        sed -i 's/^sdkman_debug_mode=.*/sdkman_debug_mode=false/' "$CONFIG_FILE"
        sed -i 's/^sdkman_colour_enable=.*/sdkman_colour_enable=true/' "$CONFIG_FILE"
        sed -i 's/^sdkman_auto_env=.*/sdkman_auto_env=true/' "$CONFIG_FILE"
        sed -i 's/^sdkman_auto_complete=.*/sdkman_auto_complete=true/' "$CONFIG_FILE"
        sed -i 's/^sdkman_healthcheck_enable=.*/sdkman_healthcheck_enable=true/' "$CONFIG_FILE"
    fi

    # Disable 'set -u' temporarily for SDKMAN internal scripts
    set +u
    export SDKMAN_DIR="$HOME/.sdkman"
    # shellcheck disable=SC1091
    [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ] && source "$HOME/.sdkman/bin/sdkman-init.sh"

    echo "$LOG_TAG Installing Java, Kotlin, and Gradle via SDKMAN!..."
    sdk install java 21.0.4-tem || true
    sdk install kotlin || true
    sdk install gradle || true
    set -u

    # --------------------------------------------------------------------------
    # Android SDK Command-Line Tools Bootstrap
    # --------------------------------------------------------------------------
    echo "$LOG_TAG Setting up Android SDK directory structure at $ANDROID_HOME..."
    mkdir -p "$ANDROID_HOME/cmdline-tools"

    if [ ! -f "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
        echo "$LOG_TAG Downloading Android Command-Line Tools..."
        TMP_ZIP=$(mktemp /tmp/cmdline-tools.XXXXXX.zip)
        TMP_DIR=$(mktemp -d /tmp/cmdline-extract.XXXXXX)

        curl -L "$CMDLINE_TOOLS_URL" -o "$TMP_ZIP"
        unzip -q "$TMP_ZIP" -d "$TMP_DIR"

        # Relocate extracted 'cmdline-tools' contents into 'cmdline-tools/latest'
        rm -rf "$ANDROID_HOME/cmdline-tools/latest"
        mv "$TMP_DIR/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"

        rm -rf "$TMP_ZIP" "$TMP_DIR"
    else
        echo "$LOG_TAG Android Command-Line Tools already present."
    fi

    # Export environment paths for the current execution session
    export ANDROID_HOME
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

    # Persist environment variables idempotently in ~/.bashrc
    if ! grep -q "ANDROID_HOME" "$HOME/.bashrc"; then
        echo "$LOG_TAG Writing ANDROID_HOME and PATH exports to ~/.bashrc..."
        cat << 'EOF' >> "$HOME/.bashrc"

# Android SDK Environment
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
EOF
    fi

    # --------------------------------------------------------------------------
    # SDK Packages, Licenses & AVD Creation
    # --------------------------------------------------------------------------
    echo "$LOG_TAG Accepting Android SDK licenses..."
    # Disable pipefail temporarily so 'yes' closing early doesn't trigger SIGPIPE (exit 141)
    set +o pipefail
    yes | sdkmanager --licenses > /dev/null
    set -o pipefail

    echo "$LOG_TAG Installing platform-tools, build-tools, emulator, and system image..."
    sdkmanager --install \
        "platform-tools" \
        "platforms;${ANDROID_API_LEVEL}" \
        "build-tools;${BUILD_TOOLS_VERSION}" \
        "emulator" \
        "${SYSTEM_IMAGE}"

    echo "$LOG_TAG Creating Android Virtual Device ($AVD_NAME)..."
    echo "no" | avdmanager --verbose create avd \
        --force \
        --name "$AVD_NAME" \
        --package "${SYSTEM_IMAGE}" \
        --tag "google_apis" \
        --abi "x86_64" \
        --device "$DEVICE_PROFILE"

    # Configure hardware acceleration and RAM in the AVD config.ini
    AVD_CONFIG="$HOME/.android/avd/${AVD_NAME}.avd/config.ini"
    if [ -f "$AVD_CONFIG" ]; then
        echo "$LOG_TAG Optimizing AVD hardware configuration..."
        sed -i 's/^hw.keyboard=.*/hw.keyboard=yes/' "$AVD_CONFIG"
        grep -q "^hw.keyboard=" "$AVD_CONFIG" || echo "hw.keyboard=yes" >> "$AVD_CONFIG"
        grep -q "^hw.ramSize=" "$AVD_CONFIG" || echo "hw.ramSize=4096" >> "$AVD_CONFIG"
        grep -q "^hw.gpu.enabled=" "$AVD_CONFIG" || echo "hw.gpu.enabled=yes" >> "$AVD_CONFIG"
        grep -q "^hw.gpu.mode=" "$AVD_CONFIG" || echo "hw.gpu.mode=host" >> "$AVD_CONFIG"
    fi

    # Clean up state file after full completion
    rm -f "$STATE_FILE"
    echo "$LOG_TAG Environment setup complete! Verify KVM with: groups | grep kvm"
    echo "$LOG_TAG Run 'source ~/.bashrc' and launch the emulator with: emulator -avd $AVD_NAME"
fi