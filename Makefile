# NetMD Wizard - macOS Build System
#
# Usage:
#   make deps          - Build all dependencies from source
#   make deps-clean    - Clean dependency build directories
#   make build         - Build NetMD Wizard (after deps or using prebuilt)
#   make clean         - Clean NetMD Wizard build
#   make all           - Build deps + app
#   make run           - Run the application
#   make bundle        - Create .app bundle
#
# Individual libraries:
#   make libcdio
#   make libcdio-paranoia
#   make taglib
#   make libsndfile
#   make netmd++
#

SHELL := /bin/bash
.PHONY: all deps deps-clean build clean run bundle help libcdio libcdio-paranoia taglib libsndfile netmd++

# Directories
ROOT_DIR := $(shell pwd)
BUILD_DIR := $(ROOT_DIR)/build
RELEASE_DIR := $(ROOT_DIR)/release
PREBUILT_DIR := $(ROOT_DIR)/prebuilt/mac
NEW_PREBUILT_DIR := $(ROOT_DIR)/prebuilt/mac_new

# Qt configuration - try to find Qt5 automatically
QT5_PATH := $(shell brew --prefix qt@5 2>/dev/null || echo "/usr/local/opt/qt@5")
QMAKE := $(QT5_PATH)/bin/qmake

# Number of parallel jobs
JOBS := $(shell sysctl -n hw.ncpu)

# Default target
all: deps build

#
# Help
#
help:
	@echo ""
	@echo "NetMD Wizard - macOS Build System"
	@echo "=================================="
	@echo ""
	@echo "Dependency management:"
	@echo "  make deps            Build all dependencies from source"
	@echo "  make deps-clean      Clean dependency build directories"
	@echo "  make deps-info       Show versions of dependencies"
	@echo ""
	@echo "Individual libraries (builds to prebuilt/mac_new):"
	@echo "  make libcdio"
	@echo "  make libcdio-paranoia"
	@echo "  make taglib"
	@echo "  make libsndfile"
	@echo "  make netmd++"
	@echo ""
	@echo "Application build:"
	@echo "  make build           Build NetMD Wizard"
	@echo "  make clean           Clean build directories"
	@echo "  make run             Run the application"
	@echo "  make bundle          Create .app bundle"
	@echo ""
	@echo "Combined:"
	@echo "  make all             Build deps + app"
	@echo "  make use-new-deps    Replace prebuilt libs with newly built ones"
	@echo ""

#
# Dependency building
#
deps:
	@./build_deps_mac.sh all

deps-clean:
	@./build_deps_mac.sh clean

deps-info:
	@./build_deps_mac.sh help | grep -A10 "Library versions:"

libcdio:
	@./build_deps_mac.sh libcdio

libcdio-paranoia:
	@./build_deps_mac.sh libcdio-paranoia

taglib:
	@./build_deps_mac.sh taglib

libsndfile:
	@./build_deps_mac.sh libsndfile

netmd++:
	@./build_deps_mac.sh netmd++

# Replace old prebuilt libs with new ones
use-new-deps:
	@if [ -d "$(NEW_PREBUILT_DIR)" ]; then \
		echo "Backing up old prebuilt libs to prebuilt/mac_old..."; \
		rm -rf $(ROOT_DIR)/prebuilt/mac_old; \
		mv $(PREBUILT_DIR) $(ROOT_DIR)/prebuilt/mac_old; \
		mv $(NEW_PREBUILT_DIR) $(PREBUILT_DIR); \
		echo "Done! New libraries are now in prebuilt/mac"; \
	else \
		echo "Error: No new dependencies found. Run 'make deps' first."; \
		exit 1; \
	fi

#
# Application build
#
setup-pkgconfig:
	@echo "Patching pkg-config files..."
	@for pc in $(PREBUILT_DIR)/lib/pkgconfig/*.pc; do \
		if [ -f "$$pc" ]; then \
			sed -i '' "s|/Users/joergn/src/cd2netmd_gui|$(ROOT_DIR)|g" "$$pc" 2>/dev/null || true; \
			sed -i '' "s|$(ROOT_DIR)/prebuilt/mac_new|$(ROOT_DIR)/prebuilt/mac|g" "$$pc" 2>/dev/null || true; \
		fi \
	done

git-version:
	@if [ ! -f git_version.h ]; then \
		./upd_git_version.sh || echo '#define GIT_VERSION "unknown"' > git_version.h; \
	fi

build: setup-pkgconfig git-version
	@echo "Building NetMD Wizard..."
	@mkdir -p $(BUILD_DIR)
	@cd $(BUILD_DIR) && \
		PKG_CONFIG_PATH="$(PREBUILT_DIR)/lib/pkgconfig:$$PKG_CONFIG_PATH" \
		$(QMAKE) ../cd2netmd_gui.pro CONFIG+=release CONFIG+=sdk_no_version_check && \
		make -j$(JOBS)
	@echo ""
	@echo "Build complete! Binary at: $(BUILD_DIR)/release/netmd_wizard"

clean:
	@echo "Cleaning build directories..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(RELEASE_DIR)/*.app
	@rm -rf $(RELEASE_DIR)/netmd_wizard_mac_*
	@echo "Clean complete"

run: build
	@echo "Running NetMD Wizard..."
	@open $(BUILD_DIR)/release/netmd_wizard.app

bundle: build
	@echo "Creating macOS app bundle..."
	@./create_mac_bundle.sh $(BUILD_DIR)
	@echo "Bundle created in: $(BUILD_DIR)/"

#
# Development helpers
#
check-tools:
	@echo "Checking required tools..."
	@command -v $(QMAKE) >/dev/null 2>&1 || (echo "Error: qmake not found. Install Qt5: brew install qt@5" && exit 1)
	@command -v cmake >/dev/null 2>&1 || (echo "Error: cmake not found. Install: brew install cmake" && exit 1)
	@command -v pkg-config >/dev/null 2>&1 || (echo "Error: pkg-config not found. Install: brew install pkg-config" && exit 1)
	@echo "All required tools found!"

show-config:
	@echo "Configuration:"
	@echo "  Qt5 Path:     $(QT5_PATH)"
	@echo "  qmake:        $(QMAKE)"
	@echo "  Build Dir:    $(BUILD_DIR)"
	@echo "  Prebuilt Dir: $(PREBUILT_DIR)"
	@echo "  Jobs:         $(JOBS)"
	@echo ""
	@echo "PKG_CONFIG_PATH would include:"
	@echo "  $(PREBUILT_DIR)/lib/pkgconfig"
