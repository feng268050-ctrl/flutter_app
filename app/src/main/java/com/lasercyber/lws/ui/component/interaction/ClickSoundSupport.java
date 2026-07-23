package com.lasercyber.lws.ui.component.interaction;

import android.view.View;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;

/** Shared click-sound behavior for custom interactive widgets (settings-backed SoundPool). */
public final class ClickSoundSupport {

    private ClickSoundSupport() {
    }

    /** Disable Android system click tone; use {@link #play(View)} on user activation instead. */
    public static void install(@NonNull View view) {
        view.setSoundEffectsEnabled(false);
    }

    public static void play(@NonNull View view) {
        if (view.isEnabled() && view.isClickable()) {
            GlobalSoundManager.playClickSound(view.getContext());
        }
    }
}
