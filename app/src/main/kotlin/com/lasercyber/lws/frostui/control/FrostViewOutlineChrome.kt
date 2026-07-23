package com.lasercyber.lws.frostui.control

import android.graphics.Outline
import android.graphics.Path
import android.os.Build
import android.view.View
import android.view.ViewOutlineProvider
import androidx.annotation.DimenRes

/** Applies outline clips; background layers stay rectangular and get clipped here. */
object FrostViewOutlineChrome {
    @JvmStatic
    fun applyRoundedClip(view: View, @DimenRes cornerRadiusDimenRes: Int) {
        val radius = view.resources.getDimension(cornerRadiusDimenRes)
        view.clipToOutline = true
        view.outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(v: View, outline: Outline) {
                outline.setRoundRect(0, 0, v.width, v.height, radius)
            }
        }
    }

    /** Convex path clip (API 30+). Ripple overlay matches engineer mode; path owns the visible shape. */
    @JvmStatic
    fun applyConvexPathClip(view: View, pathProvider: (width: Int, height: Int) -> Path) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return
        }
        view.clipToOutline = true
        view.outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(v: View, outline: Outline) {
                if (v.width <= 0 || v.height <= 0) {
                    return
                }
                outline.setConvexPath(pathProvider(v.width, v.height))
            }
        }
    }
}
