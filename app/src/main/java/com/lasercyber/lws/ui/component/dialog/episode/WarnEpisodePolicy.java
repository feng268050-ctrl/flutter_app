package com.lasercyber.lws.ui.component.dialog.episode;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;

/**
 * Frozen when an episode is armed. Must not change during the episode lifecycle.
 */
public final class WarnEpisodePolicy {

    private final boolean resistExternalAutoClose;
    private final boolean demoSimulated;

    private WarnEpisodePolicy(boolean resistExternalAutoClose, boolean demoSimulated) {
        this.resistExternalAutoClose = resistExternalAutoClose;
        this.demoSimulated = demoSimulated;
    }

    public static WarnEpisodePolicy productionPassive() {
        return new WarnEpisodePolicy(false, false);
    }

    public static WarnEpisodePolicy demoAlarm() {
        return new WarnEpisodePolicy(true, true);
    }

    public static WarnEpisodePolicy laserEnableBlock() {
        return new WarnEpisodePolicy(false, false);
    }

    /** Production fault with operator-confirm resist (e.g. L001 lens). */
    public static WarnEpisodePolicy productionResist() {
        return new WarnEpisodePolicy(true, false);
    }

    @NonNull
    public static WarnEpisodePolicy fromVo(@NonNull WarnDialogVo vo) {
        return new WarnEpisodePolicy(vo.isResistExternalAutoClose(), false);
    }

    public boolean resistsExternalAutoClose() {
        return resistExternalAutoClose;
    }

    public boolean isDemoSimulated() {
        return demoSimulated;
    }
}
