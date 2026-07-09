################################################################################
#
# flutter-pi (lws-hmi overlay) — prebuilt install only
#
################################################################################

# prebuilt/flutter-pi/<commit>/ must exist before build-rootfs.

FLUTTER_PI_VERSION = 37bd9773c1938e5f76208bc4e8632fdbbb4190ff

# Prebuilt-only: no download (see flutter-engine.mk).
FLUTTER_PI_SITE =
FLUTTER_PI_SOURCE =

LWS_HMI_ROOT ?= $(TOPDIR)/../..
FLUTTER_PI_PREBUILT_DIR = $(LWS_HMI_ROOT)/prebuilt/flutter-pi/$(FLUTTER_PI_VERSION)

FLUTTER_PI_LICENSE = MIT
FLUTTER_PI_LICENSE_FILES = LICENSE
FLUTTER_PI_DEPENDENCIES = \
	flutter-engine \
	libinput \
	libxkbcommon \
	systemd

define FLUTTER_PI_ENSURE_PREBUILT
	if [ ! -f "$(FLUTTER_PI_PREBUILT_DIR)/.lws-prebuilt" ]; then \
		printf 'flutter-pi %s: missing prebuilt %s\n' \
			"$(FLUTTER_PI_VERSION)" "$(FLUTTER_PI_PREBUILT_DIR)" 1>&2; \
		printf 'Run: make build-flutter-engine / make build-flutter-pi\n' 1>&2; \
		exit 1; \
	fi
endef
FLUTTER_PI_POST_DOWNLOAD_HOOKS += FLUTTER_PI_ENSURE_PREBUILT

define FLUTTER_PI_EXTRACT_CMDS
	mkdir -p $(@D)
endef

define FLUTTER_PI_CONFIGURE_CMDS
	:
endef

define FLUTTER_PI_BUILD_CMDS
	:
endef

define FLUTTER_PI_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(FLUTTER_PI_PREBUILT_DIR)/usr/bin/flutter-pi \
		$(TARGET_DIR)/usr/bin/flutter-pi
endef

$(eval $(generic-package))
