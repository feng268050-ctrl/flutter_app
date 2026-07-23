package com.lasercyber.lws.ui.common.weld;

import androidx.annotation.NonNull;

/**
 * Quick / Engineer mode activities expose the active process type for weld deferred alerts.
 */
public interface WeldModeHost {

    int getActiveWeldModelType();

    /**
     * Zero-point offset "go to settings": disable laser enable, end the current work session, then run {@code onDone}.
     */
    void exitWeldWorkForZeroPointSettings(@NonNull Runnable onDone);
}
