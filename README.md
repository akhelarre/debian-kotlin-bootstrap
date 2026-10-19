# Debian Kotlin & Android CLI Bootstrap

A resilient, two-stage Bash provisioning script that sets up a headless Kotlin and Android SDK development environment on Debian-based distributions—complete with hardware-accelerated KVM emulation (`qemu-kvm`), SDKMAN!, and a pre-configured Android Virtual Device (AVD) without requiring Android Studio.

---

## Architecture & Two-Stage Execution

System-level virtualization changes (kernel modules and user group assignments for `kvm` and `libvirt`) require a system reboot before user-space tools can access hardware acceleration. 

To handle this under `set -euo pipefail`, the script uses a persistent state file (`~/.kotlin_bootstrap_stage`) to split execution across two stages:

| Stage | Scope | Actions Performed |
| :--- | :--- | :--- |
| **Stage 1** | **System & Kernel** *(Requires `sudo`)* | Enables `i386` multi-arch, updates `apt` packages, installs core build tools, 32-bit compatibility libraries, system OpenJDK 21 fallback, and `qemu-kvm`/`libvirt`. Adds `$USER` to `kvm` and `libvirt` groups, writes state `2` to `~/.kotlin_bootstrap_stage`, and prompts for a reboot. |
| **Stage 2** | **User-Space** *(Post-Reboot)* | Installs and configures SDKMAN! for non-interactive execution, installs Java 21 (Temurin), Kotlin, and Gradle, bootstraps Android `cmdline-tools` into `~/Android/Sdk`, accepts SDK licenses, provisions an Android 35 (`x86_64`) AVD, enables host GPU acceleration, and cleans up the state file. |
| **Stage 3** | ** Kotlin Android Application ** | This script automates the creation of a modern, production-ready minimal Android project configured with the latest toolchains and libraries as specified in the setup |

---

## Prerequisites

- **OS:** Debian 12 (Bookworm) or newer (or derivative).
- **Hardware:** 64-bit x86_64 CPU with Intel VT-x or AMD-V virtualization enabled in BIOS/UEFI.
- **Display Server:** X11 or Wayland desktop session (required to render the standalone Android Emulator window).
- **Privileges:** Standard user with `sudo` access.

---

## Usage

### 1. Make the script executable
```bash
chmod +x run_pipeline.sh
./run_pipeline.sh
```

### 2. Run Stage 1 (System Setup)
```bash
./bootstrap-kotlin-env.sh
```
When prompted at the end of Stage 1 (`Reboot now? [y/N]:`), press `y` to reboot immediately, or reboot manually when ready.

### 3. Run Stage 2 (Toolchain & Android SDK Setup)
After logging back in, run the exact same command:
```bash
./bootstrap-kotlin-env.sh
```
The script will detect `~/.kotlin_bootstrap_stage`, skip Stage 1, install SDKMAN! and the Android SDK/AVD, and remove the state file upon completion.

### 4. Reload your shell environment
```bash
source ~/.bashrc
```

---

## Configuration Variables

You can customize the target Android SDK and emulator specifications at the top of the script before running Stage 2:

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `ANDROID_HOME` | `$HOME/Android/Sdk` | Root installation directory for the Android SDK. |
| `ANDROID_API_LEVEL` | `android-35` | Target Android API platform version. |
| `BUILD_TOOLS_VERSION` | `35.0.0` | Target Android SDK Build-Tools release. |
| `SYSTEM_IMAGE` | `system-images;android-35;google_apis;x86_64` | Emulator system image package. |
| `AVD_NAME` | `Pixel_API_35` | Name of the generated Android Virtual Device. |
| `DEVICE_PROFILE` | `pixel_6` | Hardware profile passed to `avdmanager`. |

---

## Verification & Daily Workflow

Confirm your user session has active KVM permissions and hardware virtualization support:

### Verify KVM & Group Permissions
```bash
groups | grep -E "kvm|libvirt"
ls -l /dev/kvm
```

### Verify Toolchains
```bash
java -version
kotlin -version
gradle --version
sdkmanager --list_installed
```

### Launch the Android Emulator
Run the pre-configured AVD directly from the terminal:
```bash
emulator -avd Pixel_API_35
```

*Note: The script automatically patches `~/.android/avd/Pixel_API_35.avd/config.ini` with `hw.gpu.mode=host`, `hw.ramSize=4096`, and `hw.keyboard=yes` for native GPU rendering and physical keyboard support.*