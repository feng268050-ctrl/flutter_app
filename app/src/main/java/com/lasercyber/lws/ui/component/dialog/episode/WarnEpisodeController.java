package com.lasercyber.lws.ui.component.dialog.episode;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.bean.entity.WarnMark;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;
import com.lasercyber.lws.ui.common.handler.ExternalWarnAlarm;
import com.lasercyber.lws.ui.common.handler.ExternalWarnAlarmRegistry;
import com.lasercyber.lws.ui.common.handler.LensHeavyContaminationWarnAlarm;
import com.lasercyber.lws.ui.component.dialog.AutoDialogQueue;
import com.lasercyber.lws.ui.component.dialog.WarnDialogUtil;

/**
 * Single owner of coded warn episode lifecycle (policy, phase, reminder, close, laser blocking).
 * UI rendering stays in {@link WarnDialogUtil}; {@link WarnEpisodePersistence} mirrors state to cache.
 */
public final class WarnEpisodeController {

    public enum CloseReason {
        /** User tapped confirm / jump on the warn dialog. */
        OPERATOR,
        /** Modbus or external source reports fault cleared. */
        FAULT_RECOVERED,
    }

    private enum Phase {
        INACTIVE,
        /** Fault or demo armed; operator has not confirmed this cycle. */
        FAULT_ACTIVE,
        /** Operator confirmed; production may still block laser while Modbus fault persists. */
        OPERATOR_ACKED,
    }

    private static final String TAG = LogTAGConstant.WarnDialogUtil;

    private static final class Record {
        @NonNull
        WarnEpisodePolicy policy;
        @NonNull
        Phase phase = Phase.FAULT_ACTIVE;
        boolean faultActive = true;
        boolean reminderPending = true;
        boolean dialogOpen;

        Record(@NonNull WarnEpisodePolicy policy) {
            this.policy = policy;
        }
    }

    private static final java.util.Map<String, Record> EPISODES = new java.util.concurrent.ConcurrentHashMap<>();

    private WarnEpisodeController() {
    }

    /** Rising edge: make alarm, Modbus fault, or external fault. */
    public static void armEpisode(@NonNull String errorCode, @NonNull WarnEpisodePolicy policy) {
        Record existing = EPISODES.get(errorCode);
        if (existing != null && existing.policy.resistsExternalAutoClose()
                && !policy.resistsExternalAutoClose()) {
            existing.phase = Phase.FAULT_ACTIVE;
            existing.faultActive = true;
            existing.reminderPending = true;
            persist(errorCode, existing);
            Log.d(TAG, "armEpisode refresh resist " + errorCode);
            return;
        }
        Record record = new Record(policy);
        EPISODES.put(errorCode, record);
        persist(errorCode, record);
        Log.d(TAG, "armEpisode " + errorCode + " demo=" + policy.isDemoSimulated()
                + " resist=" + policy.resistsExternalAutoClose());
    }

    public static void armDemoEpisode(@NonNull String errorCode) {
        armEpisode(errorCode, WarnEpisodePolicy.demoAlarm());
    }

    /**
     * External fault rising edge with explicit policy (camera C002, lens L001, etc.).
     */
    public static void notifyFaultActive(@NonNull String errorCode, @NonNull WarnEpisodePolicy policy) {
        Record record = getOrHydrateRecord(errorCode);
        if (record == null || !record.faultActive) {
            armEpisode(errorCode, policy);
            return;
        }
        record.reminderPending = true;
        record.phase = Phase.FAULT_ACTIVE;
        persist(errorCode, record);
    }

    /**
     * Modbus passive evaluation: arms on rising edge; returns whether a popup is allowed this cycle.
     */
    public static boolean prepareModbusPassiveDialog(@NonNull String errorCode) {
        Record record = getOrHydrateRecord(errorCode);
        if (record == null || !record.faultActive) {
            armEpisode(errorCode, WarnEpisodePolicy.productionPassive());
            return true;
        }
        return record.reminderPending;
    }

    /** Re-arms popup for an active fault episode (e.g. camera comm fault edge). */
    public static void rearmReminder(@NonNull String errorCode) {
        Record record = getOrHydrateRecord(errorCode);
        if (record == null || !record.faultActive) {
            armEpisode(errorCode, WarnEpisodePolicy.productionPassive());
            return;
        }
        record.reminderPending = true;
        record.phase = Phase.FAULT_ACTIVE;
        persist(errorCode, record);
    }

    /**
     * After Frost overlay handoff: allow passive re-show while fault persists (non-resist only).
     */
    public static void rearmReminderAfterOverlayHandoff(@NonNull String errorCode) {
        Record record = getOrHydrateRecord(errorCode);
        if (record == null || !record.faultActive || record.policy.resistsExternalAutoClose()) {
            return;
        }
        record.reminderPending = true;
        persist(errorCode, record);
    }

    public static boolean isFaultActive(@Nullable String errorCode) {
        if (errorCode == null || errorCode.isEmpty()) {
            return false;
        }
        ExternalWarnAlarm external = ExternalWarnAlarmRegistry.forCode(errorCode);
        if (external != null) {
            return external.isFaultActive();
        }
        Record record = getOrHydrateRecord(errorCode);
        return record != null && record.faultActive;
    }

    public static boolean isReminderPending(@Nullable String errorCode) {
        if (errorCode == null || errorCode.isEmpty()) {
            return false;
        }
        if (!isFaultActive(errorCode)) {
            return false;
        }
        Record record = getOrHydrateRecord(errorCode);
        return record != null && record.faultActive && record.reminderPending;
    }

    /**
     * Consumes one popup slot before {@link WarnDialogUtil} attaches the overlay.
     *
     * @return {@code true} when the dialog may open
     */
    public static synchronized boolean tryConsumeReminderForDialog(@NonNull String errorCode) {
        if (!isFaultActive(errorCode)) {
            return false;
        }
        Record record = getOrHydrateRecord(errorCode);
        if (record == null || !record.faultActive || !record.reminderPending) {
            return false;
        }
        record.reminderPending = false;
        persist(errorCode, record);
        return true;
    }

    public static synchronized void markDialogOpen(@NonNull String errorCode) {
        Record record = getOrHydrateRecord(errorCode);
        if (record == null) {
            return;
        }
        record.dialogOpen = true;
        persist(errorCode, record);
    }

    public static synchronized void markDialogClosed(@NonNull String errorCode) {
        Record record = EPISODES.get(errorCode);
        if (record == null) {
            return;
        }
        record.dialogOpen = false;
        persist(errorCode, record);
    }

    /**
     * Operator tapped confirm. Clears demo simulation; production keeps fault until recovery.
     */
    public static void acknowledgeOperator(@NonNull String errorCode) {
        Record record = getOrHydrateRecord(errorCode);
        if (record == null) {
            return;
        }
        boolean demo = record.policy.isDemoSimulated();
        record.reminderPending = false;
        record.dialogOpen = false;
        if (demo) {
            record.faultActive = false;
            record.phase = Phase.INACTIVE;
            EPISODES.remove(errorCode);
            WarnEpisodePersistence.remove(errorCode);
        } else {
            record.phase = Phase.OPERATOR_ACKED;
            persist(errorCode, record);
        }
        Log.d(TAG, "acknowledgeOperator " + errorCode + " demo=" + demo);
    }

    /**
     * External auto-close (Modbus recovery, pipeline clear). Respects frozen resist policy.
     *
     * @return {@code true} when episode was torn down
     */
    public static boolean tryClose(@NonNull String errorCode, @NonNull CloseReason reason) {
        if (reason == CloseReason.FAULT_RECOVERED && resistsExternalAutoClose(errorCode)) {
            Log.d(TAG, "tryClose skipped (resist) " + errorCode);
            return false;
        }
        AutoDialogQueue.get().cancelPendingWarn(errorCode);
        boolean dismissed = WarnDialogUtil.dismissOverlayForCode(errorCode);
        tearDownEpisode(errorCode);
        if (dismissed) {
            Log.i(TAG, "tryClose " + errorCode + " reason=" + reason);
        } else if (reason == CloseReason.FAULT_RECOVERED) {
            Log.w(TAG, "tryClose episode cleared but overlay not dismissed " + errorCode);
        }
        return dismissed;
    }

    public static boolean resistsExternalAutoClose(@Nullable String errorCode) {
        if (errorCode == null || errorCode.isEmpty()) {
            return false;
        }
        Record record = getOrHydrateRecord(errorCode);
        if (record == null || record.phase == Phase.OPERATOR_ACKED) {
            return false;
        }
        return record.policy.resistsExternalAutoClose();
    }

    /** Demo episode awaiting operator confirm (replaces legacy sticky tracker). */
    public static boolean isDemoFaultActive(@Nullable String errorCode) {
        if (errorCode == null || errorCode.isEmpty()) {
            return false;
        }
        Record record = EPISODES.get(errorCode);
        return record != null
                && record.policy.isDemoSimulated()
                && record.phase == Phase.FAULT_ACTIVE;
    }

    /** Modbus / external passive popup ingress. */
    public static void requestPassiveShow(@NonNull Context context, @NonNull WarnDialogVo vo) {
        ensureEpisodeForShow(vo, WarnEpisodePolicy.productionPassive());
        AutoDialogQueue.get().enqueuePassiveWarn(context, vo);
    }

    /** Laser-enable preflight / quick-check immediate popup ingress. */
    public static void requestImmediateShow(@NonNull Activity activity, @NonNull WarnDialogVo vo) {
        ensureEpisodeForShow(vo, WarnEpisodePolicy.laserEnableBlock());
        AutoDialogQueue.get().enqueueImmediateWarn(activity, vo);
    }

    /** Overlay visible for {@code errorCode}. */
    public static boolean isOverlayVisible(@Nullable String errorCode) {
        return WarnDialogUtil.isShowingErrorCode(errorCode);
    }

    /**
     * Whether laser work / preflight must treat this code as blocking.
     * Demo: only while {@link Phase#FAULT_ACTIVE}. Production: while fault active.
     */
    public static boolean isBlockingLaser(@NonNull String errorCode) {
        if (!isFaultActive(errorCode)) {
            return false;
        }
        Record record = getOrHydrateRecord(errorCode);
        if (record == null) {
            return false;
        }
        if (record.policy.isDemoSimulated()) {
            return record.phase == Phase.FAULT_ACTIVE;
        }
        return true;
    }

    @Nullable
    public static AlarmCodeEnums findFirstBlockingOtherCodedWarn() {
        for (AlarmCodeEnums alarm : AlarmCodeEnums.values()) {
            String code = alarm.errorCode;
            if (LaserEnableAlarmGuardCompat.isBypassable(code)) {
                continue;
            }
            if (isBlockingLaser(code)) {
                return alarm;
            }
        }
        return null;
    }

    /** Frost must not remove resist warn overlays in {@code dismissAllOnActivity}. */
    public static boolean shouldProtectOverlay(@Nullable android.view.View overlay) {
        if (overlay == null) {
            return false;
        }
        Object tag = overlay.getTag(com.lasercyber.lws.ui.R.id.tag_warn_overlay_resist_code);
        return tag instanceof String code && resistsExternalAutoClose(code);
    }

    public static boolean blocksExternalOverlayDismiss() {
        String code = WarnDialogUtil.getActiveErrorCode();
        return code != null && resistsExternalAutoClose(code);
    }

    @VisibleForTesting
    public static void resetForTest() {
        EPISODES.clear();
        WarnEpisodePersistence.resetForTest();
    }

    /**
     * Staging/debug: clear alarm restrictions (episode persistence, laser-blocking state) without
     * dismissing a visible warn overlay. Cancels queued (not yet shown) warn dialogs. Invoked via
     * adb {@link com.lasercyber.lws.ui.common.handler.DemoAlarmTrigger#ACTION_DEMO_ALARM_CLEAN}.
     */
    public static void clearAllForDebug() {
        for (AlarmCodeEnums alarm : AlarmCodeEnums.values()) {
            AutoDialogQueue.get().cancelPendingWarn(alarm.errorCode);
        }
        java.util.ArrayList<String> activeCodes = new java.util.ArrayList<>(EPISODES.keySet());
        for (String code : activeCodes) {
            tearDownEpisode(code);
        }
        for (AlarmCodeEnums alarm : AlarmCodeEnums.values()) {
            WarnEpisodePersistence.remove(alarm.errorCode);
        }
        EPISODES.clear();
        LensHeavyContaminationWarnAlarm.INSTANCE.clearUnresolvedEpisodeForDebug();
        Log.i(TAG, "clearAllForDebug: alarm restrictions cleared (overlay kept if visible)");
    }

    private static void ensureEpisodeForShow(
            @NonNull WarnDialogVo vo, @NonNull WarnEpisodePolicy fallbackPolicy) {
        String code = vo.getErrorCode();
        if (StringUtils.isEmpty(code) || getOrHydrateRecord(code) != null) {
            return;
        }
        WarnEpisodePolicy policy = vo.isResistExternalAutoClose()
                ? WarnEpisodePolicy.fromVo(vo)
                : fallbackPolicy;
        armEpisode(code, policy);
    }

    private static void tearDownEpisode(@NonNull String errorCode) {
        Record record = EPISODES.get(errorCode);
        if (record != null) {
            record.faultActive = false;
            record.reminderPending = false;
            record.dialogOpen = false;
            record.phase = Phase.INACTIVE;
        }
        EPISODES.remove(errorCode);
        WarnMark mark = WarnEpisodePersistence.read(errorCode);
        if (mark != null) {
            mark.setWarn(false)
                    .setReminder(false)
                    .setDialogOpen(false)
                    .setResistExternalAutoClose(false)
                    .setRemoveWarnTime(System.currentTimeMillis());
            WarnEpisodePersistence.write(errorCode, mark);
        }
    }

    private static void persist(@NonNull String errorCode, @NonNull Record record) {
        WarnMark mark = WarnEpisodePersistence.read(errorCode);
        if (mark == null) {
            mark = WarnMark.create();
        }
        if (record.faultActive && mark.getWarnTime() <= 0) {
            mark.setWarnTime(System.currentTimeMillis());
        }
        mark.setWarn(record.faultActive)
                .setReminder(record.reminderPending)
                .setDialogOpen(record.dialogOpen)
                .setResistExternalAutoClose(
                        record.policy.resistsExternalAutoClose() && record.phase != Phase.OPERATOR_ACKED);
        if (record.reminderPending) {
            mark.setCloseReminderTime(-1);
        } else if (mark.getCloseReminderTime() <= 0) {
            mark.setCloseReminderTime(System.currentTimeMillis());
        }
        WarnEpisodePersistence.write(errorCode, mark);
    }

    @Nullable
    private static Record getOrHydrateRecord(@NonNull String errorCode) {
        Record record = EPISODES.get(errorCode);
        if (record != null) {
            return record;
        }
        WarnMark mark = WarnEpisodePersistence.read(errorCode);
        if (mark == null || !mark.isWarn()) {
            return null;
        }
        WarnEpisodePolicy policy = mark.isResistExternalAutoClose()
                ? WarnEpisodePolicy.productionResist()
                : WarnEpisodePolicy.productionPassive();
        record = new Record(policy);
        record.faultActive = true;
        record.reminderPending = mark.isReminder();
        record.dialogOpen = mark.isDialogOpen();
        record.phase = mark.isReminder() ? Phase.FAULT_ACTIVE : Phase.OPERATOR_ACKED;
        EPISODES.put(errorCode, record);
        return record;
    }

    /** Avoid circular import with laser guard; bypassable trio only. */
    static final class LaserEnableAlarmGuardCompat {
        private LaserEnableAlarmGuardCompat() {
        }

        static boolean isBypassable(@NonNull String code) {
            return com.lasercyber.lws.ui.common.constant.AlarmCodeConstants.ALARM_A001.equals(code)
                    || com.lasercyber.lws.ui.common.constant.AlarmCodeConstants.ALARM_C002.equals(code)
                    || com.lasercyber.lws.ui.common.constant.AlarmCodeConstants.ALARM_L001.equals(code)
                    || com.lasercyber.lws.ui.common.constant.AlarmCodeConstants.ALARM_W001.equals(code)
                    || com.lasercyber.lws.ui.common.constant.AlarmCodeConstants.ALARM_W002.equals(code);
        }
    }
}
