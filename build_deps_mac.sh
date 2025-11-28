#!/bin/bash
#
# NetMD Wizard - macOS Dependency Builder
# Downloads and builds all required libraries from source
#
# Usage:
#   ./build_deps_mac.sh          # Build all libraries
#   ./build_deps_mac.sh clean    # Clean build directories
#   ./build_deps_mac.sh libcdio  # Build only libcdio
#
# Libraries built:
#   - libcdio (CD reading)
#   - libcdio-paranoia (CD audio extraction)
#   - taglib (audio metadata)
#   - libsndfile (audio file I/O)
#   - netmd++ (NetMD device communication)
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build_deps"
INSTALL_PREFIX="${SCRIPT_DIR}/prebuilt/mac_new"
SRC_DIR="${BUILD_DIR}/src"
NUM_JOBS=$(sysctl -n hw.ncpu)

# Library versions (update these to change versions)
LIBCDIO_VERSION="2.2.0"
LIBCDIO_PARANOIA_VERSION="10.2+2.0.2"
TAGLIB_VERSION="2.0.2"  # Using 2.x; API mostly compatible, better CMake support
LIBSNDFILE_VERSION="1.2.2"
NETMDPP_REPO="https://github.com/Jo2003/netmd_plusplus.git"
NETMDPP_BRANCH="main"
# Pin to commit before native mono upload removed enablePcm2Mono/disablePcm2Mono methods
NETMDPP_COMMIT="2073b82"

# Download URLs
LIBCDIO_URL="https://github.com/libcdio/libcdio/releases/download/${LIBCDIO_VERSION}/libcdio-${LIBCDIO_VERSION}.tar.bz2"
LIBCDIO_PARANOIA_URL="https://github.com/libcdio/libcdio-paranoia/releases/download/release-${LIBCDIO_PARANOIA_VERSION}/libcdio-paranoia-${LIBCDIO_PARANOIA_VERSION}.tar.bz2"
TAGLIB_URL="https://taglib.org/releases/taglib-${TAGLIB_VERSION}.tar.gz"
LIBSNDFILE_URL="https://github.com/libsndfile/libsndfile/releases/download/${LIBSNDFILE_VERSION}/libsndfile-${LIBSNDFILE_VERSION}.tar.xz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for required tools
check_dependencies() {
    log_info "Checking build dependencies..."
    
    local missing=()
    
    command -v cmake >/dev/null 2>&1 || missing+=("cmake")
    command -v autoconf >/dev/null 2>&1 || missing+=("autoconf")
    command -v automake >/dev/null 2>&1 || missing+=("automake")
    command -v libtool >/dev/null 2>&1 || missing+=("libtool")
    command -v pkg-config >/dev/null 2>&1 || missing+=("pkg-config")
    command -v git >/dev/null 2>&1 || missing+=("git")
    
    # Check for libusb and libgcrypt (needed for netmd++)
    if ! pkg-config --exists libusb-1.0 2>/dev/null; then
        missing+=("libusb")
    fi
    
    if ! pkg-config --exists libgcrypt 2>/dev/null; then
        # libgcrypt doesn't always have pkg-config, check for libgcrypt-config
        if ! command -v libgcrypt-config >/dev/null 2>&1; then
            missing+=("libgcrypt")
        fi
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install with Homebrew:"
        echo "  brew install ${missing[*]}"
        echo ""
        exit 1
    fi
    
    log_success "All build dependencies found"
}

# Create directories
setup_directories() {
    log_info "Setting up build directories..."
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${SRC_DIR}"
    mkdir -p "${INSTALL_PREFIX}/lib/pkgconfig"
    mkdir -p "${INSTALL_PREFIX}/include"
    mkdir -p "${INSTALL_PREFIX}/bin"
}

# Download and extract a tarball
download_and_extract() {
    local url="$1"
    local filename="$2"
    local extract_dir="$3"
    
    cd "${SRC_DIR}"
    
    if [ ! -f "${filename}" ]; then
        log_info "Downloading ${filename}..."
        curl -L -o "${filename}" "${url}"
    else
        log_info "Using cached ${filename}"
    fi
    
    if [ ! -d "${extract_dir}" ]; then
        log_info "Extracting ${filename}..."
        case "${filename}" in
            *.tar.bz2)
                tar -xjf "${filename}"
                ;;
            *.tar.gz)
                tar -xzf "${filename}"
                ;;
            *.tar.xz)
                tar -xJf "${filename}"
                ;;
        esac
    fi
}

# Build libcdio
build_libcdio() {
    log_info "Building libcdio ${LIBCDIO_VERSION}..."
    
    download_and_extract "${LIBCDIO_URL}" "libcdio-${LIBCDIO_VERSION}.tar.bz2" "libcdio-${LIBCDIO_VERSION}"
    
    cd "${SRC_DIR}/libcdio-${LIBCDIO_VERSION}"
    
    # Configure and build
    ./configure \
        --prefix="${INSTALL_PREFIX}" \
        --disable-shared \
        --enable-static \
        --disable-dependency-tracking \
        --without-cd-drive \
        --without-cd-info \
        --without-cdda-player \
        --without-cd-read \
        --without-iso-info \
        --without-iso-read
    
    make -j${NUM_JOBS}
    make install
    
    log_success "libcdio ${LIBCDIO_VERSION} installed"
}

# Build libcdio-paranoia
build_libcdio_paranoia() {
    log_info "Building libcdio-paranoia ${LIBCDIO_PARANOIA_VERSION}..."
    
    download_and_extract "${LIBCDIO_PARANOIA_URL}" "libcdio-paranoia-${LIBCDIO_PARANOIA_VERSION}.tar.bz2" "libcdio-paranoia-${LIBCDIO_PARANOIA_VERSION}"
    
    cd "${SRC_DIR}/libcdio-paranoia-${LIBCDIO_PARANOIA_VERSION}"
    
    # Need to find libcdio we just built
    export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
    
    ./configure \
        --prefix="${INSTALL_PREFIX}" \
        --disable-shared \
        --enable-static \
        --disable-dependency-tracking
    
    make -j${NUM_JOBS}
    make install
    
    log_success "libcdio-paranoia ${LIBCDIO_PARANOIA_VERSION} installed"
}

# Build TagLib
build_taglib() {
    log_info "Building TagLib ${TAGLIB_VERSION}..."
    
    download_and_extract "${TAGLIB_URL}" "taglib-${TAGLIB_VERSION}.tar.gz" "taglib-${TAGLIB_VERSION}"
    
    cd "${SRC_DIR}/taglib-${TAGLIB_VERSION}"
    
    mkdir -p build && cd build
    
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DWITH_ZLIB=ON
    
    make -j${NUM_JOBS}
    make install
    
    log_success "TagLib ${TAGLIB_VERSION} installed"
}

# Build libsndfile
build_libsndfile() {
    log_info "Building libsndfile ${LIBSNDFILE_VERSION}..."
    
    download_and_extract "${LIBSNDFILE_URL}" "libsndfile-${LIBSNDFILE_VERSION}.tar.xz" "libsndfile-${LIBSNDFILE_VERSION}"
    
    cd "${SRC_DIR}/libsndfile-${LIBSNDFILE_VERSION}"
    
    mkdir -p build && cd build
    
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_PROGRAMS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_TESTING=OFF \
        -DENABLE_EXTERNAL_LIBS=OFF
    
    make -j${NUM_JOBS}
    make install
    
    log_success "libsndfile ${LIBSNDFILE_VERSION} installed"
}

# Build netmd++
build_netmdpp() {
    log_info "Building netmd++ from git..."
    
    cd "${SRC_DIR}"
    
    if [ ! -d "netmd_plusplus" ]; then
        git clone "${NETMDPP_REPO}" netmd_plusplus
    else
        cd netmd_plusplus
        git fetch origin
        cd ..
    fi
    
    cd netmd_plusplus
    
    # Checkout specific commit if specified (pinned for API compatibility)
    if [ -n "${NETMDPP_COMMIT:-}" ]; then
        log_info "Checking out pinned commit: ${NETMDPP_COMMIT}"
        git checkout "${NETMDPP_COMMIT}"
    else
        git checkout "${NETMDPP_BRANCH}"
        git pull origin "${NETMDPP_BRANCH}"
    fi
    
    # Get library paths from Homebrew
    LIBUSB_PREFIX=$(brew --prefix libusb 2>/dev/null || echo "/opt/homebrew/opt/libusb")
    LIBGCRYPT_PREFIX=$(brew --prefix libgcrypt 2>/dev/null || echo "/opt/homebrew/opt/libgcrypt")
    LIBGPGERR_PREFIX=$(brew --prefix libgpg-error 2>/dev/null || echo "/opt/homebrew/opt/libgpg-error")
    
    log_info "Using libusb from: ${LIBUSB_PREFIX}"
    log_info "Using libgcrypt from: ${LIBGCRYPT_PREFIX}"
    log_info "Using libgpg-error from: ${LIBGPGERR_PREFIX}"
    
    # Patch the CMakeLists.txt to use correct paths on Apple Silicon
    # The original hardcodes /usr/local which doesn't work on Apple Silicon
    INCLUDE_PATHS="${LIBUSB_PREFIX}/include ${LIBGCRYPT_PREFIX}/include ${LIBGPGERR_PREFIX}/include"
    LIB_PATHS="${LIBUSB_PREFIX}/lib ${LIBGCRYPT_PREFIX}/lib ${LIBGPGERR_PREFIX}/lib"
    
    sed -i '' "s|/usr/local/include|${INCLUDE_PATHS}|g" src/CMakeLists.txt
    sed -i '' "s|/usr/local/lib|${LIB_PATHS}|g" src/CMakeLists.txt
    
    # Disable test build - it has linker issues and we don't need it
    sed -i '' 's|add_subdirectory(test)|# add_subdirectory(test)|g' CMakeLists.txt
    
    rm -rf build
    mkdir -p build && cd build
    
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF
    
    make -j${NUM_JOBS}
    make install
    
    # Ensure the pkg-config file has correct paths
    sed -i '' "s|^prefix=.*|prefix=${INSTALL_PREFIX}|g" "${INSTALL_PREFIX}/lib/pkgconfig/libnetmd++.pc"
    
    log_success "netmd++ installed"
}

# Fix pkg-config files to use correct paths
fix_pkgconfig() {
    log_info "Fixing pkg-config files..."
    
    for pc in "${INSTALL_PREFIX}/lib/pkgconfig"/*.pc; do
        if [ -f "$pc" ]; then
            # Update prefix to use absolute path
            sed -i '' "s|^prefix=.*|prefix=${INSTALL_PREFIX}|g" "$pc"
        fi
    done
    
    log_success "pkg-config files updated"
}

# Print summary
print_summary() {
    echo ""
    echo "========================================"
    echo "           BUILD COMPLETE"
    echo "========================================"
    echo ""
    echo "Libraries installed to: ${INSTALL_PREFIX}"
    echo ""
    echo "Installed libraries:"
    ls -la "${INSTALL_PREFIX}/lib"/*.a 2>/dev/null || echo "  (none)"
    echo ""
    echo "pkg-config files:"
    ls "${INSTALL_PREFIX}/lib/pkgconfig"/*.pc 2>/dev/null || echo "  (none)"
    echo ""
    echo "To use these libraries, set:"
    echo "  export PKG_CONFIG_PATH=\"${INSTALL_PREFIX}/lib/pkgconfig:\$PKG_CONFIG_PATH\""
    echo ""
    echo "To replace the existing prebuilt libraries:"
    echo "  rm -rf ${SCRIPT_DIR}/prebuilt/mac"
    echo "  mv ${INSTALL_PREFIX} ${SCRIPT_DIR}/prebuilt/mac"
    echo ""
}

# Clean build directories
clean() {
    log_info "Cleaning build directories..."
    rm -rf "${BUILD_DIR}"
    rm -rf "${INSTALL_PREFIX}"
    log_success "Clean complete"
}

# Build a single library
build_single() {
    local lib="$1"
    
    setup_directories
    export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
    
    case "$lib" in
        libcdio)
            build_libcdio
            ;;
        libcdio-paranoia|paranoia)
            build_libcdio_paranoia
            ;;
        taglib)
            build_taglib
            ;;
        libsndfile|sndfile)
            build_libsndfile
            ;;
        netmd++|netmdpp|netmd)
            build_netmdpp
            ;;
        *)
            log_error "Unknown library: $lib"
            echo "Available: libcdio, libcdio-paranoia, taglib, libsndfile, netmd++"
            exit 1
            ;;
    esac
    
    fix_pkgconfig
}

# Build all libraries
build_all() {
    setup_directories
    
    # Set PKG_CONFIG_PATH for the entire build
    export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
    
    build_libcdio
    build_libcdio_paranoia
    build_taglib
    build_libsndfile
    build_netmdpp
    
    fix_pkgconfig
    print_summary
}

# Main entry point
main() {
    echo ""
    echo "========================================"
    echo "  NetMD Wizard - macOS Dependency Builder"
    echo "========================================"
    echo ""
    
    check_dependencies
    
    case "${1:-all}" in
        clean)
            clean
            ;;
        all)
            build_all
            ;;
        help|--help|-h)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  all              Build all libraries (default)"
            echo "  clean            Remove build directories"
            echo "  libcdio          Build only libcdio"
            echo "  libcdio-paranoia Build only libcdio-paranoia"
            echo "  taglib           Build only taglib"
            echo "  libsndfile       Build only libsndfile"
            echo "  netmd++          Build only netmd++"
            echo ""
            echo "Library versions:"
            echo "  libcdio:          ${LIBCDIO_VERSION}"
            echo "  libcdio-paranoia: ${LIBCDIO_PARANOIA_VERSION}"
            echo "  taglib:           ${TAGLIB_VERSION}"
            echo "  libsndfile:       ${LIBSNDFILE_VERSION}"
            echo "  netmd++:          git (${NETMDPP_BRANCH})"
            echo ""
            ;;
        *)
            build_single "$1"
            ;;
    esac
}

main "$@"
