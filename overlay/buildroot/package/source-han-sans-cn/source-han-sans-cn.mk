###############################################################################
#
# Source Han Sans CN (lws-hmi overlay) — UI subset only
#
###############################################################################

SOURCE_HAN_SANS_CN_VERSION = $(SOURCE_HAN_SANS_VERSION)
SOURCE_HAN_SANS_CN_SOURCE = SourceHanSansCN.zip
SOURCE_HAN_SANS_CN_SITE = $(SOURCE_HAN_SANS_SITE)
SOURCE_HAN_SANS_CN_LICENSE = OFL-1.1
SOURCE_HAN_SANS_CN_LICENSE_FILES = LICENSE.txt
SOURCE_HAN_SANS_CN_DEPENDENCIES = host-zip

# Regular/Medium/Bold cover normal UI; Medium matches 44-source-han-sans-cn.conf.
SOURCE_HAN_SANS_CN_FONTS = \
	SourceHanSansCN-Regular.otf \
	SourceHanSansCN-Medium.otf \
	SourceHanSansCN-Bold.otf

define SOURCE_HAN_SANS_CN_EXTRACT_CMDS
	unzip $(SOURCE_HAN_SANS_CN_DL_DIR)/$(SOURCE_HAN_SANS_CN_SOURCE) -d $(@D)/
endef

ifeq ($(BR2_PACKAGE_FONTCONFIG),y)
define SOURCE_HAN_SANS_CN_INSTALL_FONTCONFIG_CONF
	$(INSTALL) -D -m 0644 \
		$(SOURCE_HAN_SANS_CN_PKGDIR)/44-source-han-sans-cn.conf \
		$(TARGET_DIR)/usr/share/fontconfig/conf.avail/
endef
endif

define SOURCE_HAN_SANS_CN_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/fonts/source-han-sans-cn/
	for f in $(SOURCE_HAN_SANS_CN_FONTS); do \
		$(INSTALL) -m 0644 $(@D)/SubsetOTF/CN/$$f \
			$(TARGET_DIR)/usr/share/fonts/source-han-sans-cn/ || exit 1; \
	done
	$(SOURCE_HAN_SANS_CN_INSTALL_FONTCONFIG_CONF)
endef

$(eval $(generic-package))
