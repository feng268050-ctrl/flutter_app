package com.lasercyber.lws.ui.activitys.quick.mode.ui

import com.lasercyber.lws.frostui.control.FrostHoldConfirmConfig
import com.lasercyber.lws.ui.activitys.quick.mode.component.LaserButtonTrapezoidGeometry
import com.lasercyber.lws.ui.activitys.quick.mode.component.LaserButtonTrapezoidPressRipple

object QuickModeLaserHoldConfirmConfig {
    @JvmStatic
    fun create(): FrostHoldConfirmConfig = FrostHoldConfirmConfig.trapezoidRippleOnly(
        applyViewClip = null,
        hitTest = { x, y, view ->
            LaserButtonTrapezoidGeometry.contains(
                x,
                y,
                view.width.toFloat(),
                view.height.toFloat(),
            )
        },
        rippleClipPath = null,
        coverRadiusProvider = { originX, originY, width, height ->
            LaserButtonTrapezoidGeometry.coverRadius(
                originX,
                originY,
                width.toFloat(),
                height.toFloat(),
            )
        },
        pressRippleProvider = { view -> LaserButtonTrapezoidPressRipple.create(view.context) },
    )
}
