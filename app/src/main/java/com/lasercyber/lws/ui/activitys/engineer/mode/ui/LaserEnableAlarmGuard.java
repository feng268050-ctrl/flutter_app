package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import android.app.Activity;
import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.camera.CameraCommStatus;
import com.lasercyber.lws.ui.common.constant.AlarmCodeConstants;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.common.handler.CameraCommunicationWarnAlarm;
import com.lasercyber.lws.ui.common.handler.LensHeavyContaminationWarnAlarm;
import com.lasercyber.lws.ui.common.settings.DangerousOperationsSettings;
import com.lasercyber.lws.ui.common.utils.ShieldingGasAlarmMessageUtil;
import com.lasercyber.lws.ui.common.utils.convert.DeviceStatusConvert;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;

/**
 * Laser-enable preflight and runtime work blocking for coded alarms.
 * A001, C002, L001, W001, and W002 support dangerous-operations bypass; all other coded alarms always block.
 */
public final class LaserEnableAlarmGuard {

    private LaserEnableAlarmGuard() {
    }

    public static boolean passesPreflight(@NonNull Activity activity) {
        Context app = activity.getApplicationContext();
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);

        if (deviceStatus != null && EngineerModeCheck.isKeySwitchPreflightBlocking(deviceStatus)) {
            OperationDialogBuilder.openErrorDialog(activity, R.string.check_key_error_text);
            return false;
        }

        if (isGasBlocking(app, deviceStatus)) {
            return blockLaserEnable(activity,
                    DeviceStatusConvert.convertShieldingGasAlarmDialogVo(deviceStatus, true),
                    AlarmCodeEnums.A001);
        }

        if (isCameraBlocking(app)) {
            return blockLaserEnable(activity,
                    CameraCommunicationWarnAlarm.INSTANCE.buildActiveBlockDialogVo(),
                    AlarmCodeEnums.C002);
        }

        if (isLensBlocking(app)) {
            return blockLaserEnable(activity,
                    LensHeavyContaminationWarnAlarm.INSTANCE.buildLaserEnableBlockDialogVo(app),
                    AlarmCodeEnums.L001);
        }

        if (isFeederBlocking(app, deviceStatus)) {
            AlarmCodeEnums feederAlarm = resolveActiveFeederAlarm(deviceStatus);
            return blockLaserEnable(activity,
                    DeviceStatusConvert.convertToWarnDialogVo(deviceStatus, true),
                    feederAlarm);
        }

        AlarmCodeEnums otherBlocking = WarnEpisodeController.findFirstBlockingOtherCodedWarn();
        if (otherBlocking != null) {
            if (DangerousOperationsSettings.isKeepLaserOnWhileAlarmed(app)) {
                return true;
            }
            return blockLaserEnable(
                    activity, buildFallbackActiveBlockVo(otherBlocking), otherBlocking);
        }

        return true;
    }

    /** True when any coded alarm blocks work (bypass applies to A001/C002/L001/W001/W002). */
    public static boolean isWorkBlocked(@Nullable Context context, @Nullable DeviceStatus deviceStatus) {
        if (DangerousOperationsSettings.isKeepLaserOnWhileAlarmed(context)) {
            return false;
        }
        return isReadyIndicatorBlocked(context, deviceStatus);
    }

    /**
     * True when coded alarms block the green ready GPIO.
     * Respects A001/C002/L001/W001/W002 bypass toggles only; ignores keepLaserOnWhileAlarmed.
     */
    public static boolean isReadyIndicatorBlocked(
            @Nullable Context context, @Nullable DeviceStatus deviceStatus) {
        return isGasBlocking(context, deviceStatus)
                || isCameraBlocking(context)
                || isLensBlocking(context)
                || isFeederBlocking(context, deviceStatus)
                || isOtherCodedWarnBlocking();
    }

    @VisibleForTesting
    public static boolean isBypassableAlarmCode(@Nullable String code) {
        return AlarmCodeConstants.ALARM_A001.equals(code)
                || AlarmCodeConstants.ALARM_C002.equals(code)
                || AlarmCodeConstants.ALARM_L001.equals(code)
                || AlarmCodeConstants.ALARM_W001.equals(code)
                || AlarmCodeConstants.ALARM_W002.equals(code);
    }

    private static boolean blockLaserEnable(
            @NonNull Activity activity,
            @Nullable WarnDialogVo vo,
            @NonNull AlarmCodeEnums fallbackAlarm) {
        WarnDialogVo effective = vo != null ? vo : buildFallbackActiveBlockVo(fallbackAlarm);
        String errorCode = effective != null ? effective.getErrorCode() : fallbackAlarm.errorCode;
        if (!StringUtils.isEmpty(errorCode) && WarnEpisodeController.isOverlayVisible(errorCode)) {
            return false;
        }
        if (effective != null) {
            WarnEpisodeController.requestImmediateShow(activity, effective);
        }
        return false;
    }

    @Nullable
    private static WarnDialogVo buildFallbackActiveBlockVo(@NonNull AlarmCodeEnums alarm) {
        if (LaserEnableAlarmGuard.isBypassableAlarmCode(alarm.errorCode)) {
            return DeviceStatusConvert.createAlarmHit(
                    alarm.errorCode,
                    Utils.getApp().getString(alarm.titleId),
                    Utils.getApp().getString(alarm.contentId),
                    false);
        }
        return DeviceStatusConvert.createSeriousHit(
                alarm.errorCode,
                Utils.getApp().getString(alarm.titleId),
                Utils.getApp().getString(alarm.contentId),
                false);
    }

    @VisibleForTesting
    public static boolean isGasBlocking(@Nullable Context context, @Nullable DeviceStatus deviceStatus) {
        boolean active = ShieldingGasAlarmMessageUtil.hasActiveAlarm(deviceStatus)
                || WarnEpisodeController.isDemoFaultActive(AlarmCodeEnums.A001.errorCode);
        return active && !DangerousOperationsSettings.isAllowWorkAfterGasAlarm(context);
    }

    @VisibleForTesting
    public static boolean isCameraBlocking(@Nullable Context context) {
        boolean active = CameraCommStatus.isFault()
                || WarnEpisodeController.isDemoFaultActive(AlarmCodeEnums.C002.errorCode);
        return active && !DangerousOperationsSettings.isAllowWorkAfterCameraAlarm(context);
    }

    @VisibleForTesting
    public static boolean isLensBlocking(@Nullable Context context) {
        boolean active = LensHeavyContaminationWarnAlarm.INSTANCE.isLaserEnableBlocked()
                || WarnEpisodeController.isDemoFaultActive(AlarmCodeEnums.L001.errorCode);
        return active && !DangerousOperationsSettings.isAllowWorkAfterLensContamination(context);
    }

    @VisibleForTesting
    public static boolean isFeederAlarmActive(@Nullable DeviceStatus deviceStatus) {
        if (deviceStatus != null) {
            if (deviceStatus.isWireFeederCommunicationAlarm() || deviceStatus.isWireFeederCurrentAlarm()) {
                return true;
            }
        }
        return WarnEpisodeController.isDemoFaultActive(AlarmCodeEnums.W001.errorCode)
                || WarnEpisodeController.isDemoFaultActive(AlarmCodeEnums.W002.errorCode);
    }

    @VisibleForTesting
    public static boolean isFeederBlocking(@Nullable Context context, @Nullable DeviceStatus deviceStatus) {
        return isFeederAlarmActive(deviceStatus)
                && !DangerousOperationsSettings.isAllowWorkAfterFeederAlarm(context);
    }

    @NonNull
    private static AlarmCodeEnums resolveActiveFeederAlarm(@Nullable DeviceStatus deviceStatus) {
        if (deviceStatus != null && deviceStatus.isWireFeederCommunicationAlarm()) {
            return AlarmCodeEnums.W001;
        }
        if (deviceStatus != null && deviceStatus.isWireFeederCurrentAlarm()) {
            return AlarmCodeEnums.W002;
        }
        if (WarnEpisodeController.isDemoFaultActive(AlarmCodeEnums.W001.errorCode)) {
            return AlarmCodeEnums.W001;
        }
        return AlarmCodeEnums.W002;
    }

    @VisibleForTesting
    public static boolean isOtherCodedWarnBlocking() {
        return WarnEpisodeController.findFirstBlockingOtherCodedWarn() != null;
    }

    @VisibleForTesting
    @Nullable
    static AlarmCodeEnums findFirstBlockingOtherCodedWarn() {
        return WarnEpisodeController.findFirstBlockingOtherCodedWarn();
    }

    /** True when {@code errorCode} is a known alarm code that should trigger runtime laser interrupt. */
    public static boolean shouldInterruptLaserForErrorCode(@Nullable String errorCode) {
        return AlarmCodeEnums.findByCode(errorCode) != null;
    }
}
