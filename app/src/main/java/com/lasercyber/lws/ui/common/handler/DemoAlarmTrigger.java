package com.lasercyber.lws.ui.common.handler;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserWorkGuard;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.common.utils.convert.DeviceStatusConvert;

/**
 * Staging/debug helper: show a production warn dialog for a given alarm code (adb broadcast).
 * Disabled when {@link BuildConfig#RELEASE_CHANNEL} is true.
 */
public final class DemoAlarmTrigger {

    public static final String ACTION_DEMO_ALARM = "com.lasercyber.lws.ui.action.DEMO_ALARM";
    public static final String ACTION_DEMO_ALARM_CLEAN = "com.lasercyber.lws.ui.action.DEMO_ALARM_CLEAN";
    public static final String EXTRA_CODE = "code";
    private static final String TAG = "DemoAlarm";

    @Nullable
    private static volatile Boolean releaseChannelOverride;

    private DemoAlarmTrigger() {
    }

    public static void handle(@Nullable Context context, @Nullable String code) {
        if (isReleaseChannel()) {
            Log.d(TAG, "ignored: release channel");
            return;
        }
        if (context == null) {
            Log.w(TAG, "ignored: null context");
            return;
        }
        if (StringUtils.isEmpty(code)) {
            Log.w(TAG, "demo_alarm_unknown_code: empty");
            return;
        }
        AlarmCodeEnums alarm = AlarmCodeEnums.findByCode(code);
        if (alarm == null) {
            Log.w(TAG, "demo_alarm_unknown_code: " + code);
            return;
        }
        Context app = context.getApplicationContext();
        WarnDialogVo vo = buildDialogVo(alarm);
        if (vo == null) {
            Log.w(TAG, "demo_alarm_dialog_skipped: " + code);
            return;
        }
        WarnEpisodeController.armDemoEpisode(alarm.errorCode);
        DeviceDialogHandler.showPassiveWarnDialog(vo);
        LaserWorkGuard.evaluateAndInterruptIfNeeded(app);
        Log.i(TAG, "triggered code=" + alarm.errorCode);
    }

    /** Clears alarm restrictions; visible warn overlay stays open (staging/debug adb helper). */
    public static void clean(@Nullable Context context) {
        if (isReleaseChannel()) {
            Log.d(TAG, "clean ignored: release channel");
            return;
        }
        if (context == null) {
            Log.w(TAG, "clean ignored: null context");
            return;
        }
        WarnEpisodeController.clearAllForDebug();
        Log.i(TAG, "cleaned alarm restrictions");
    }

    @Nullable
    private static WarnDialogVo buildDialogVo(@NonNull AlarmCodeEnums alarm) {
        String title = Utils.getApp().getString(alarm.titleId);
        String content = Utils.getApp().getString(alarm.contentId);
        WarnDialogVo vo = DeviceStatusConvert.createSeriousHit(alarm.errorCode, title, content, false);
        if (vo != null) {
            vo.setResistExternalAutoClose(true);
        }
        return vo;
    }

    @VisibleForTesting
    static boolean isReleaseChannel() {
        if (releaseChannelOverride != null) {
            return releaseChannelOverride;
        }
        return BuildConfig.RELEASE_CHANNEL;
    }

    @VisibleForTesting
    static void setReleaseChannelOverrideForTest(@Nullable Boolean releaseChannel) {
        releaseChannelOverride = releaseChannel;
    }
}
