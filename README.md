# DES Head-Unit

> **Automotive-Grade Embedded Linux System for Raspberry Pi 4**
> A production-ready head unit and instrument cluster platform built with Yocto Project, Qt 6, and Wayland.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Yocto: Scarthgap](https://img.shields.io/badge/Yocto-Scarthgap-blue.svg)](https://www.yoctoproject.org/)
[![Qt: 6.5+](https://img.shields.io/badge/Qt-6.5%2B-green.svg)](https://www.qt.io/)

---

## 📖 Overview

**DES Head-Unit** is a complete automotive cockpit system designed for embedded Linux environments. It combines a modern Qt 6-based user interface with a custom Yocto Linux distribution, providing:

- **Dual Display Support**: Simultaneous head unit (main screen) and instrument cluster displays
- **Real-time Vehicle Communication**: CAN bus integration for vehicle data exchange
- **Modern UI Framework**: Qt 6 QML with Wayland compositor for smooth graphics
- **Production-Ready**: Full Yocto build system with systemd service orchestration
- **Modular Architecture**: Clean separation between UI, business logic, and hardware abstraction

### Use Cases

- Automotive infotainment systems
- Instrument cluster displays
- Embedded Linux development learning
- Qt/QML application deployment
- Yocto Project reference implementation

---

## ✨ Key Features

### 🎨 User Interface
- **Qt 6 Quick/QML** for declarative UI development
- **Wayland** compositor for efficient GPU-accelerated rendering
- **Responsive Design** optimized for 1024x600 touch displays
- **Theme Support** with customizable UI components

### 🚗 Vehicle Integration
- **CAN Bus Support** via SocketCAN (MCP2518FD controller)
- **Real-time Data** processing at 500kbps
- **D-Bus IPC** for inter-application communication
- **Bluetooth Audio** with PulseAudio integration

### 🏗️ System Architecture
- **Yocto Linux** custom distribution based on Poky Scarthgap
- **systemd** for service management and dependency handling
- **RPM Package Management** for on-device updates
- **Custom BSP** for Raspberry Pi 4 (64-bit ARM)

### 🔧 Hardware Support
- **Raspberry Pi 4** Model B (4GB/8GB recommended)
- **Dual HDMI** outputs (1024x600 @ 60Hz each)
- **Seeed CAN-FD HAT v2** for automotive communication
- **USB Audio** and Bluetooth A2DP sink

---

## 🏛️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     DES Cockpit System                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐              ┌─────────────────┐          │
│  │   Head-Unit     │              │   Instrument    │          │
│  │   (Qt 6 QML)    │◄───D-Bus────►│     Cluster     │          │
│  │                 │              │   (Qt 6 QML)    │          │
│  │  • Navigation   │              │  • Speed        │          │
│  │  • Media Player │              │  • RPM          │          │
│  │  • Climate      │              │  • Gear Status  │          │
│  │  • Bluetooth    │              │  • Warnings     │          │
│  └────────┬────────┘              └────────┬────────┘          │
│           │                                │                   │
│           └────────────┬───────────────────┘                   │
│                        │                                       │
│           ┌────────────▼────────────┐                          │
│           │   Wayland (Weston)      │                          │
│           │   Dual Display Output   │                          │
│           └────────────┬────────────┘                          │
│                        │                                       │
│           ┌────────────▼────────────┐                          │
│           │   Hardware Abstraction  │                          │
│           │  • SocketCAN (can0/1)   │                          │
│           │  • PulseAudio           │                          │
│           │  • Bluetooth (BlueZ)    │                          │
│           └─────────────────────────┘                          │
│                                                                 │
│                 Raspberry Pi 4 (ARM64)                          │
│              Custom Yocto Linux (systemd)                       │
└─────────────────────────────────────────────────────────────────┘
```

### Communication Flow

```
Vehicle CAN Bus
       │
       ▼
MCP2518FD (SPI)
       │
       ▼
SocketCAN (can0/can1)
       │
       ▼
Instrument Cluster ◄──D-Bus──► Head-Unit
       │                            │
       └────────┬───────────────────┘
                │
                ▼
        User Interface
```

---

## 🛠️ Technology Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Hardware** | Raspberry Pi 4 | 64-bit | ARM Cortex-A72 quad-core |
| **BSP** | meta-raspberrypi | Latest | Board support package |
| **Operating System** | Yocto Linux | Scarthgap | Custom embedded Linux |
| **Kernel** | Linux | 6.6.63 | Real-time capable kernel |
| **Init System** | systemd | 255+ | Service orchestration |
| **Display Server** | Wayland + Weston | 13.0+ | Compositor for dual displays |
| **UI Framework** | Qt | 6.5+ | Application framework |
| **Audio** | PulseAudio | 17.0+ | Audio routing & Bluetooth |
| **Connectivity** | BlueZ | 5.70+ | Bluetooth stack |
| **Networking** | ConnMan | 1.42+ | Network manager |
| **CAN Protocol** | SocketCAN | Kernel | Vehicle communication |
| **Package Manager** | RPM | DNF/Smart | Software updates |

---

## 📁 Repository Structure

```
DES_Head-Unit/
├── Head-Unit/                      # Qt 6 Head-Unit Application
│   ├── ui/                         # QML user interface
│   │   ├── main.qml               # Main entry point
│   │   ├── pages/                 # Screen pages
│   │   └── components/            # Reusable components
│   ├── src/                       # C++ backend logic
│   │   ├── GearController/       # Gear management
│   │   ├── MusicController/      # Media player
│   │   └── WeatherService/       # Weather API
│   └── CMakeLists.txt            # Build configuration
│
├── DES_Instrument-Cluster/        # Instrument Cluster Application
│   ├── Cluster-app/              # Qt 6 cluster UI
│   ├── Arduino/                  # Speed sensor firmware
│   ├── Pi-controller/            # Python controller scripts
│   └── systemd/                  # Service units
│
├── yocto-workspace/              # Yocto Project Workspace
│   ├── poky/                     # Yocto reference distribution
│   ├── meta-openembedded/        # Community layers
│   ├── meta-qt6/                 # Qt 6 support layer
│   ├── meta-raspberrypi/         # Raspberry Pi BSP
│   └── meta-custom/              # DES custom layers
│       ├── meta-env/             # Distribution & image
│       │   ├── conf/distro/des.conf
│       │   └── recipes-core/images/des-image.bb
│       ├── meta-app/             # Application recipes
│       │   ├── recipes-des/headunit/
│       │   └── recipes-des/instrument-cluster/
│       └── meta-piracer/         # Hardware integration
│           ├── recipes-support/can/
│           └── recipes-support/piracer-controller/
│
├── .github/                      # CI/CD workflows
├── ARCHITECTURE.md               # System architecture docs
├── YOCTO_PROJECT_DETAILED_GUIDE_KR.md  # Comprehensive guide (Korean)
└── README.md                     # This file
```

---

## 🚀 Quick Start

### Prerequisites

#### Hardware
- Raspberry Pi 4 Model B (4GB+ RAM recommended)
- 2× 7" HDMI displays (1024x600 resolution)
- Seeed CAN-FD HAT v2.0 (optional, for CAN bus)
- 32GB+ microSD card (Class 10 or better)
- 5V/3A USB-C power supply

#### Development Machine
- Linux host (Ubuntu 20.04+ recommended)
- 100GB+ free disk space
- 8GB+ RAM (16GB recommended for Yocto builds)
- Qt 6.5+ installed (for local development)

### Option 1: Flash Pre-built Image (Fastest)

```bash
# Download the latest release image
wget https://github.com/your-org/DES_Head-Unit/releases/latest/des-image-raspberrypi4-64.wic.bz2

# Flash to SD card (replace /dev/sdX with your SD card device)
bunzip2 -c des-image-raspberrypi4-64.wic.bz2 | sudo dd of=/dev/sdX bs=4M status=progress

# Or use balenaEtcher (GUI tool)
```

### Option 2: Build from Source

#### Step 1: Clone the Repository

```bash
git clone --recursive https://github.com/your-org/DES_Head-Unit.git
cd DES_Head-Unit
```

#### Step 2: Initialize Yocto Environment

```bash
cd yocto-workspace
source poky/oe-init-build-env build-des
```

#### Step 3: Build the Image

```bash
# Full system image (takes 4-8 hours on first build)
bitbake des-image

# Or build only the applications for testing
bitbake headunit instrument-cluster
```

#### Step 4: Flash the Image

```bash
cd tmp-glibc/deploy/images/raspberrypi4-64/

# Using dd
bunzip2 -c des-image-raspberrypi4-64.wic.bz2 | sudo dd of=/dev/sdX bs=4M status=progress

# Using bmaptool (faster)
bmaptool copy des-image-raspberrypi4-64.wic.bz2 /dev/sdX
```

### First Boot

1. **Insert SD card** into Raspberry Pi 4
2. **Connect displays** to both HDMI ports
3. **Power on** the device
4. **Wait for boot** (30-60 seconds)
5. **Login via SSH** (optional):
   ```bash
   ssh root@<raspberry-pi-ip>
   # Default: no password (debug builds only)
   ```

---

## 💻 Local Development

### Building Head-Unit Locally

```bash
# Install Qt 6.5+ from qt.io or your package manager
sudo apt install qt6-base-dev qt6-declarative-dev qt6-multimedia-dev

# Configure with CMake
cmake -S Head-Unit -B build-headunit \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH=/opt/Qt/6.5.3/gcc_64

# Build
cmake --build build-headunit -j$(nproc)

# Run with session bus (for development)
DES_GEAR_USE_SESSION_BUS=1 ./build-headunit/HeadUnitApp
```

### Building Instrument Cluster

```bash
cd DES_Instrument-Cluster/Cluster-app

# Native build (on ARM host)
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
./appIC

# Cross-compile (on x86 host for aarch64 target)
# Use the provided Docker build environment
cd ../build-tool
docker build -t cluster-builder -f Dockerfile.x86 .
docker run --rm -v $(pwd)/..:/work cluster-builder
```

### Development Tips

- **Use Qt Creator**: Import `CMakeLists.txt` for IDE integration
- **Hot Reload QML**: Enable QML debugging for live UI updates
- **D-Bus Inspection**: Use `d-feet` or `qdbus` to monitor messages
- **CAN Simulation**: Use `vcan` (virtual CAN) for testing without hardware

---

## 📦 Yocto Build System

### Layer Structure

The project uses a modular layer architecture:

| Layer | Priority | Purpose |
|-------|----------|---------|
| `meta-custom/meta-env` | 7 | Distribution policy, system image |
| `meta-custom/meta-app` | 7 | Application recipes (HeadUnit, Cluster) |
| `meta-custom/meta-piracer` | 7 | Hardware-specific recipes (CAN, sensors) |
| `meta-qt6` | 6 | Qt 6 framework support |
| `meta-raspberrypi` | 5 | Raspberry Pi BSP |
| `meta-openembedded/meta-oe` | 5 | Extended packages |
| `poky/meta` | 5 | OpenEmbedded Core |

### Key Configuration Files

#### `build-des/conf/local.conf`
- Machine: `raspberrypi4-64`
- Distro: `des`
- Parallel builds: `BB_NUMBER_THREADS = "4"`, `PARALLEL_MAKE = "-j 4"`
- Qt Wayland support: `PACKAGECONFIG:append:pn-qtbase = " wayland gles2"`
- Disk monitoring and build optimizations

#### `build-des/conf/bblayers.conf`
- Lists all active layers
- Order matters for recipe priority

#### `meta-custom/meta-env/conf/distro/des.conf`
- Distribution identity: `DISTRO_NAME = "DES Head-Unit"`
- Init system: `VIRTUAL-RUNTIME_init_manager = "systemd"`
- Features: `wayland opengl pulseaudio bluetooth`

#### `meta-custom/meta-env/recipes-core/images/des-image.bb`
- Final image recipe
- Package selection via `IMAGE_INSTALL`
- Rootfs post-processing (user groups, services)

### Build Commands

```bash
# Source environment (do this every time)
cd yocto-workspace
source poky/oe-init-build-env build-des

# List available recipes
bitbake-layers show-recipes

# Build specific packages
bitbake qtbase          # Qt framework
bitbake headunit        # Head-Unit app
bitbake can0            # CAN interface service

# Build full image
bitbake des-image

# Clean a recipe (force rebuild)
bitbake -c cleansstate headunit

# Check recipe dependencies
bitbake -g des-image && cat pn-buildlist

# Generate SDK for cross-compilation
bitbake -c populate_sdk des-image
```

### Build Optimization

```bash
# Enable shared state cache (speeds up rebuilds)
SSTATE_DIR = "/path/to/shared/sstate-cache"

# Use download mirror
DL_DIR = "/path/to/shared/downloads"

# Parallel builds (adjust based on your CPU/RAM)
BB_NUMBER_THREADS = "8"      # BitBake tasks
PARALLEL_MAKE = "-j 8"       # make compilation

# Remove intermediate work files (saves disk space)
INHERIT += "rm_work"
RM_WORK_EXCLUDE += "qtbase qtdeclarative"  # Keep Qt sources
```

### Output Artifacts

After a successful build:

```
build-des/tmp-glibc/deploy/images/raspberrypi4-64/
├── des-image-raspberrypi4-64.wic.bz2      # Compressed disk image
├── des-image-raspberrypi4-64.rpi-sdimg    # Raw SD card image
├── Image                                   # Linux kernel
├── bcm2711-rpi-4-b.dtb                    # Device tree
├── overlays/                              # Device tree overlays
└── modules-*.tgz                          # Kernel modules
```

---

## 🔧 System Configuration

### Dual Display Setup

The system automatically configures dual HDMI outputs:

**config.txt settings** (applied via `rpi-config_%.bbappend`):
```ini
# Head-Unit Display (HDMI-0)
hdmi_group:0=2
hdmi_mode:0=87
hdmi_cvt:0=1024 600 60 6 0 0 0
hdmi_drive:0=2

# Instrument Cluster Display (HDMI-1)
hdmi_group:1=2
hdmi_mode:1=87
hdmi_cvt:1=1024 600 60 6 0 0 0
hdmi_drive:1=2

# Common settings
max_framebuffers=2
disable_overscan=1
gpu_mem=128
```

### CAN Bus Configuration

CAN interfaces are brought up at boot via systemd services:

**can0.service** / **can1.service**:
```ini
[Unit]
Description=CAN interface can0
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/ip link set can0 type can bitrate 500000
ExecStart=/usr/sbin/ip link set can0 up

[Install]
WantedBy=multi-user.target
```

**Device Tree Overlay** (`seeed-can-fd-hat-v2.dtbo`):
- Enables SPI0 bus
- Registers MCP2518FD CAN controller
- Configures GPIO interrupts

### Service Dependencies

```
graphical.target
  └─► weston.service (Wayland compositor)
       ├─► headunit.service (Head-Unit UI)
       │    └─► rfkill-unblock.service (Bluetooth)
       └─► instrument-cluster.service (Cluster UI)
            └─► piracer-controller.service (Vehicle controller)
                 └─► can1.service (CAN bus)
```

### Network Configuration

- **WiFi**: Auto-enabled via `wifi-auto-enable.service`
- **Ethernet**: DHCP by default
- **Bluetooth**: Managed by BlueZ with PulseAudio integration
- **Network Manager**: ConnMan for unified network control

---

## 🐛 Troubleshooting

### Build Issues

**Problem**: `ERROR: Nothing PROVIDES 'qtbase'`
```bash
# Solution: Ensure meta-qt6 layer is added
bitbake-layers show-layers
bitbake-layers add-layer ../meta-qt6
```

**Problem**: `do_compile failed` for a recipe
```bash
# Solution: Check build logs
cat tmp-glibc/work/*/headunit/*/temp/log.do_compile

# Force clean rebuild
bitbake -c cleansstate headunit
bitbake headunit
```

**Problem**: Out of disk space during build
```bash
# Solution: Enable rm_work and clean tmp
echo 'INHERIT += "rm_work"' >> conf/local.conf
rm -rf tmp-glibc/work/*
```

### Runtime Issues

**Problem**: HeadUnit not starting
```bash
# Check service status
ssh root@<pi-ip>
systemctl status headunit

# View logs
journalctl -u headunit -f

# Manually run for debugging
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY=/run/wayland-0
/usr/bin/HeadUnitApp
```

**Problem**: Wayland connection failed
```bash
# Check Weston compositor
systemctl status weston

# Verify Wayland socket
ls -la /run/wayland-0

# Restart Weston
systemctl restart weston
```

**Problem**: CAN interface not found
```bash
# Check CAN devices
ip link show can0

# Verify kernel module
lsmod | grep mcp251xfd

# Check device tree overlay
dtoverlay -l | grep seeed

# View kernel logs
dmesg | grep -i can
```

**Problem**: No Bluetooth audio
```bash
# Check PulseAudio
systemctl status pulseaudio

# Verify Bluetooth service
systemctl status bluetooth

# Check bluez-alsa
systemctl status bluealsa

# Test Bluetooth pairing
bluetoothctl
> scan on
> pair <device-mac>
```

### Performance Tuning

**Slow UI rendering**:
- Increase GPU memory: `gpu_mem=256` in `config.txt`
- Enable GPU acceleration: Verify VC4 driver loaded (`dmesg | grep vc4`)
- Reduce Qt logging: `export QT_LOGGING_RULES="*.debug=false"`

**High memory usage**:
- Check processes: `htop`
- Disable unused services: `systemctl disable <service>`
- Optimize Qt Quick: Use `ShaderEffect` caching

---

## 📚 Documentation

### Comprehensive Guides

- **[YOCTO_PROJECT_DETAILED_GUIDE_KR.md](./YOCTO_PROJECT_DETAILED_GUIDE_KR.md)**: 200+ page deep-dive into the Yocto build system (Korean)
- **[ARCHITECTURE.md](./ARCHITECTURE.md)**: System architecture and design decisions
- **[Head-Unit/README.md](./Head-Unit/README.md)**: Qt application development guide
- **[DES_Instrument-Cluster/README.md](./DES_Instrument-Cluster/README.md)**: Cluster application and hardware setup

### External Resources

- [Yocto Project Documentation](https://docs.yoctoproject.org/)
- [Qt 6 Documentation](https://doc.qt.io/qt-6/)
- [Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/)
- [Wayland Protocol](https://wayland.freedesktop.org/docs/html/)
- [SocketCAN Kernel Docs](https://www.kernel.org/doc/Documentation/networking/can.txt)

### API Reference

D-Bus interface for vehicle communication:

```xml
<interface name="com.des.vehicle.Gear">
  <method name="GetGear">
    <arg name="gear" type="y" direction="out"/>
  </method>
  <method name="RequestGear">
    <arg name="gear" type="y" direction="in"/>
    <arg name="source" type="s" direction="in"/>
  </method>
  <signal name="GearChanged">
    <arg name="gear" type="y"/>
    <arg name="source" type="s"/>
    <arg name="timestamp" type="u"/>
  </signal>
</interface>
```

---

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Push** to the branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

### Coding Standards

- **C++**: Follow Qt coding conventions
- **QML**: Use declarative style, avoid imperative JavaScript
- **Python**: PEP 8 compliance
- **BitBake**: Use 4-space indentation, document all variables

### Commit Messages

Use conventional commits format:

```
type(scope): subject

body

footer
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Example**:
```
feat(headunit): add navigation screen

- Implement OSM map integration
- Add route calculation
- Update UI components

Closes #123
```

### Testing

Before submitting a PR:

```bash
# Yocto: Parse all recipes
bitbake -k -c parse_all

# Qt: Run unit tests
cd build-headunit
ctest --output-on-failure

# Cluster: Check build
cd DES_Instrument-Cluster/Cluster-app/build
make && ./appIC --test
```

### Code Review

All submissions require:
- Passing CI checks
- At least one approving review
- No unresolved conversations
- Updated documentation (if applicable)

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](./LICENSE) file for details.

### Third-Party Components

- **Qt 6**: LGPL v3 / Commercial
- **Yocto Project**: Mixed (GPL, MIT, BSD)
- **Linux Kernel**: GPL v2
- **systemd**: LGPL v2.1+
- **Wayland/Weston**: MIT
- **PulseAudio**: LGPL v2.1+
- **BlueZ**: GPL v2

---

## 👥 Authors & Acknowledgments
- [jojeongmin304](https://github.com/jojeongmin304)
- [Ju-Daeng-E](https://github.com/Ju-Daeng-E)

---

*For questions or support, open an issue in this repository.*
---

## 🗺️ Roadmap

### Current Version (v1.0)
- ✅ Dual display Wayland support
- ✅ Qt 6 Head-Unit with navigation, media, climate
- ✅ Instrument cluster with CAN integration
- ✅ Full Yocto build system
- ✅ systemd service orchestration

### Upcoming (v1.1)
- 🔄 OTA (Over-The-Air) update system
- 🔄 Voice control integration
- 🔄 Android Auto / CarPlay mirroring
- 🔄 Advanced driver assistance display

### Future
- 📋 Multi-language support
- 📋 Plugin architecture for 3rd-party apps
- 📋 Cloud connectivity for telemetry
- 📋 AI-powered predictive features

---

## 📊 Project Statistics

![Language Distribution](https://img.shields.io/github/languages/top/jojeongmin304/DES_Head-Unit)
![Code Size](https://img.shields.io/github/languages/code-size/jojeongmin304/DES_Head-Unit)
![Contributors](https://img.shields.io/github/contributors/jojeongmin304/DES_Head-Unit)
![Last Commit](https://img.shields.io/github/last-commit/jojeongmin304/DES_Head-Unit)

**Build Time**: ~4-8 hours (first build), ~30 minutes (incremental)
**Image Size**: ~2GB (compressed ~500MB)
**Boot Time**: ~30 seconds (from power-on to UI ready)
**Memory Usage**: ~600MB (idle), ~1.2GB (active media playback)

---

<div align="center">

**Built with ❤️ for the embedded Linux community**

[⬆ Back to Top](#des-head-unit)

</div>
