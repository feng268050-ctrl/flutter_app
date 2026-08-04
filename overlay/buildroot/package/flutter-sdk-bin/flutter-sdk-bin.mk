################################################################################
#
# host-flutter-sdk-bin (lws-hmi overlay)
#
################################################################################

# Host SDK for `make build-flutter-engine` (compile path). Not used by build-rootfs.
FLUTTER_SDK_BIN_VERSION = 3.41.9


LWS_HMI_ROOT ?= $(TOPDIR)/../..
FLUTTER_SDK_BIN_LINKED = $(LWS_HMI_ROOT)/flutter-sdk
# Linux x86_64 SDK for Buildroot host package (Docker on macOS uses this path).
FLUTTER_SDK_BIN_CACHE = $(LWS_HMI_ROOT)/.cache/flutter-sdk/install-linux
ifeq ($(wildcard $(FLUTTER_SDK_BIN_CACHE)/.lws-precache-done),)
FLUTTER_SDK_BIN_SITE = $(FLUTTER_SDK_BIN_LINKED)
else
FLUTTER_SDK_BIN_SITE = $(FLUTTER_SDK_BIN_CACHE)
endif
FLUTTER_SDK_BIN_SITE_METHOD = local
FLUTTER_SDK_BIN_LICENSE = BSD-3-Clause
FLUTTER_SDK_BIN_LICENSE_FILES = LICENSE

HOST_FLUTTER_SDK_BIN_SDK = $(HOST_DIR)/share/flutter/sdk
HOST_FLUTTER_SDK_BIN_DART_SDK = $(HOST_FLUTTER_SDK_BIN_SDK)/bin/cache/dart-sdk
HOST_FLUTTER_SDK_BIN_SDK_ENGINE = $(HOST_FLUTTER_SDK_BIN_SDK)/bin/cache/artifacts/engine

HOST_FLUTTER_SDK_BIN_ENV = \
	HOME=$(HOST_FLUTTER_SDK_BIN_SDK) \
	PATH=$(BR_PATH):$(HOST_FLUTTER_SDK_BIN_SDK):$(HOST_FLUTTER_SDK_BIN_SDK)/bin \
	PUB_CACHE=$(FLUTTER_SDK_BIN_PUB_CACHE)

HOST_FLUTTER_SDK_BIN_CONF_OPTS = \
	--clear-features \
	--no-analytics \
	--disable-analytics \
	--enable-custom-devices \
	--enable-linux-desktop \
	--no-enable-android \
	--no-enable-fuchsia \
	--no-enable-ios \
	--no-enable-macos-desktop \
	--no-enable-windows-desktop

define HOST_FLUTTER_SDK_BIN_ENSURE_LOCAL_TREE
	if [ ! -f "$(FLUTTER_SDK_BIN_SITE)/.lws-precache-done" ]; then \
		printf 'host-flutter-sdk-bin %s: missing %s\n' \
			"$(FLUTTER_SDK_BIN_VERSION)" "$(FLUTTER_SDK_BIN_SITE)" 1>&2; \
		printf 'Run from lws-hmi repo: make fetch-flutter-sdk\n' 1>&2; \
		exit 1; \
	fi
endef
HOST_FLUTTER_SDK_BIN_POST_RSYNC_HOOKS += HOST_FLUTTER_SDK_BIN_ENSURE_LOCAL_TREE

define HOST_FLUTTER_SDK_BIN_CONFIGURE_CMDS
	# Install-only: tree comes from make fetch-flutter-sdk (tarball + precache, not a git clone).
	# flutter config here fails with "not a clone of the GitHub project".
	:
endef

define HOST_FLUTTER_SDK_BIN_BUILD_CMDS
	mkdir -p $(HOST_FLUTTER_SDK_BIN_SDK)
endef

define HOST_FLUTTER_SDK_BIN_INSTALL_CMDS
	cp -rpdT $(@D)/. $(HOST_FLUTTER_SDK_BIN_SDK)/
endef

ifeq ($(FLUTTER_ENGINE_RUNTIME_MODE_PROFILE),y)
HOST_FLUTTER_SDK_BIN_PROFILE_FLAGS = --track-widget-creation
HOST_FLUTTER_SDK_BIN_SDK_PRODUCT = false
HOST_FLUTTER_SDK_BIN_SDK_ROOT = $(HOST_FLUTTER_SDK_BIN_SDK_ENGINE)/common/flutter_patched_sdk
HOST_FLUTTER_SDK_BIN_SDK_VM_PROFILE = true
else ifeq ($(BR2_ENABLE_RUNTIME_DEBUG),y)
HOST_FLUTTER_SDK_BIN_DEBUG_FLAGS = --enable-asserts
HOST_FLUTTER_SDK_BIN_SDK_PRODUCT = false
HOST_FLUTTER_SDK_BIN_SDK_ROOT = $(HOST_FLUTTER_SDK_BIN_SDK_ENGINE)/common/flutter_patched_sdk
HOST_FLUTTER_SDK_BIN_SDK_VM_PROFILE = false
else
HOST_FLUTTER_SDK_BIN_SDK_PRODUCT = true
HOST_FLUTTER_SDK_BIN_SDK_ROOT = $(HOST_FLUTTER_SDK_BIN_SDK_ENGINE)/common/flutter_patched_sdk_product
HOST_FLUTTER_SDK_BIN_SDK_VM_PROFILE = false
endif

HOST_FLUTTER_SDK_BIN_DART_ARGS = \
	--verbose \
	--disable-analytics \
	--disable-dart-dev $(HOST_FLUTTER_SDK_BIN_SDK_ENGINE)/linux-x64/frontend_server_aot.dart.snapshot \
	--sdk-root $(HOST_FLUTTER_SDK_BIN_SDK_ROOT) \
	--target=flutter \
	--no-print-incremental-dependencies \
	-Ddart.vm.profile=$(HOST_FLUTTER_SDK_BIN_SDK_VM_PROFILE) \
	-Ddart.vm.product=$(HOST_FLUTTER_SDK_BIN_SDK_PRODUCT) \
	$(HOST_FLUTTER_SDK_BIN_DEBUG_FLAGS) \
	$(HOST_FLUTTER_SDK_BIN_PROFILE_FLAGS) \
	--aot \
	--tfa \
	--target-os linux \
	--packages .dart_tool/package_config.json \
	--output-dill .dart_tool/flutter_build/*/app.dill \
	--depfile .dart_tool/flutter_build/*/kernel_snapshot_program.d

HOST_FLUTTER_SDK_BIN_FLUTTER = \
	$(HOST_FLUTTER_SDK_BIN_ENV) \
	$(HOST_FLUTTER_SDK_BIN_SDK)/bin/flutter

HOST_FLUTTER_SDK_BIN_DART_BIN = \
	$(HOST_FLUTTER_SDK_BIN_ENV) \
	$(HOST_FLUTTER_SDK_BIN_DART_SDK)/bin/dartaotruntime \
	$(HOST_FLUTTER_SDK_BIN_DART_ARGS)

$(eval $(host-generic-package))

FLUTTER_SDK_BIN_PUB_CACHE = $(DL_DIR)/br-flutter-pub-cache
