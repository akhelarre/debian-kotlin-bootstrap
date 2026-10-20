#!/usr/bin/env bash
set -euo pipefail

LOG_TAG="[STAGE-1-OS]"
STATE_FILE="$HOME/.kotlin_bootstrap_stage"

echo "$LOG_TAG Configuring multi-arch (i386) and updating repositories..."
sudo dpkg --add-architecture i386
sudo apt-get update && sudo apt-get upgrade -y

echo "$LOG_TAG Installing core build utilities..."
sudo apt-get install -y \
    curl wget git unzip zip tar build-essential fontconfig libfreetype6

echo "$LOG_TAG Installing 32-bit compatibility & emulator shared libraries..."
sudo apt-get install -y \
    libc6:i386 libstdc++6:i386 lib32z1 libbz2-1.0:i386 \
    libpulse0 libnss3 libxcomposite1 libxcursor1 libxi6 libxtst6 libasound2

echo "$LOG_TAG Installing fallback OpenJDK 21 & KVM virtualization stack..."
sudo apt-get install -y \
    openjdk-21-jdk qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

echo "$LOG_TAG Adding $USER to kvm and libvirt groups..."
sudo usermod -aG kvm "$USER"
sudo usermod -aG libvirt "$USER"

# Mark stage 1 complete
echo "2" > "$STATE_FILE"

echo "$LOG_TAG Stage 1 complete. Kernel group updates require a session reload/reboot."
read -rp "$LOG_TAG Reboot now? [y/N]: " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
    sudo reboot
else
    echo "$LOG_TAG Please reboot and execute './pipeline.sh' to continue."
    exit 0
fi
