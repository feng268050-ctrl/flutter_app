package com.lasercyber.lws.frostui.control

object FrostControlDefaults {
    const val ANIMATION_DURATION_MS = 200
    const val SEGMENT_CROSSFADE_DURATION_MS = 200
    const val SLIDER_LONG_PRESS_THRESHOLD_MS = 200
    const val SEGMENT_LONG_PRESS_THRESHOLD_MS = 200
    const val SLIDER_THUMB_DRAG_SCALE = 1.3f
    const val SLIDER_THUMB_EXPAND_DURATION_MS = 150
    const val SLIDER_CENTER_SNAP_VALUE = 0
    const val SLIDER_CENTER_SNAP_DWELL_MS = 100
    const val REVERSIBLE_RIPPLE_FILL_DURATION_MS = 300
    const val REVERSIBLE_RIPPLE_HOLD_SCALE = 1.06f
}

internal fun shouldNotifyCheckedChange(wasChecked: Boolean, requested: Boolean): Boolean =
    wasChecked != requested
