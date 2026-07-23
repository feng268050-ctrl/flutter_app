package com.lasercyber.lws.ui.activitys.engineer.mode.ui

import android.view.View
import com.lasercyber.lws.frostui.control.FrostViewOutlineChrome
import com.lasercyber.lws.ui.R

/** Engineer toggle buttons: one [R.dimen.engineer_toggle_btn_corner_radius], rectangular fill + clip. */
object EngineerToggleButtonChrome {
    @JvmStatic
    fun apply(view: View) {
        FrostViewOutlineChrome.applyRoundedClip(view, R.dimen.engineer_toggle_btn_corner_radius)
    }
}
