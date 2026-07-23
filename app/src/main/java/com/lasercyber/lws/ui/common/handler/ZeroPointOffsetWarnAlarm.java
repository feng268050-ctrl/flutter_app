package com.lasercyber.lws.ui.common.handler;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import androidx.annotation.NonNull;

import com.blankj.utilcode.util.ActivityUtils;
import com.lasercyber.lws.ai.zeropoint.ZeroPointPendingCorrectionStore;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.WarnTableViewModel;
import com.lasercyber.lws.ui.activitys.setting.DeviceSettingActivity;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.common.boot.BootSelfCheckGate;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodePolicy;
import com.lasercyber.lws.ui.common.constant.AlarmCodeConstants;
import com.lasercyber.lws.ui.common.utils.WarnUtil;
import com.lasercyber.lws.ui.common.utils.convert.DeviceStatusConvert;
import com.lasercyber.lws.ui.common.weld.WeldAlertScope;
import com.lasercyber.lws.ui.common.weld.WeldModeHost;

/**
 * Weld zero-point offset reminder ({@link AlarmCodeConstants#ALARM_H034}) after auto-detect
 * finds an out-of-tolerance offset.
 */
public final class ZeroPointOffsetWarnAlarm {

    private static final String TAG = "ZeroPointOffsetAlarm";

    public static final ZeroPointOffsetWarnAlarm INSTANCE = new ZeroPointOffsetWarnAlarm();

    private final WarnTableViewModel warnTableViewModel = new WarnTableViewModel();

    private boolean pendingReminder;
    private boolean dialogAcknowledgedThisBoot;

    private ZeroPointOffsetWarnAlarm() {
    }

    @NonNull
    public static String getAlarmCode() {
        return AlarmCodeConstants.ALARM_H034;
    }

    public synchronized void onFaultSignaled(@NonNull Context context) {
        if (!WeldAlertScope.isEligibleFromTopActivity()) {
            return;
        }
        Context app = context.getApplicationContext();
        String content = app.getString(R.string.zero_point_offset_alert_body);
        warnTableViewModel.saveZeroPointOffsetWarnLog(context, content);
        pendingReminder = true;
        Log.i(TAG, "pending zero-point offset reminder set code=" + getAlarmCode());
        showPassiveDialogIfNeeded(context);
    }

    public synchronized void onFaultCleared() {
        pendingReminder = false;
        ZeroPointPendingCorrectionStore.getInstance().clear();
        WarnLogEpisodeTracker.notifyFaultCleared(getAlarmCode());
        DeviceStatusConvert.closeWarn(getAlarmCode());
    }

    public synchronized void onDialogDismissed(@NonNull Context context) {
        onFaultCleared();
        dialogAcknowledgedThisBoot = false;
    }

    public synchronized void resetForStop() {
        pendingReminder = false;
        dialogAcknowledgedThisBoot = false;
        ZeroPointPendingCorrectionStore.getInstance().clear();
        DeviceStatusConvert.closeWarn(getAlarmCode());
    }

    /** Visible to same-package unit tests. */
    synchronized boolean isPendingReminderForTest() {
        return pendingReminder;
    }

    /** Visible to same-package unit tests. */
    synchronized void armPendingForTest() {
        pendingReminder = true;
    }

    private synchronized void showPassiveDialogIfNeeded(@NonNull Context context) {
        if (BootSelfCheckGate.isActive()) {
            return;
        }
        if (!pendingReminder || dialogAcknowledgedThisBoot) {
            return;
        }
        if (!WeldAlertScope.isEligibleFromTopActivity()) {
            return;
        }
        Context app = context.getApplicationContext();
        WarnDialogVo vo = buildDialogVo(app);
        WarnEpisodeController.notifyFaultActive(getAlarmCode(), WarnEpisodePolicy.productionPassive());
        DeviceDialogHandler.showPassiveWarnDialog(vo);
    }

    @NonNull
    private WarnDialogVo buildDialogVo(@NonNull Context app) {
        WarnDialogVo vo = new WarnDialogVo();
        vo.setType(WarnUtil.WARN_TYPE);
        vo.setTitle(app.getString(R.string.zero_point_offset_alarm_title));
        vo.setContent(app.getString(R.string.zero_point_offset_alert_body));
        vo.setIsShowProgress(false);
        vo.setErrorCode(getAlarmCode());
        vo.setButtonText(app.getString(R.string.confirm_text));
        vo.setJumpButtonText(app.getString(R.string.zero_point_offset_alert_go_settings));
        vo.setOnConfirm(() -> onDialogDismissed(app));
        vo.setOnJump(() -> onJumpToAdvancedSettings(app));
        return vo;
    }

    private synchronized void onJumpToAdvancedSettings(@NonNull Context app) {
        onDialogDismissed(app);
        Activity topActivity = ActivityUtils.getTopActivity();
        Runnable openSettings = () -> openAdvancedSettings(app);
        if (topActivity instanceof WeldModeHost host) {
            host.exitWeldWorkForZeroPointSettings(openSettings);
        } else {
            openSettings.run();
        }
    }

    private void openAdvancedSettings(Context context) {
        Intent intent = new Intent(context, DeviceSettingActivity.class);
        intent.putExtra(DeviceSettingActivity.EXTRA_INITIAL_TAB_INDEX,
                DeviceSettingActivity.TAB_INDEX_ADVANCED_SETTINGS);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }
}
