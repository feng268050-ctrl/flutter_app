################################################################################
#
# flutter-engine (lws-hmi overlay) — prebuilt install only
#
################################################################################

# prebuilt/flutter-engine/<ver>/arm64-<mode>/ must exist before build-rootfs.
# Maintainers: populate via make build-flutter-engine / make build-runtime-deps, or commit
# artifacts from a one-off upstream SDK compile when bumping version pins.

FLUTTER_ENGINE_VERSION = 3.24.4

FLUTTER_ENGINE_SITE =
FLUTTER_ENGINE_SOURCE =
FLUTTER_ENGINE_LICENSE = BSD-3-Clause
FLUTTER_ENGINE_LICENSE_FILES = LICENSE
FLUTTER_ENGINE_INSTALL_STAGING = YES
FLUTTER_ENGINE_DEPENDENCIES =

ifndef LWS_HMI_ROOT
# Docker: /work/lws-hmi; native: sibling of SDK checkout.
LWS_HMI_ROOT := $(shell \
	if [ -d "$(TOPDIR)/../../lws-hmi/prebuilt/flutter-engine" ]; then \
		echo "$(TOPDIR)/../../lws-hmi"; \
	elif [ -d "$(TOPDIR)/../lws-hmi/prebuilt/flutter-engine" ]; then \
		echo "$(TOPDIR)/../lws-hmi"; \
	else \
		echo "$(TOPDIR)/../.."; \
	fi)
endif

ifeq ($(FLUTTER_ENGINE_RUNTIME_MODE_PROFILE),y)
FLUTTER_ENGINE_RUNTIME_MODE=profile
else ifeq ($(BR2_ENABLE_RUNTIME_DEBUG),y)
FLUTTER_ENGINE_RUNTIME_MODE=debug
else
FLUTTER_ENGINE_RUNTIME_MODE=release
endif

FLUTTER_ENGINE_PREBUILT_DIR = $(LWS_HMI_ROOT)/prebuilt/flutter-engine/$(FLUTTER_ENGINE_VERSION)/arm64-$(FLUTTER_ENGINE_RUNTIME_MODE)

define FLUTTER_ENGINE_ENSURE_PREBUILT
	if [ ! -f "$(FLUTTER_ENGINE_PREBUILT_DIR)/.lws-prebuilt" ]; then \
		printf 'flutter-engine %s: missing prebuilt %s\n' \
			"$(FLUTTER_ENGINE_VERSION)" "$(FLUTTER_ENGINE_PREBUILT_DIR)" 1>&2; \
		printf 'Run: make build-flutter-engine\n' 1>&2; \
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

define FLUTTER_ENGINE_INSTALL_GEN_SNAPSHOT
	$(INSTALL) -D -m 0755 $(FLUTTER_ENGINE_PREBUILT_DIR)/host/bin/gen_snapshot \
		$(HOST_DIR)/bin/flutter_gen_snapshot
endef
FLUTTER_ENGINE_POST_INSTALL_STAGING_HOOKS += FLUTTER_ENGINE_INSTALL_GEN_SNAPSHOT

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

$(eval $(generic-package))
