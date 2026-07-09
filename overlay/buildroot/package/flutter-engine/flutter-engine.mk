################################################################################
#
# flutter-engine (lws-hmi overlay)
#
################################################################################

# Sources: .cache/flutter-engine/ (make build-flutter-engine)
# Prebuilt: prebuilt/flutter-engine/<ver>/arm64-<mode>/ (make build-prebuilt)
#
# Bump FLUTTER_ENGINE_VERSION and overlay/buildroot/flutter-engine.version together,
# then: make rebuild-deps && make build-prebuilt (or build-rootfs once)
FLUTTER_ENGINE_VERSION = 3.24.4

FLUTTER_ENGINE_SITE =
FLUTTER_ENGINE_SOURCE =
FLUTTER_ENGINE_LICENSE = BSD-3-Clause
FLUTTER_ENGINE_LICENSE_FILES = LICENSE

LWS_HMI_ROOT ?= $(TOPDIR)/../..
FLUTTER_ENGINE_TARBALL_PATH = $(LWS_HMI_ROOT)/.cache/flutter-engine/flutter-$(FLUTTER_ENGINE_VERSION).tar.gz
FLUTTER_ENGINE_INSTALL_STAGING = YES

ifeq ($(BR2_aarch64),y)
FLUTTER_ENGINE_TARGET_ARCH = arm64
FLUTTER_ENGINE_TARGET_TRIPPLE = aarch64-unknown-linux-gnu
else ifeq ($(BR2_arm)$(BR2_armeb),y)
FLUTTER_ENGINE_TARGET_ARCH = arm
FLUTTER_ENGINE_TARGET_TRIPPLE = armv7-unknown-linux-gnueabihf
else ifeq ($(BR2_x86_64),y)
FLUTTER_ENGINE_TARGET_ARCH = x64
FLUTTER_ENGINE_TARGET_TRIPPLE = x86_64-unknown-linux-gnu
endif

ifeq ($(FLUTTER_ENGINE_RUNTIME_MODE_PROFILE),y)
FLUTTER_ENGINE_RUNTIME_MODE=profile
else ifeq ($(BR2_ENABLE_RUNTIME_DEBUG),y)
FLUTTER_ENGINE_RUNTIME_MODE=debug
else
FLUTTER_ENGINE_RUNTIME_MODE=release
endif

FLUTTER_ENGINE_PREBUILT_DIR = $(LWS_HMI_ROOT)/prebuilt/flutter-engine/$(FLUTTER_ENGINE_VERSION)/arm64-$(FLUTTER_ENGINE_RUNTIME_MODE)
ifneq ($(wildcard $(FLUTTER_ENGINE_PREBUILT_DIR)/.lws-prebuilt),)
FLUTTER_ENGINE_USE_PREBUILT = YES
endif

ifeq ($(FLUTTER_ENGINE_USE_PREBUILT),YES)
FLUTTER_ENGINE_DEPENDENCIES =
else
FLUTTER_ENGINE_DEPENDENCIES = \
	host-flutter-sdk-bin \
	host-ninja \
	host-pkgconf \
	freetype \
	zlib
endif

FLUTTER_ENGINE_BUILD_DIR = \
	$(@D)/out/linux_$(FLUTTER_ENGINE_RUNTIME_MODE)_$(FLUTTER_ENGINE_TARGET_ARCH)

FLUTTER_ENGINE_INSTALL_FILES = libflutter_engine.so

FLUTTER_ENGINE_CLANG_PATH = $(@D)/flutter/buildtools/linux-x64/clang

ifneq ($(FLUTTER_ENGINE_USE_PREBUILT),YES)
FLUTTER_ENGINE_CONF_OPTS = \
	--clang \
	--embedder-for-target \
	--linux-cpu $(FLUTTER_ENGINE_TARGET_ARCH) \
	--no-build-embedder-examples \
	--no-clang-static-analyzer \
	--no-enable-unittests \
	--no-goma \
	--no-prebuilt-dart-sdk \
	--no-stripped \
	--runtime-mode $(FLUTTER_ENGINE_RUNTIME_MODE) \
	--target-os linux \
	--target-sysroot $(STAGING_DIR) \
	--target-toolchain $(FLUTTER_ENGINE_CLANG_PATH) \
	--target-triple $(FLUTTER_ENGINE_TARGET_TRIPPLE)

ifeq ($(BR2_arm)$(BR2_armeb),y)
FLUTTER_ENGINE_CONF_OPTS += \
	--arm-float-abi $(call qstrip,$(BR2_GCC_TARGET_FLOAT_ABI))
endif

ifeq ($(BR2_CCACHE),y)
define FLUTTER_ENGINE_COMPILER_PATH_FIXUP
	$(SED) "s%cc =.*%cc = \"$(HOST_DIR)/bin/ccache $(FLUTTER_ENGINE_CLANG_PATH)/bin/clang\""%g \
		$(@D)/build/toolchain/custom/BUILD.gn

	$(SED) "s%cxx =.*%cxx = \"$(HOST_DIR)/bin/ccache $(FLUTTER_ENGINE_CLANG_PATH)/bin/clang++\""%g \
		$(@D)/build/toolchain/custom/BUILD.gn
endef
FLUTTER_ENGINE_PRE_CONFIGURE_HOOKS += FLUTTER_ENGINE_COMPILER_PATH_FIXUP
endif

ifeq ($(BR2_ENABLE_LTO),y)
FLUTTER_ENGINE_CONF_OPTS += --lto
else
FLUTTER_ENGINE_CONF_OPTS += --no-lto
endif

ifeq ($(BR2_OPTIMIZE_0),y)
FLUTTER_ENGINE_CONF_OPTS += --unoptimized
endif

ifeq ($(BR2_PACKAGE_FONTCONFIG),y)
FLUTTER_ENGINE_DEPENDENCIES += fontconfig
FLUTTER_ENGINE_CONF_OPTS += --enable-fontconfig
endif

ifeq ($(BR2_PACKAGE_HAS_LIBGL),y)
FLUTTER_ENGINE_DEPENDENCIES += libgl
endif

ifeq ($(BR2_PACKAGE_HAS_LIBGLES),y)
FLUTTER_ENGINE_DEPENDENCIES += libgles
FLUTTER_ENGINE_CONF_OPTS += --enable-impeller-3d
endif

ifeq ($(BR2_PACKAGE_LIBGLFW),y)
FLUTTER_ENGINE_DEPENDENCIES += libglfw
FLUTTER_ENGINE_CONF_OPTS += --build-glfw-shell
else
FLUTTER_ENGINE_CONF_OPTS += --no-build-glfw-shell
endif

ifeq ($(BR2_PACKAGE_LIBGTK3),y)
FLUTTER_ENGINE_DEPENDENCIES += libgtk3
FLUTTER_ENGINE_INSTALL_FILES += libflutter_linux_gtk.so
else
FLUTTER_ENGINE_CONF_OPTS += --disable-desktop-embeddings
endif

ifeq ($(BR2_PACKAGE_MESA3D_VULKAN_DRIVER),y)
FLUTTER_ENGINE_CONF_OPTS += --enable-vulkan --enable-impeller-vulkan
endif

ifeq ($(BR2_PACKAGE_XORG7)$(BR2_PACKAGE_LIBXCB),yy)
FLUTTER_ENGINE_DEPENDENCIES += libxcb
else
define FLUTTER_ENGINE_VULKAN_X11_SUPPORT_FIXUP
	$(SED) "s%vulkan_use_x11.*%vulkan_use_x11 = false%g" -i \
		$(@D)/flutter/build_overrides/vulkan_headers.gni

	$(SED) "s%ozone_platform_x11.*%ozone_platform_x11 = false%g" \
		$(@D)/build/config/BUILDCONFIG.gn
endef
FLUTTER_ENGINE_PRE_CONFIGURE_HOOKS += FLUTTER_ENGINE_VULKAN_X11_SUPPORT_FIXUP
endif

ifeq ($(BR2_PACKAGE_WAYLAND),y)
FLUTTER_ENGINE_DEPENDENCIES += wayland
else
define FLUTTER_ENGINE_VULKAN_WAYLAND_SUPPORT_FIXUP
	$(SED) "s%vulkan_use_wayland.*%vulkan_use_wayland = false%g" \
		$(@D)/flutter/build_overrides/vulkan_headers.gni

	$(SED) "s%ozone_platform_wayland.*%ozone_platform_wayland = false%g" \
		$(@D)/build/config/BUILDCONFIG.gn
endef
FLUTTER_ENGINE_PRE_CONFIGURE_HOOKS += FLUTTER_ENGINE_VULKAN_WAYLAND_SUPPORT_FIXUP
endif

define FLUTTER_ENGINE_ENSURE_LOCAL_TARBALL
	if [ ! -f "$(FLUTTER_ENGINE_TARBALL_PATH)" ]; then \
		printf 'flutter-engine %s: missing %s\n' \
			"$(FLUTTER_ENGINE_VERSION)" "$(FLUTTER_ENGINE_TARBALL_PATH)" 1>&2; \
		printf 'Run from lws-hmi repo: make build-flutter-engine\n' 1>&2; \
		exit 1; \
	fi
endef
FLUTTER_ENGINE_POST_DOWNLOAD_HOOKS += FLUTTER_ENGINE_ENSURE_LOCAL_TARBALL

define FLUTTER_ENGINE_EXTRACT_CMDS
	$(call suitable-extractor,$(FLUTTER_ENGINE_TARBALL_PATH)) $(FLUTTER_ENGINE_TARBALL_PATH) \
	| $(TAR) --strip-components=1 -C $(@D) $(TAR_OPTIONS) -
endef

define FLUTTER_ENGINE_CONFIGURE_CMDS
	cd $(@D) && \
		rm -rf $(FLUTTER_ENGINE_BUILD_DIR) && \
		PATH=$(HOST_DIR)/share/depot_tools:$(BR_PATH) \
		PUB_CACHE=$(FLUTTER_SDK_BIN_PUB_CACHE) \
		HOME=$(HOST_FLUTTER_SDK_BIN_SDK) \
		./flutter/tools/gn \
			$(FLUTTER_ENGINE_CONF_OPTS)
endef

define FLUTTER_ENGINE_BUILD_CMDS
	cd $(@D) && \
		PATH=$(HOST_DIR)/share/depot_tools:$(BR_PATH) \
		PUB_CACHE=$(FLUTTER_SDK_BIN_PUB_CACHE) \
		HOME=$(HOST_FLUTTER_SDK_BIN_SDK) \
		$(HOST_DIR)/bin/ninja \
			-j $(PARALLEL_JOBS) \
			-C $(FLUTTER_ENGINE_BUILD_DIR)
endef
endif # !FLUTTER_ENGINE_USE_PREBUILT

ifeq ($(FLUTTER_ENGINE_USE_PREBUILT),YES)
define FLUTTER_ENGINE_ENSURE_PREBUILT
	if [ ! -f "$(FLUTTER_ENGINE_PREBUILT_DIR)/.lws-prebuilt" ]; then \
		printf 'flutter-engine %s: missing prebuilt %s\n' \
			"$(FLUTTER_ENGINE_VERSION)" "$(FLUTTER_ENGINE_PREBUILT_DIR)" 1>&2; \
		printf 'Run: make build-deps (clone) or make build-prebuilt (maintainer)\n' 1>&2; \
		exit 1; \
	fi
endef
FLUTTER_ENGINE_POST_DOWNLOAD_HOOKS += FLUTTER_ENGINE_ENSURE_PREBUILT

define FLUTTER_ENGINE_EXTRACT_CMDS
	mkdir -p $(@D)
endef

define FLUTTER_ENGINE_CONFIGURE_CMDS
	:
endef

define FLUTTER_ENGINE_BUILD_CMDS
	:
endef
endif # FLUTTER_ENGINE_USE_PREBUILT

FLUTTER_ENGINE_GEN_SNAPSHOT = $(HOST_DIR)/bin/flutter_gen_snapshot

ifeq ($(FLUTTER_ENGINE_USE_PREBUILT),YES)
define FLUTTER_ENGINE_INSTALL_GEN_SNAPSHOT
	$(INSTALL) -D -m 0755 $(FLUTTER_ENGINE_PREBUILT_DIR)/host/bin/gen_snapshot \
		$(HOST_DIR)/bin/flutter_gen_snapshot
endef
else
define FLUTTER_ENGINE_INSTALL_GEN_SNAPSHOT
	$(INSTALL) -D -m 0755 $(FLUTTER_ENGINE_BUILD_DIR)/clang_x64/gen_snapshot \
		$(HOST_DIR)/bin/flutter_gen_snapshot
endef
endif
FLUTTER_ENGINE_POST_INSTALL_STAGING_HOOKS += FLUTTER_ENGINE_INSTALL_GEN_SNAPSHOT

ifeq ($(FLUTTER_ENGINE_USE_PREBUILT),YES)
define FLUTTER_ENGINE_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 0755 \
		$(FLUTTER_ENGINE_PREBUILT_DIR)/staging/usr/lib/libflutter_engine.so \
		$(STAGING_DIR)/usr/lib/libflutter_engine.so
	$(INSTALL) -D -m 0644 \
		$(FLUTTER_ENGINE_PREBUILT_DIR)/staging/usr/include/flutter_embedder.h \
		$(STAGING_DIR)/usr/include/flutter_embedder.h
	$(INSTALL) -D -m 0644 \
		$(FLUTTER_ENGINE_PREBUILT_DIR)/staging/usr/share/flutter/$(FLUTTER_ENGINE_RUNTIME_MODE)/data/icudtl.dat \
		$(STAGING_DIR)/usr/share/flutter/$(FLUTTER_ENGINE_RUNTIME_MODE)/data/icudtl.dat
endef

define FLUTTER_ENGINE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 \
		$(FLUTTER_ENGINE_PREBUILT_DIR)/target/usr/lib/libflutter_engine.so \
		$(TARGET_DIR)/usr/lib/libflutter_engine.so
	$(INSTALL) -D -m 0644 \
		$(FLUTTER_ENGINE_PREBUILT_DIR)/target/usr/share/flutter/$(FLUTTER_ENGINE_RUNTIME_MODE)/data/icudtl.dat \
		$(TARGET_DIR)/usr/share/flutter/$(FLUTTER_ENGINE_RUNTIME_MODE)/data/icudtl.dat
endef
else
define FLUTTER_ENGINE_INSTALL_STAGING_CMDS
	$(foreach i,$(FLUTTER_ENGINE_INSTALL_FILES),
		$(INSTALL) -D -m 0755 $(FLUTTER_ENGINE_BUILD_DIR)/so.unstripped/$(i) \
			$(STAGING_DIR)/usr/lib/$(i); \
	)
	$(INSTALL) -D -m 0755 $(FLUTTER_ENGINE_BUILD_DIR)/flutter_embedder.h \
		$(STAGING_DIR)/usr/include/flutter_embedder.h

	$(INSTALL) -D -m 0755 $(FLUTTER_ENGINE_BUILD_DIR)/icudtl.dat \
		$(STAGING_DIR)/usr/share/flutter/$(FLUTTER_ENGINE_RUNTIME_MODE)/data/icudtl.dat
endef

define FLUTTER_ENGINE_INSTALL_TARGET_CMDS
	$(foreach i,$(FLUTTER_ENGINE_INSTALL_FILES),
		$(INSTALL) -D -m 0755 $(FLUTTER_ENGINE_BUILD_DIR)/so.unstripped/$(i) \
			$(TARGET_DIR)/usr/lib/$(i); \
	)
	$(INSTALL) -D -m 0755 $(FLUTTER_ENGINE_BUILD_DIR)/icudtl.dat \
		$(TARGET_DIR)/usr/share/flutter/$(FLUTTER_ENGINE_RUNTIME_MODE)/data/icudtl.dat
endef
endif

$(eval $(generic-package))

FLUTTER_SDK_BIN_PUB_CACHE = $(DL_DIR)/br-flutter-pub-cache
