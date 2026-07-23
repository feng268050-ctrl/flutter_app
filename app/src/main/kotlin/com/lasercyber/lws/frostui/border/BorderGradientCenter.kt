package com.lasercyber.lws.frostui.border

import kotlin.jvm.JvmStatic

/** Supported highlight centers for frost panel border gradients. */
enum class BorderGradientCenter(val xmlValue: String) {
    TOP_LEFT_BOTTOM_RIGHT("top-left-bottom-right"),
    BOTTOM_LEFT_TOP_RIGHT("bottom-left-top-right"),
    TOP_RIGHT_BOTTOM_LEFT("top-right-bottom-left"),
    TOP_BOTTOM("top-bottom"),
    LEFT_RIGHT("left-right"),
    /** Single-color rounded stroke with no corner/edge gradient highlights. */
    UNIFORM("uniform");

    companion object {
        @JvmStatic
        fun fromXmlValue(value: String?): BorderGradientCenter {
            if (value == null) {
                return TOP_LEFT_BOTTOM_RIGHT
            }
            return entries.firstOrNull { it.xmlValue == value } ?: TOP_LEFT_BOTTOM_RIGHT
        }
    }
}
