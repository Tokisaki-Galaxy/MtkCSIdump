# MtkCSIdump — GitHub Copilot Agent Instructions

## Project Overview

**MtkCSIdump** is a user-space tool and accompanying OpenWrt firmware build for
dumping Channel State Information (CSI) from MediaTek Wi-Fi chipsets (mt76 driver
family). It uses the nl80211 vendor command interface to extract CSI data from the
kernel driver, then streams the data via UDP to a visualisation client.

### Key release artifacts
| Artifact | Description |
|---|---|
| `CSIdump` | statically-linked aarch64 binary (user-space tool) |
| `mt76.ko`, `mt76-connac-lib.ko`, `mt7915e.ko`, … | patched mt76 kernel modules with CSI vendor-command support |
| `openwrt-mediatek-filogic-openwrt_one-squashfs-sysupgrade.itb` | full OpenWrt firmware image for OpenWRT One |
| `openwrt-mediatek-filogic-xiaomi_mi-router-ax3000t-squashfs-sysupgrade.bin` | full OpenWrt firmware image for Xiaomi AX3000T |

---

## Repository Structure

```
MtkCSIdump/
├── CMakeLists.txt                  # CMake build (cross-compile to aarch64)
├── toolchain-aarch64-openwrt.cmake # CMake toolchain file for OpenWrt SDK
├── main.cpp                        # Entry point (signal handling, UDP server)
├── motion_detector.{cpp,h}         # Core CSI collection and motion-detection logic
├── md.{cpp,h}                      # Motion-detection helpers
├── parsers/
│   ├── parser.h                    # Base parser interface
│   ├── parser_mt76.{cpp,h}         # mt76-specific CSI data parser
│   └── …
├── wifi_drv_api/
│   ├── mt76_api.{cpp,h}            # nl80211 / netlink interface to mt76 driver
│   └── …
├── csi_udp_client_gui.py           # Python UDP client + visualisation GUI
├── requirements.txt                # Python dependencies (PyQt / Matplotlib)
├── install_deps.sh                 # Helper to install Python dependencies
└── .github/
    ├── copilot-instructions.md     # ← You are here
    └── workflows/
        ├── build.yml               # Main CI/CD workflow
        └── copilot-setup-steps.yml # Copilot environment setup
```

---

## Build Environment

### Pre-installed tools (Copilot agent environment)

| Tool | Purpose |
|---|---|
| `cmake` + `ninja-build` | Build system for CSIdump |
| `aarch64-openwrt-linux-g++` | Cross-compiler (from OpenWrt SDK in `$SDK_DIR`) |
| `libnl-tiny.a` | Static netlink library for nl80211 (built by SDK) |
| OpenWrt SDK (`$SDK_DIR`) | Provides toolchain + kernel headers for module builds |
| OpenWrt ImageBuilder | Produces sysupgrade firmware images |
| `tree`, `jq`, `ripgrep` | General utilities |
| Python 3 + pip | For the GUI client |

### Key environment variables

```bash
OPENWRT_CC      # path to aarch64-openwrt-linux-gcc
OPENWRT_CXX     # path to aarch64-openwrt-linux-g++
OPENWRT_SYSROOT # path to SDK staging_dir/target-aarch64_cortex-a53_musl
LIBNL_TINY_PATH    # path to libnl-tiny.a parent directory
LIBNL_TINY_INCLUDE # path to libnl-tiny headers directory
SDK_DIR         # root of the extracted OpenWrt SDK
```

---

## How to Build CSIdump

### In CI (GitHub Actions)
The workflow `.github/workflows/build.yml` handles everything automatically:
- Downloads the OpenWrt SDK
- Builds libnl-tiny as a static library via the SDK package system
- Cross-compiles CSIdump with the SDK's aarch64 cross-compiler

### Locally (with OpenWrt SDK)
```bash
# 1. Set environment variables pointing to your SDK
export SDK_DIR=/path/to/openwrt-sdk-*-mediatek-filogic*/
export TC_DIR=$(ls -d ${SDK_DIR}/staging_dir/toolchain-aarch64_cortex-a53_*)
export TARGET_DIR=$(ls -d ${SDK_DIR}/staging_dir/target-aarch64_cortex-a53_musl)
export OPENWRT_CC="${TC_DIR}/bin/aarch64-openwrt-linux-gcc"
export OPENWRT_CXX="${TC_DIR}/bin/aarch64-openwrt-linux-g++"
export OPENWRT_SYSROOT="${TARGET_DIR}"

# 2. Build libnl-tiny in the SDK (if not already built)
cd "${SDK_DIR}"
make package/libs/libnl-tiny/compile CONFIG_PACKAGE_libnl-tiny=y -j$(nproc)
cd -

# 3. Configure and build CSIdump
cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE=toolchain-aarch64-openwrt.cmake \
  -DLIBNL_TINY_PATH="${TARGET_DIR}/usr/lib" \
  -DLIBNL_TINY_INCLUDE="${TARGET_DIR}/usr/include/libnl-tiny"
cmake --build build -j$(nproc)

# 4. Verify the binary
file build/CSIdump
# → build/CSIdump: ELF 64-bit LSB executable, ARM aarch64, …, statically linked
```

### CMake variables reference

| Variable | Default | Description |
|---|---|---|
| `CMAKE_CXX_COMPILER` | (must be set) | aarch64 cross-compiler |
| `CMAKE_TOOLCHAIN_FILE` | (none) | Path to `toolchain-aarch64-openwrt.cmake` |
| `LIBNL_TINY_PATH` | `/data/mediatek/…/usr/local/lib/` | Directory containing `libnl-tiny.a` |
| `LIBNL_TINY_INCLUDE` | `/data/mediatek/…/usr/local/include/libnl-tiny/` | libnl-tiny headers directory |

---

## How to Build OpenWrt Kernel Modules

The mt76 kernel modules are built via the OpenWrt SDK package system:

```bash
cd "${SDK_DIR}"

# Update package feeds
./scripts/feeds update -a && ./scripts/feeds install -a

# Build mt76 kernel module packages
make package/kernel/mt76/compile \
  CONFIG_PACKAGE_kmod-mt76=y \
  CONFIG_PACKAGE_kmod-mt76-connac-lib=y \
  CONFIG_PACKAGE_kmod-mt7915e=y \
  -j$(nproc) V=s

# Locate the compiled .ko files
find build_dir -name "*.ko" | grep mt76
```

---

## How to Build OpenWrt Sysupgrade Images

The firmware images are built with the OpenWrt ImageBuilder:

```bash
# Download ImageBuilder
IB_URL="https://downloads.openwrt.org/releases/24.10.1/targets/mediatek/filogic/openwrt-imagebuilder-24.10.1-mediatek-filogic.Linux-x86_64.tar.xz"
wget "${IB_URL}" -O ib.tar.xz && tar xf ib.tar.xz

cd openwrt-imagebuilder-*/

# Build for OpenWRT One
make image \
  PROFILE=openwrt_one \
  PACKAGES="kmod-mt76 kmod-mt76-connac-lib kmod-mt7915e kmod-mt7916-firmware"

# Build for Xiaomi AX3000T
make image \
  PROFILE=xiaomi_mi-router-ax3000t \
  PACKAGES="kmod-mt76 kmod-mt76-connac-lib kmod-mt7915e kmod-mt7916-firmware"
```

---

## How to Run the Python GUI Client

```bash
# Install Python dependencies
pip3 install -r requirements.txt
# OR
./install_deps.sh

# Run the visualisation GUI
python3 csi_udp_client_gui.py <udp_port>
# Example:
python3 csi_udp_client_gui.py 8888
```

On the OpenWrt device side, run:
```sh
# Start CSI collection and stream to port 8888 on the client machine
./CSIdump wlan1 100 8888
```

---

## Release Workflow

Releases are created automatically when a git tag starting with `v` is pushed:

```bash
git tag -a v0.2 -m "Release v0.2"
git push origin v0.2
```

This triggers `.github/workflows/build.yml` which:
1. Cross-compiles the `CSIdump` binary
2. Builds mt76 kernel modules via the OpenWrt SDK
3. Builds sysupgrade images via the OpenWrt ImageBuilder
4. Creates a GitHub Release with all artifacts attached

---

## Code Style and Conventions

- **Language**: C++17 (source), Python 3 (GUI client)
- **Cross-compilation**: aarch64-openwrt-linux-musl (statically linked)
- **Build system**: CMake ≥ 3.1
- **Kernel interface**: nl80211 vendor commands via libnl-tiny / libunl
- No automated tests exist; verify changes by deploying to an OpenWrt device

## Common Issues

| Symptom | Likely cause | Fix |
|---|---|---|
| `libnl-tiny.a not found` | SDK not built with libnl-tiny | Run `make package/libs/libnl-tiny/compile` in SDK |
| `cannot find -lnl-tiny` | Wrong `LIBNL_TINY_PATH` | Check path to `libnl-tiny.a` and pass via `-DLIBNL_TINY_PATH=…` |
| cmake picks wrong compiler | Toolchain not set | Always pass `-DCMAKE_TOOLCHAIN_FILE=toolchain-aarch64-openwrt.cmake` |
| `Exec format error` at runtime | Binary not for aarch64 | Run `file CSIdump` — must show `ARM aarch64` |
| ImageBuilder `unknown profile` | Wrong profile name | Run `make info` in ImageBuilder dir to list valid profiles |
