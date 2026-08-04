################################################################################
#
# flutter-embedded-linux (lws-hmi overlay) — prebuilt Wayland client only
#
################################################################################

# prebuilt/flutter-embedded-linux/<tag>/ must exist before build-rootfs-weston.

FLUTTER_EMBEDDED_LINUX_VERSION = 42d3d75a56

# Prebuilt-only: no download (see flutter-engine.mk).
FLUTTER_EMBEDDED_LINUX_SITE =
FLUTTER_EMBEDDED_LINUX_SOURCE =

LWS_HMI_ROOT ?= $(TOPDIR)/../..
FLUTTER_EMBEDDED_LINUX_PREBUILT_DIR = \
	$(LWS_HMI_ROOT)/prebuilt/flutter-embedded-linux/$(FLUTTER_EMBEDDED_LINUX_VERSION)

FLUTTER_EMBEDDED_LINUX_LICENSE = BSD-3-Clause
FLUTTER_EMBEDDED_LINUX_LICENSE_FILES = LICENSE
FLUTTER_EMBEDDED_LINUX_DEPENDENCIES = \
	flutter-engine \
	libxkbcommon \
	libdrm \
	wayland

define FLUTTER_EMBEDDED_LINUX_ENSURE_PREBUILT
	if [ ! -f "$(FLUTTER_EMBEDDED_LINUX_PREBUILT_DIR)/.lws-prebuilt" ]; then \
		printf 'flutter-embedded-linux %s: missing prebuilt %s\n' \
			"$(FLUTTER_EMBEDDED_LINUX_VERSION)" \
			"$(FLUTTER_EMBEDDED_LINUX_PREBUILT_DIR)" 1>&2; \
		printf 'Run: make build-flutter-embedded-linux\n' 1>&2; \
		exit 1; \
	fi
	if [ ! -f "$(FLUTTER_EMBEDDED_LINUX_PREBUILT_DIR)/.lws-gstreamer-video-player" ]; then \
		printf 'flutter-embedded-linux: missing GStreamer video plugin build\n' 1>&2; \
		printf 'Run: make build-flutter-embedded-linux\n' 1>&2; \
		exit 1; \
	fi
endef
FLUTTER_EMBEDDED_LINUX_POST_DOWNLOAD_HOOKS += FLUTTER_EMBEDDED_LINUX_ENSURE_PREBUILT

define FLUTTER_EMBEDDED_LINUX_EXTRACT_CMDS
	mkdir -p $(@D)
endef

define FLUTTER_EMBEDDED_LINUX_CONFIGURE_CMDS
	:
endef

define FLUTTER_EMBEDDED_LINUX_BUILD_CMDS
	:
endef

define FLUTTER_EMBEDDED_LINUX_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 \
		$(FLUTTER_EMBEDDED_LINUX_PREBUILT_DIR)/usr/bin/flutter-wayland-client \
		$(TARGET_DIR)/usr/bin/flutter-wayland-client
	$(INSTALL) -D -m 0755 \
		$(FLUTTER_EMBEDDED_LINUX_PREBUILT_DIR)/usr/lib/libvideo_player_plugin.so \
		$(TARGET_DIR)/usr/lib/libvideo_player_plugin.so
endef

$(eval $(generic-package))
