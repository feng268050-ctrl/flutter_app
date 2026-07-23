package com.lasercyber.lws.ui.common.handler;

import android.content.Context;
import android.text.TextUtils;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ai.stain.StainDetectAlertMapper;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.WarnTableViewModel;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserEnableAlarmGuard;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserWorkGuard;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.bean.event.LensCheckResultEvent;
import com.lasercyber.lws.ui.common.boot.BootSelfCheckGate;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodePolicy;
import com.lasercyber.lws.ui.common.constant.AlarmCodeConstants;
import com.lasercyber.lws.ui.common.weld.WeldAlertScope;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;
import org.json.JSONObject;

import java.util.Locale;

/**
 * Live weld lens heavy contamination ({@link AlarmCodeConstants#ALARM_L001}), driven by
 * {@link LensCheckResultEvent} from RKNN or live OpenCV stain detect.
 */
public final class LensHeavyContaminationWarnAlarm {

    private static final String TAG = "LensHeavyWarnAlarm";
    public static final LensHeavyContaminationWarnAlarm INSTANCE = new LensHeavyContaminationWarnAlarm();

    private final WarnTableViewModel warnTableViewModel = new WarnTableViewModel();

    private boolean dialogAcknowledgedThisBoot;
    private boolean unresolvedHeavyEpisode;
    @Nullable
    private String latestMessage;
    @Nullable
    private Context appContext;
    private boolean started;

    private LensHeavyContaminationWarnAlarm() {
    }

    public synchronized void start(@NonNull Context context) {
        if (started) {
            return;
        }
        appContext = context.getApplicationContext();
        EventBus.getDefault().register(this);
        started = true;
    }

    public synchronized void stop() {
        if (!started) {
            return;
        }
        EventBus.getDefault().unregister(this);
        resetForStop();
        started = false;
        appContext = null;
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onLensCheckResult(LensCheckResultEvent event) {
        if (event == null || appContext == null) {
            return;
        }
        handleLensCheckResult(event, appContext);
        if (LaserEnableAlarmGuard.isLensBlocking(appContext)) {
            LaserWorkGuard.evaluateAndInterruptIfNeeded(appContext);
        }
    }

    public synchronized void onFaultCleared() {
        latestMessage = null;
        unresolvedHeavyEpisode = false;
        GpioLedHandler.refresh();
    }

    /**
     * Staging/debug ({@code make alarm-clean}): end the current L001 episode without disabling stain
     * detect. Clears laser-enable block and resets per-boot dialog ack so the next heavy-detect
     * cycle may show a fresh passive dialog. Unlike {@link #onFaultCleared()}, also clears
     * {@code dialogAcknowledgedThisBoot}.
     */
    public synchronized void clearUnresolvedEpisodeForDebug() {
        latestMessage = null;
        unresolvedHeavyEpisode = false;
        dialogAcknowledgedThisBoot = false;
        Log.i(TAG, "clearUnresolvedEpisodeForDebug: L001 episode cleared for debug");
    }

    public synchronized boolean isLaserEnableBlocked() {
        return unresolvedHeavyEpisode;
    }

    @Nullable
    public synchronized WarnDialogVo buildLaserEnableBlockDialogVo(@NonNull Context context) {
        if (!unresolvedHeavyEpisode) {
            return null;
        }
        return buildDialogVo(context.getApplicationContext());
    }

    public synchronized void onDialogDismissed(@NonNull Context context) {
        onFaultCleared();
        dialogAcknowledgedThisBoot = false;
    }

    synchronized void handleLensCheckResult(@NonNull LensCheckResultEvent event, @NonNull Context context) {
        if (event.getLevel() == 1) {
            return;
        }
        if (event.getLevel() <= 0) {
            onFaultCleared();
            return;
        }
        if (event.getLevel() < 2 || StainDetectAlertMapper.isOfflineStainDetectMessage(event.getMessage())) {
            return;
        }
        if (!WeldAlertScope.isEligibleFromTopActivity()) {
            return;
        }
        latestMessage = resolveDisplayMessage(context, event.getMessage());
        unresolvedHeavyEpisode = true;
        warnTableViewModel.saveLensHeavyContaminationWarnLog(context, latestMessage);
        GpioLedHandler.refresh();
        showPassiveDialogIfNeeded(context);
    }

    @VisibleForTesting
    public synchronized void resetForStop() {
        latestMessage = null;
        dialogAcknowledgedThisBoot = false;
        unresolvedHeavyEpisode = false;
    }

    /** Visible to unit tests. */
    @VisibleForTesting
    public synchronized void armPendingForTest() {
        unresolvedHeavyEpisode = true;
    }

    /** Visible to unit tests. */
    @VisibleForTesting
    public synchronized void acknowledgeDialogForTest() {
        dialogAcknowledgedThisBoot = true;
    }

    private synchronized void showPassiveDialogIfNeeded(@NonNull Context context) {
        if (BootSelfCheckGate.isActive()) {
            return;
        }
        if (dialogAcknowledgedThisBoot || !unresolvedHeavyEpisode) {
            return;
        }
        if (!WeldAlertScope.isEligibleFromTopActivity()) {
            return;
        }
        Context app = context.getApplicationContext();
        WarnDialogVo vo = buildDialogVo(app);
        if (vo == null) {
            return;
        }
        WarnEpisodeController.notifyFaultActive(
                AlarmCodeConstants.ALARM_L001, WarnEpisodePolicy.productionResist());
        DeviceDialogHandler.showPassiveWarnDialog(vo);
    }

    @Nullable
    private WarnDialogVo buildDialogVo(@NonNull Context app) {
        WarnDialogVo vo = new WarnDialogVo();
        vo.setType(WarnDialogSeverity.dialogTypeForCode(AlarmCodeConstants.ALARM_L001, app));
        vo.setTitle(app.getString(R.string.lens_heavy_contamination_alarm_title));
        vo.setContent(buildDialogContent(app, latestMessage));
        vo.setButtonText(app.getString(R.string.confirm_text));
        vo.setIsShowProgress(false);
        vo.setErrorCode(AlarmCodeConstants.ALARM_L001);
        vo.setResistExternalAutoClose(true);
        vo.setOnConfirm(() -> onDialogDismissed(app));
        return vo;
    }

    @NonNull
    private static String buildDialogContent(@NonNull Context app, @Nullable String message) {
        if (TextUtils.isEmpty(message)) {
            return app.getString(R.string.lens_alert_heavy_body_default);
        }
        return message;
    }

    @NonNull
    private static String resolveDisplayMessage(@NonNull Context app, @Nullable String rawMessage) {
        if (TextUtils.isEmpty(rawMessage)) {
            return app.getString(R.string.lens_alert_heavy_body_default);
        }
        String message = rawMessage.trim();
        if (!message.startsWith("{")) {
            return localizeDisplayMessage(app, message);
        }
        try {
            JSONObject root = new JSONObject(message);
            String human = root.optString("message", "");
            if (!TextUtils.isEmpty(human.trim())) {
                return localizeDisplayMessage(app, human.trim());
            }
            String status = root.optString("status", "");
            if (!TextUtils.isEmpty(status.trim())) {
                return localizeDisplayMessage(app, status.trim());
            }
        } catch (Exception e) {
            Log.w(TAG, "resolveDisplayMessage skipped non-json message");
        }
        return app.getString(R.string.lens_alert_heavy_body_default);
    }

    @NonNull
    private static String localizeDisplayMessage(@NonNull Context app, @Nullable String message) {
        if (TextUtils.isEmpty(message)) {
            return app.getString(R.string.lens_alert_heavy_body_default);
        }
        if (isStatusToken(message)) {
            return app.getString(R.string.lens_alert_heavy_body_default);
        }
        if (!isChineseUi() && containsCjk(message)) {
            return app.getString(R.string.lens_alert_heavy_body_default);
        }
        return message;
    }

    private static boolean isChineseUi() {
        Locale locale = SystemSettingUtils.getLanguage();
        return locale != null && locale.getLanguage() != null
                && locale.getLanguage().toLowerCase(Locale.ROOT).startsWith("zh");
    }

    private static boolean isStatusToken(String message) {
        String normalized = message.trim().toUpperCase(Locale.ROOT);
        return "HEAVY".equals(normalized)
                || "MILD".equals(normalized)
                || "CLEAN".equals(normalized)
                || "STAIN_HEAVY".equals(normalized)
                || "STAIN_MILD".equals(normalized);
    }

    private static boolean containsCjk(String message) {
        for (int i = 0; i < message.length(); i++) {
            Character.UnicodeScript script = Character.UnicodeScript.of(message.charAt(i));
            if (script == Character.UnicodeScript.HAN) {
                return true;
            }
        }
        return false;
    }
}
