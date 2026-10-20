# Debian Kotlin & Android CLI Bootstrap

A resilient, multi-stage Bash provisioning pipeline that sets up a headless Kotlin and Android SDK development environment on Debian-based distributions—complete with hardware-accelerated KVM emulation (`qemu-kvm`), SDKMAN!, and a pre-configured Android Virtual Device (AVD) without requiring Android Studio.

---

## Architecture & Execution Workflow

System-level virtualization changes (kernel modules and user group assignments for `kvm` and `libvirt`) require a session reset or system reboot before user-space tools can access hardware acceleration.

To maintain resilience under `set -euo pipefail`, the pipeline tracks execution progress via a persistent state file (`~/.kotlin_bootstrap_stage`):

| Stage | Scope | Actions Performed |
| :--- | :--- | :--- |
| **Stage 1** (`stage1-os.sh`) | System & Kernel (Requires `sudo`) | Enables `i386` multi-arch, updates apt repositories, installs core build tools, 32-bit runtime compatibility libraries, system OpenJDK fallback, and `qemu-kvm`/`libvirt`. Adds `$USER` to `kvm` and `libvirt` groups, writes state `2` to `~/.kotlin_bootstrap_stage`, and prompts for a system reboot. |
| **Stage 2** (`stage2-env.sh`) | User-Space (Post-Reboot) | Installs and configures SDKMAN! for non-interactive execution, provisions Java 21 (Temurin), Kotlin, and Gradle, bootstraps Android `cmdline-tools` into `~/Android/Sdk`, accepts SDK licenses, provisions an Android 35 (`x86_64`) AVD, configures host GPU acceleration, and cleans up the state file. |
| **Stage 3** (`scaffold-kotlin-app.sh`) | Project Scaffold | Generates a modern, production-ready minimal Kotlin Android application pre-configured with the latest toolchains, Gradle wrapper, and project layout. |

---

## Prerequisites

- **OS:** Debian 12 (Bookworm), Debian 13 (Trixie), or compatible derivatives.
- **Hardware:** 64-bit `x86_64` CPU with Intel VT-x or AMD-V virtualization enabled in BIOS/UEFI (nested virtualization enabled if running inside a VM).
- **Display Server:** X11 or Wayland desktop session (required to render the standalone Android Emulator GUI window).
- **Privileges:** Standard non-root user with `sudo` permissions.

---

## Usage

### 1. Grant Execution Permissions

Make all pipeline scripts executable:

```bash
chmod +x *.sh

```

### 2. Orchestrated Run (Recommended)

You can launch the complete pipeline driver:

```bash
./run_pipeline.sh

```

*Alternatively, you can run `./setup.sh` depending on your entrypoint preference.*

### 3. Step-by-Step Execution

#### Step A: Run Stage 1 (System Setup)

```bash
./stage1-os.sh

```

When prompted at the end (`Reboot now? [y/N]:`), press `y` to reboot immediately, or reboot manually when convenient.

#### Step B: Run Stage 2 (Toolchain & Android SDK Setup)

After logging back in, run:

```bash
./stage2-env.sh

```

The script detects the state, completes the user-space provisioning for SDKMAN!, Android command-line tools, and the AVD, and removes `~/.kotlin_bootstrap_stage`.

#### Step C: Scaffold a New Project

```bash
./scaffold-kotlin-app.sh

```

### 4. Reload Shell Environment

Apply newly added PATH entries and environment variables:

```bash
source ~/.bashrc

```

---

## Configuration Variables

You can customize the target Android SDK and emulator specifications directly inside the script variables before running Stage 2:

| Variable | Default Value | Description |
| --- | --- | --- |
| `ANDROID_HOME` | `$HOME/Android/Sdk` | Root installation directory for the Android SDK. |
| `ANDROID_API_LEVEL` | `android-35` | Target Android API platform version. |
| `BUILD_TOOLS_VERSION` | `35.0.0` | Target Android SDK Build-Tools release. |
| `SYSTEM_IMAGE` | `system-images;android-35;google_apis;x86_64` | Emulator system image package. |
| `AVD_NAME` | `Pixel_API_35` | Name of the generated Android Virtual Device. |
| `DEVICE_PROFILE` | `pixel_6` | Hardware profile passed to `avdmanager`. |

---

## Verification & Daily Workflow

### Verify KVM & Group Permissions

Confirm your current session has active KVM permissions and device node access:

```bash
groups | grep -E "kvm|libvirt"
ls -l /dev/kvm

```

### Verify Toolchains

Confirm that all development runtimes respond correctly:

```bash
java -version
kotlin -version
gradle --version
sdkmanager --list_installed

```

### Launch the Android Emulator

Run the pre-configured AVD directly from your terminal:

```bash
emulator -avd Pixel_API_35

```

> **Note:** The setup automatically patches `~/.android/avd/Pixel_API_35.avd/config.ini` with `hw.gpu.mode=host`, `hw.ramSize=4096`, and `hw.keyboard=yes` for native hardware GPU acceleration and physical keyboard input.

```
