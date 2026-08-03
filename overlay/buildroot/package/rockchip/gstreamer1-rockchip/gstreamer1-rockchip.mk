################################################################################
#
# gstreamer1-rockchip
#
# Overlay: always enable librga convert/scale for mppvideodec (format/width/height).
# Stock keys off BR2_PREFER_ROCKCHIP_RGA, which is easy to miss in chip fragments and
# leaves Flutter RTSP preview on CPU NV12→RGBA (~1fps on RK3566).
#
################################################################################

GSTREAMER1_ROCKCHIP_SITE = $(TOPDIR)/../external/gstreamer-rockchip
GSTREAMER1_ROCKCHIP_VERSION = master
GSTREAMER1_ROCKCHIP_SITE_METHOD = local

GSTREAMER1_ROCKCHIP_LICENSE_FILES = COPYING
GSTREAMER1_ROCKCHIP_LICENSE = LGPL-2.1
GSTREAMER1_ROCKCHIP_DEPENDENCIES = gst1-plugins-base

GSTREAMER1_ROCKCHIP_DEPENDENCIES += rockchip-mpp
GSTREAMER1_ROCKCHIP_CONF_OPTS += -Drockchipmpp=enabled

GSTREAMER1_ROCKCHIP_DEPENDENCIES += rockchip-rga
GSTREAMER1_ROCKCHIP_CONF_OPTS += -Drga=enabled

ifeq ($(BR2_PACKAGE_XORG7),y)
GSTREAMER1_ROCKCHIP_DEPENDENCIES += xlib_libX11 libdrm
GSTREAMER1_ROCKCHIP_CONF_OPTS += -Drkximage=enabled
endif

$(eval $(meson-package))
