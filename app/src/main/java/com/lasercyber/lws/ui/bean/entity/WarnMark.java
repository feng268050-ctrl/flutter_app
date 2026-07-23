package com.lasercyber.lws.ui.bean.entity;

import java.io.Serializable;

import lombok.Data;
import lombok.experimental.Accessors;

@Accessors(chain = true)
@Data
public class WarnMark implements Serializable {
    /**
     * 本故障周期内是否仍需向操作员弹窗/声音提醒。
     * 用户点「确定」后由 {@link com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController#tryConsumeReminderForDialog}
     * 置为 {@code false}；通讯恢复 {@link com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController#tryClose}
     * 后再次故障时由 {@link com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController#rearmReminder} 置回 {@code true}。
     */
    private boolean reminder;
    /**
     * 初次告警时间
     */
    private long warnTime;
    /**
     * 关闭时间
     */
    private long closeReminderTime;
    /**
     * 是否告警
     */
    private boolean isWarn;
    /**
     * 解除告警时间
     */
    private long removeWarnTime;
    /**
     * 弹窗是否已经打开
     */
    private boolean dialogOpen;
    /**
     * When true, {@link com.lasercyber.lws.ui.common.utils.convert.DeviceStatusConvert#closeWarn}
     * must not auto-dismiss this episode (frozen in {@link com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController}).
     */
    private boolean resistExternalAutoClose;
    public static WarnMark create() {
        WarnMark warnMark = new WarnMark();
        warnMark.setReminder(true);
        warnMark.setWarn(true);
        warnMark.setDialogOpen(false);
        warnMark.setWarnTime(System.currentTimeMillis());
        return warnMark;
    }
}
