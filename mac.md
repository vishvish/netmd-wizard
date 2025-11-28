## Overview

**NetMD Wizard** is a Qt-based C++ application for transferring audio from CDs to Sony NetMD MiniDisc devices. It's similar to Sony's NetMD Simple Burner.

---

## Build System

The project supports two build systems:
1. **qmake** (via cd2netmd_gui.pro) - **Recommended for macOS**
2. **CMake** (via CMakeLists.txt) - Primarily for Linux

---

## Dependencies

### Required System Libraries (install via Homebrew)

```bash
brew install qt@5
brew install libusb
brew install libgcrypt
brew install pkg-config
```

### Prebuilt Libraries (already included)

The repo includes prebuilt static libraries in mac:
- `libcdio` - CD reading library
- `libcdio_cdda` / `libcdio_paranoia` - CD audio extraction with error correction
- `libiso9660` / `libudf` - ISO/UDF filesystem support
- `libnetmd++` - NetMD device communication
- `taglib` - Audio metadata/tag reading
- Various audio codecs (FLAC, Vorbis, Opus, sndfile)

### Bundled Tools

- ffmpeg - Audio transcoding
- atracdenc - ATRAC encoder for LP modes

---

## Building on macOS

### Step 1: Fix pkg-config Paths

The prebuilt `.pc` files have hardcoded paths from the original developer's machine (`/Users/joergn/src/cd2netmd_gui`). You need to patch them:

```bash
cd /Users/vish/git/software/netmd-wizard
TMP=/tmp/08-15.pc
D=$(pwd)
for pc in prebuilt/mac/lib/pkgconfig/*.pc; do
    sed "s|/Users/joergn/src/cd2netmd_gui|${D}|g" "$pc" > ${TMP} && cp ${TMP} "$pc"
done
```

### Step 2: Set Environment Variables

```bash
export PKG_CONFIG_PATH=/Users/vish/git/software/netmd-wizard/prebuilt/mac/lib/pkgconfig
export PATH="/opt/homebrew/opt/qt@5/bin:$PATH"  # or /usr/local/opt/qt@5/bin on Intel Mac
```

### Step 3: Generate Version Header

```bash
./upd_git_version.sh
```

### Step 4: Build with qmake

```bash
mkdir -p build && cd build
qmake ../cd2netmd_gui.pro CONFIG+=release
make -j$(sysctl -n hw.ncpu)
```

The executable will be in `release/netmd_wizard`.

---

## Creating the macOS App Bundle

After building, you can create a proper `.app` bundle:

```bash
./create_mac_bundle.sh release
```

**Note:** The script references `/Users/joergn/Qt5.12.12/...` for Qt translations - you'll need to update this path to your Qt installation.

---

## Key Technical Notes

1. **macOS-specific code**: The project uses cdrutil.cpp/cdrutil.h on macOS because `libcdio` doesn't support CD-Text on Mac. It uses macOS's `drutil` command instead.

2. **Minimum macOS version**: 10.13 (High Sierra)

3. **Qt version**: Qt 5 is required (tested with 5.12.x)

4. **USB access**: You need a NetMD-compatible MiniDisc device connected via USB

---

## Running the Application

After building:

```bash
./release/netmd_wizard
```

Or if you created the app bundle:

```bash
open "release/netmd_wizard_mac_<version>/NetMD Wizard.app"
```

---

## Quick Build Commands Summary

```bash
# Install dependencies
brew install qt@5 libusb libgcrypt pkg-config

# Set up environment
cd /Users/vish/git/software/netmd-wizard
export PKG_CONFIG_PATH=$(pwd)/prebuilt/mac/lib/pkgconfig
export PATH="/opt/homebrew/opt/qt@5/bin:$PATH"

# Fix pkg-config paths
for pc in prebuilt/mac/lib/pkgconfig/*.pc; do
    sed -i '' "s|/Users/joergn/src/cd2netmd_gui|$(pwd)|g" "$pc"
done

# Generate version header
./upd_git_version.sh

# Build
mkdir -p build && cd build
qmake ../cd2netmd_gui.pro CONFIG+=release
make -j$(sysctl -n hw.ncpu)

# Run
./release/netmd_wizard
```