package com.lasercyber.lws.frostui.control

import android.view.View

internal fun View.disallowAncestorsInterceptTouch(disallow: Boolean) {
    var parent = parent
    while (parent != null) {
        parent.requestDisallowInterceptTouchEvent(disallow)
        parent = parent.parent
    }
}
