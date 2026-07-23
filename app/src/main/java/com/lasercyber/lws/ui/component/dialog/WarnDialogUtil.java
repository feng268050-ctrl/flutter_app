package com.lasercyber.lws.ui.component.dialog;

import android.app.Activity;
import android.content.Context;
import android.content.DialogInterface;
import android.content.res.Resources;
import android.graphics.Color;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.frostui.border.FrostTone;
import com.lasercyber.lws.frostui.dialog.FrostOverlayHost;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.frostui.button.interop.FrostButtonView;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.component.dialog.episode.WarnEpisodeController;
import com.lasercyber.lws.ui.common.utils.WarnUtil;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.common.view.WarnProgressView;

import java.lang.ref.WeakReference;
import java.util.Objects;

public class WarnDialogUtil {

    private static final String TAG = LogTAGConstant.WarnDialogUtil;
    private static final float WARN_DIALOG_MAX_WIDTH_FRACTION = 0.95f;
    private static final float WARN_DIALOG_PROGRESS_MIN_WIDTH_FRACTION = 0.9f;

    @Nullable
    private static WeakReference<FrostDialog.Handle> sHandleRef;
    private static boolean status = false;
    private static volatile boolean singleOpen = false;

    @Nullable
    private static WarnDialogVo sActiveVo;
    @Nullable
    private static DialogInterface.OnDismissListener sActiveDismissListener;

    /** Whether closing the overlay ends the warn episode (sound + queue) or only detaches for handoff. */
    private enum SessionEndReason {
        TERMINAL,
        OVERLAY_HANDOFF
    }

    private static SessionEndReason sSessionEndReason = SessionEndReason.TERMINAL;

    private WarnDialogUtil() {
    }

    /**
     * 显示全局告警弹窗；若已有弹窗则先关闭再展示新的。
     *
     * @return {@code false} 表示本次展示前已存在弹窗并被替换
     */
    public static Boolean showStatusDialog(Context context, WarnDialogVo vo) {
        boolean isOpen = true;
        if (isHandleShowing()) {
            status = false;
            isOpen = false;
            closeDialogForHandoff();
        }
        if (openDialog(context, vo, dialog -> status = false, null)) {
            status = true;
        }
        return isOpen;
    }

    public static boolean openDialog(
            Context context,
            WarnDialogVo vo,
            DialogInterface.OnDismissListener listener,
            DialogInterface.OnShowListener showListener) {
        Activity activity = resolveActivity(context);
        if (activity == null) {
            updateSingleOpen(false);
            return false;
        }

        String incomingCode = vo.getErrorCode();
        String activeCode = getActiveErrorCode();

        if (!StringUtils.isEmpty(activeCode) && WarnEpisodeController.resistsExternalAutoClose(activeCode)) {
            if (isHandleShowing()) {
                if (activeCode.equals(incomingCode)) {
                    playWarnSoundIfNeeded(activity, vo);
                    return true;
                }
                Log.d(TAG, "openDialog: resist episode " + activeCode + " visible, defer " + incomingCode);
                return false;
            }
            if (!activeCode.equals(incomingCode)) {
                Log.d(TAG, "openDialog: resist episode " + activeCode + " pending, defer " + incomingCode);
                return false;
            }
            Log.w(TAG, "openDialog: reattaching resist episode " + activeCode);
            sHandleRef = null;
        } else {
            if (isShowingErrorCode(incomingCode)) {
                playWarnSoundIfNeeded(activity, vo);
                return true;
            }
            if (resistsProgrammaticClose(incomingCode) && isDialogShowing()) {
                Log.d(TAG, "openDialog: resist episode visible, skip refresh " + incomingCode);
                playWarnSoundIfNeeded(activity, vo);
                return true;
            }
            if (isHandleShowing()
                    && sActiveVo != null
                    && !StringUtils.isEmpty(incomingCode)
                    && !StringUtils.isEmpty(activeCode)
                    && !incomingCode.equals(activeCode)) {
                Log.d(TAG, "openDialog: keep visible warn " + activeCode + ", defer " + incomingCode);
                return false;
            }
            endActiveSessionSynchronously();
        }

        sActiveVo = vo;
        sActiveDismissListener = listener;

        if (!StringUtils.isEmpty(vo.getJumpButtonText())) {
            return openDualActionDialog(activity, context, vo, showListener);
        }

        FrostDialog.Handle handle = FrostPromptDialog.builder(activity)
                .widthPx(resolveWarnDialogWidthPx(activity, vo))
                .replaceExistingIfOccupied(true)
                .dismissOnScrimClick(false)
                .body(body -> bindBody(body, context, vo))
                .confirmText(resolveConfirmText(context, vo))
                .onConfirm(() -> {
                    acknowledgeOperatorDismiss(vo);
                    Runnable onConfirm = vo.getOnConfirm();
                    if (onConfirm != null) {
                        onConfirm.run();
                    }
                    updateSingleOpen(false);
                    dismissActiveDialog();
                })
                .onDismiss(WarnDialogUtil::handleDismiss)
                .show();
        if (handle == null) {
            Log.w(TAG, "openDialog: failed to attach warn overlay");
            stopWarnSoundForVo(vo);
            clearActiveSession();
            updateSingleOpen(false);
            return false;
        }

        sHandleRef = new WeakReference<>(handle);
        status = true;
        markOverlayProtected(handle.getRootView(), vo.getErrorCode());
        playWarnSoundIfNeeded(activity, vo);
        if (showListener != null) {
            showListener.onShow(null);
        }
        return true;
    }

    private static boolean openDualActionDialog(
            @NonNull Activity activity,
            @NonNull Context context,
            @NonNull WarnDialogVo vo,
            @Nullable DialogInterface.OnShowListener showListener) {
        final int actionTextColor = vo.getType() == WarnUtil.INFO_TYPE
                ? Color.parseColor("#FF9900")
                : Color.RED;
        FrostDialog.Handle handle = FrostDialog.prompt(activity)
                .tone(FrostTone.LIGHT)
                .minHeightDimen(R.dimen.frost_dialog_prompt_min_height)
                .expandBodyScroll(false)
                .showTitle(false)
                .showActionBar(true)
                .autoDismissOnConfirm(false)
                .dismissOnScrimClick(false)
                .replaceExistingIfOccupied(true)
                .widthPx(resolveWarnDialogWidthPx(activity, vo))
                .customBodyView(R.layout.dialog_frost_body_prompt,
                        body -> bindBody(body, context, vo))
                .customActionBarView(R.layout.dialog_frost_action_warn_dual, action -> {
                    FrostPromptDialog.applyPromptShellInsets(action, false);
                    FrostPromptDialog.clearActionSectionTopMargin(action);
                    FrostButtonView confirm = action.findViewById(R.id.btn_confirm);
                    FrostButtonView jump = action.findViewById(R.id.btn_jump);
                    if (confirm != null) {
                        confirm.setText(resolveConfirmText(context, vo));
                        confirm.setTextColor(actionTextColor);
                        confirm.setOnClickListener(v -> runVoActionAndDismiss(vo.getOnConfirm()));
                    }
                    if (jump != null) {
                        jump.setText(vo.getJumpButtonText());
                        jump.setTextColor(actionTextColor);
                        jump.setOnClickListener(v -> runVoActionAndDismiss(vo.getOnJump()));
                    }
                })
                .onDismiss(WarnDialogUtil::handleDismiss)
                .show();
        if (handle == null) {
            Log.w(TAG, "openDualActionDialog: failed to attach warn overlay");
            stopWarnSoundForVo(vo);
            clearActiveSession();
            updateSingleOpen(false);
            return false;
        }
        sHandleRef = new WeakReference<>(handle);
        status = true;
        markOverlayProtected(handle.getRootView(), vo.getErrorCode());
        playWarnSoundIfNeeded(activity, vo);
        if (showListener != null) {
            showListener.onShow(null);
        }
        return true;
    }

    private static void runVoActionAndDismiss(@Nullable Runnable action) {
        WarnDialogVo vo = sActiveVo;
        if (vo != null) {
            acknowledgeOperatorDismiss(vo);
        }
        if (action != null) {
            action.run();
        }
        updateSingleOpen(false);
        dismissActiveDialog();
    }

    /**
     * Operator tapped confirm/jump on a coded warn dialog. Clears demo-sticky and reminder state
     * that must not run on programmatic session replacement (e.g. laser-enable re-show).
     */
    static void acknowledgeOperatorDismiss(@NonNull WarnDialogVo vo) {
        if (StringUtils.isEmpty(vo.getErrorCode())) {
            return;
        }
        WarnEpisodeController.acknowledgeOperator(vo.getErrorCode());
    }

    private static void playWarnSoundIfNeeded(@NonNull Activity activity, @NonNull WarnDialogVo vo) {
        if (vo.getType() != WarnUtil.WARN_TYPE) {
            return;
        }
        GlobalSoundManager.ensureInitialized(activity);
        GlobalSoundManager.ensureWarnSoundPlaying(vo.getErrorCode());
    }

    public static void closeDialog() {
        closeDialogTerminal();
    }

    private static void closeDialogForHandoff() {
        sSessionEndReason = SessionEndReason.OVERLAY_HANDOFF;
        dismissOverlayIfShowing();
    }

    private static void closeDialogTerminal() {
        WarnDialogVo vo = sActiveVo;
        if (vo != null && WarnEpisodeController.resistsExternalAutoClose(vo.getErrorCode())) {
            Log.d(TAG, "closeDialogTerminal: blocked for resist episode " + vo.getErrorCode());
            return;
        }
        sSessionEndReason = SessionEndReason.TERMINAL;
        dismissOverlayIfShowing();
    }

    private static void dismissOverlayIfShowing() {
        FrostDialog.Handle handle = sHandleRef != null ? sHandleRef.get() : null;
        if (handle != null && handle.isShowing()) {
            if (sSessionEndReason == SessionEndReason.TERMINAL) {
                handle.dismissImmediate();
            } else {
                handle.dismiss();
            }
            return;
        }
        if (sSessionEndReason == SessionEndReason.TERMINAL) {
            FrostDialog.dismissImmediate();
        } else {
            FrostDialog.dismiss();
        }
        finishSessionAfterOverlayClosed();
        status = false;
    }

    /**
     * Called by {@link WarnEpisodeController} when episode teardown is authorized.
     */
    public static boolean dismissOverlayForCode(@Nullable String errorCode) {
        if (StringUtils.isEmpty(errorCode)
                || WarnEpisodeController.resistsExternalAutoClose(errorCode)) {
            return false;
        }
        if (isShowingErrorCode(errorCode)) {
            return dismissActiveWarnOverlayTerminal();
        }
        // Frost overlay can outlive the WeakReference handle on embedded devices.
        if (errorCode.equals(getActiveErrorCode()) && isWarnOverlayVisible()) {
            return dismissActiveWarnOverlayTerminal();
        }
        return false;
    }

    private static boolean isWarnOverlayVisible() {
        return isHandleShowing() || status || FrostDialog.isShowing();
    }

    private static boolean dismissActiveWarnOverlayTerminal() {
        sSessionEndReason = SessionEndReason.TERMINAL;
        dismissOverlayIfShowing();
        return true;
    }

    /**
     * Dismisses the global warn overlay when it is showing the given alarm code (e.g. C002 recovery).
     *
     * @return {@code true} when a matching dialog was dismissed
     */
    public static boolean dismissIfShowingErrorCode(@Nullable String errorCode) {
        if (StringUtils.isEmpty(errorCode)) {
            return false;
        }
        if (WarnEpisodeController.resistsExternalAutoClose(errorCode)) {
            return false;
        }
        return dismissOverlayForCode(errorCode);
    }

    /** Ends the current session synchronously before opening a replacement dialog. */
    private static void endActiveSessionSynchronously() {
        if (sActiveVo != null && WarnEpisodeController.resistsExternalAutoClose(sActiveVo.getErrorCode())) {
            Log.d(TAG, "endActiveSession: blocked for resist episode " + sActiveVo.getErrorCode());
            return;
        }
        sSessionEndReason = SessionEndReason.OVERLAY_HANDOFF;
        FrostDialog.Handle handle = sHandleRef != null ? sHandleRef.get() : null;
        if (handle != null && handle.isShowing()) {
            handle.dismissImmediate();
            return;
        }
        if (sActiveDismissListener != null) {
            finishSessionAfterOverlayClosed();
        } else {
            clearActiveSession();
        }
        status = false;
    }

    private static void finishSessionAfterOverlayClosed() {
        WarnDialogVo vo = sActiveVo;
        stopWarnSoundForVo(vo);
        if (sSessionEndReason == SessionEndReason.OVERLAY_HANDOFF
                && vo != null
                && !StringUtils.isEmpty(vo.getErrorCode())
                && !WarnEpisodeController.resistsExternalAutoClose(vo.getErrorCode())) {
            WarnEpisodeController.rearmReminderAfterOverlayHandoff(vo.getErrorCode());
        }
        DialogInterface.OnDismissListener listener = sActiveDismissListener;
        clearActiveSession();
        sSessionEndReason = SessionEndReason.TERMINAL;
        if (listener != null) {
            listener.onDismiss(null);
        }
        syncWarnSoundToOverlay();
    }

    private static void stopWarnSoundForVo(@Nullable WarnDialogVo vo) {
        if (vo != null && vo.getType() == WarnUtil.WARN_TYPE) {
            GlobalSoundManager.stopWarnSoundForEpisode(vo.getErrorCode());
        }
    }

    /** Coded warn audio must not outlive the visible overlay. */
    private static void syncWarnSoundToOverlay() {
        if (!isDialogShowing() && GlobalSoundManager.isCodedWarnSoundEpisodeActive()) {
            GlobalSoundManager.stopWarnSound();
        }
    }

    /**
     * Called before Frost replaces overlays outside {@link WarnDialogUtil} so dismiss is a handoff, not terminal.
     */
    public static void beginExternalOverlayReplace() {
        if (isDialogShowing()) {
            sSessionEndReason = SessionEndReason.OVERLAY_HANDOFF;
        }
    }

    /** Demo / resist episodes must not be torn down by Frost {@code dismissAllOnActivity}. */
    public static boolean blocksExternalOverlayDismiss() {
        return WarnEpisodeController.blocksExternalOverlayDismiss();
    }

    /** Frost {@link FrostOverlayHost#dismissAllOnActivity} must skip resist warn overlays. */
    public static boolean shouldProtectOverlay(@Nullable View overlay) {
        return WarnEpisodeController.shouldProtectOverlay(overlay);
    }

    private static void markOverlayProtected(@Nullable View root, @Nullable String errorCode) {
        if (root == null || StringUtils.isEmpty(errorCode)
                || !WarnEpisodeController.resistsExternalAutoClose(errorCode)) {
            return;
        }
        root.setTag(R.id.tag_warn_overlay_resist_code, errorCode);
    }

    private static void clearOverlayProtection(@Nullable View root) {
        if (root != null) {
            root.setTag(R.id.tag_warn_overlay_resist_code, null);
        }
    }

    public static boolean resistsProgrammaticClose(@Nullable String errorCode) {
        return WarnEpisodeController.resistsExternalAutoClose(errorCode);
    }

    /** Native AI {@code onAlert(0)} must not stop coded warn dialog audio while the overlay is visible. */
    public static boolean shouldDeferNativeAlertSoundStop() {
        return isSeriousDialogAwaitingConfirm();
    }

    public static boolean updateSingleOpen(boolean value) {
        if (singleOpen == value) {
            return false;
        }
        synchronized (WarnDialogUtil.class) {
            if (singleOpen == value) {
                return false;
            }
            singleOpen = value;
            return true;
        }
    }

    public static void singleOpenDialog(Context context, WarnDialogVo vo, boolean checkOpen) {
        if (checkOpen) {
            WarnEpisodeController.requestPassiveShow(context, vo);
        } else {
            Activity activity = context instanceof Activity a ? a : null;
            if (activity != null) {
                WarnEpisodeController.requestImmediateShow(activity, vo);
            }
        }
    }

    public static void onDestroy() {
        closeDialog();
        status = false;
        singleOpen = false;
        sHandleRef = null;
        clearActiveSession();
    }

    private static void bindBody(@NonNull View body, @NonNull Context context, @NonNull WarnDialogVo vo) {
        android.widget.ImageView iconView = body.findViewById(R.id.prompt_icon);
        TextView titleView = body.findViewById(R.id.prompt_title);
        TextView contentView = body.findViewById(R.id.prompt_content);
        WarnProgressView progressView = body.findViewById(R.id.prompt_progress);

        titleView.setText(resolveTitle(context, vo));
        contentView.setText(vo.getContent());

        boolean isInfo = vo.getType() == WarnUtil.INFO_TYPE;
        titleView.setTextColor(isInfo ? Color.BLACK : Color.RED);
        iconView.setImageResource(
                vo.getType() == WarnUtil.WARN_TYPE ? R.mipmap.alarm_warn_icon : R.mipmap.alarm_info_icon);

        boolean showProgress = Boolean.TRUE.equals(vo.getIsShowProgress());
        progressView.setVisibility(showProgress ? View.VISIBLE : View.GONE);
        if (contentView.getLayoutParams() instanceof android.widget.LinearLayout.LayoutParams contentLp) {
            if (showProgress) {
                contentLp.width = 0;
                contentLp.weight = 1f;
            } else {
                contentLp.width = ViewGroup.LayoutParams.MATCH_PARENT;
                contentLp.weight = 0f;
            }
            int progressGap = body.getResources().getDimensionPixelSize(R.dimen.engineer_mode_entry_section_spacing);
            contentLp.setMarginStart(showProgress ? progressGap : 0);
            contentView.setLayoutParams(contentLp);
        }
        if (showProgress) {
            progressView.setProgress(
                    vo.getProgress(),
                    vo.getUnit(),
                    vo.getProTitle(),
                    vo.getProContent(),
                    vo.getMax(),
                    new int[]{
                            Color.parseColor("#00C853"),
                            Color.parseColor("#FFA500"),
                            Color.parseColor("#FF4444"),
                            Color.parseColor("#00C853")
                    });
        }
    }

    @NonNull
    private static String resolveTitle(@NonNull Context context, @NonNull WarnDialogVo vo) {
        String title = vo.getTitle();
        if (title != null) {
            return title;
        }
        return vo.getType() == WarnUtil.WARN_TYPE
                ? context.getString(R.string.security_alert_title)
                : context.getString(R.string.gas_pressure_low_title);
    }

    private static int resolveWarnDialogWidthPx(@NonNull Context context, @NonNull WarnDialogVo vo) {
        Resources resources = context.getResources();
        int screenWidth = resources.getDisplayMetrics().widthPixels;
        int minWidth = FrostPromptDialog.standardWidthPx(context);
        int maxWidth = Math.max(minWidth, Math.round(screenWidth * WARN_DIALOG_MAX_WIDTH_FRACTION));
        int titleWidth = FrostPromptDialog.resolveTitleBasedWidthPx(context, resolveTitle(context, vo));
        int resolved = Math.max(minWidth, titleWidth);
        if (Boolean.TRUE.equals(vo.getIsShowProgress())) {
            int progressFloor = Math.round(screenWidth * WARN_DIALOG_PROGRESS_MIN_WIDTH_FRACTION);
            resolved = Math.max(resolved, progressFloor);
        }
        return Math.min(maxWidth, resolved);
    }

    @NonNull
    private static CharSequence resolveConfirmText(@NonNull Context context, @NonNull WarnDialogVo vo) {
        String buttonText = vo.getButtonText();
        if (StringUtils.isEmpty(buttonText)) {
            return context.getString(R.string.confirm_text);
        }
        return buttonText;
    }

    private static void dismissActiveDialog() {
        sSessionEndReason = SessionEndReason.TERMINAL;
        FrostDialog.Handle handle = sHandleRef != null ? sHandleRef.get() : null;
        if (handle != null && handle.isShowing()) {
            handle.dismiss();
            return;
        }
        closeDialogTerminal();
    }

    private static void handleDismiss() {
        status = false;
        WarnDialogVo vo = sActiveVo;
        View root = sHandleRef != null && sHandleRef.get() != null
                ? sHandleRef.get().getRootView() : null;
        if (vo != null
                && WarnEpisodeController.resistsExternalAutoClose(vo.getErrorCode())
                && sSessionEndReason != SessionEndReason.TERMINAL) {
            clearOverlayProtection(root);
            Log.d(TAG, "handleDismiss: blocked for resist episode " + vo.getErrorCode());
            status = isHandleShowing();
            return;
        }
        clearOverlayProtection(root);
        finishSessionAfterOverlayClosed();
    }

    private static void clearActiveSession() {
        sActiveVo = null;
        sActiveDismissListener = null;
        if (sHandleRef != null) {
            sHandleRef.clear();
            sHandleRef = null;
        }
    }

    @Nullable
    private static Activity resolveActivity(@NonNull Context context) {
        if (context instanceof Activity activity) {
            if (activity.isFinishing() || activity.isDestroyed()) {
                return null;
            }
            return activity;
        }
        Activity top = FrostOverlayHost.findActivity(context);
        if (top == null || top.isFinishing() || top.isDestroyed()) {
            return null;
        }
        return top;
    }

    private static boolean isHandleShowing() {
        FrostDialog.Handle handle = sHandleRef != null ? sHandleRef.get() : null;
        return handle != null && handle.isShowing();
    }

    /** {@code true} when a coded alarm / warn overlay is visible (used to avoid displacing it). */
    public static boolean isDialogShowing() {
        return isHandleShowing();
    }

    @Nullable
    public static String getActiveErrorCode() {
        return sActiveVo != null ? sActiveVo.getErrorCode() : null;
    }

    public static boolean isShowingErrorCode(@Nullable String errorCode) {
        if (StringUtils.isEmpty(errorCode)) {
            return false;
        }
        return isHandleShowing() && errorCode.equals(getActiveErrorCode());
    }

    /**
     * Staging/debug only: dismiss the visible warn overlay even when the episode resists external
     * auto-close (demo / resist alarms). Not used by {@code make alarm-clean} (that keeps the popup).
     */
    public static void forceDismissForDebugClean() {
        sSessionEndReason = SessionEndReason.TERMINAL;
        FrostDialog.Handle handle = sHandleRef != null ? sHandleRef.get() : null;
        View root = handle != null ? handle.getRootView() : null;
        clearOverlayProtection(root);
        if (handle != null && handle.isShowing()) {
            handle.dismissImmediate();
        } else {
            FrostDialog.dismiss();
        }
        status = false;
        stopWarnSoundForVo(sActiveVo);
        clearActiveSession();
        syncWarnSoundToOverlay();
    }

    /** Visible serious alarm awaiting operator confirm on the primary button. */
    public static boolean isSeriousDialogAwaitingConfirm() {
        WarnDialogVo vo = sActiveVo;
        return isHandleShowing()
                && vo != null
                && Objects.equals(vo.getType(), WarnUtil.WARN_TYPE);
    }
}
