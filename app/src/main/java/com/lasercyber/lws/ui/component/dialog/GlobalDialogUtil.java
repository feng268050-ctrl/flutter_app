package com.lasercyber.lws.ui.component.dialog;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Bitmap;
import android.util.Log;
import android.util.TypedValue;
import android.view.View;
import android.widget.ImageView;
import android.widget.RadioGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.widget.AppCompatRadioButton;
import androidx.core.content.ContextCompat;

import com.lasercyber.lws.frostui.dialog.FrostOverlayHost;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.boot.BootSelfCheckCoordinator;
import com.lasercyber.lws.ui.common.boot.BootSelfCheckGate;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.lang.ref.WeakReference;
import java.util.function.Consumer;

/** Global HMI prompts backed by {@link FrostDialog}. */
public class GlobalDialogUtil {
    private static final String TAG = LogTAGConstant.GlobalDialogUtil;

    private volatile static WeakReference<FrostDialog.Handle> sDialogRef;
    private volatile static WeakReference<FrostDialog.Handle> sWifiInitDialogRef;
    private volatile static WeakReference<FrostDialog.Handle> sBundledFirmwareDialogRef;
    private volatile static WeakReference<FrostDialog.Handle> sBindDeviceDialogRef;
    private volatile static WeakReference<FrostDialog.Handle> sDeviceRegistrationDialogRef;
    private volatile static WeakReference<FrostDialog.Handle> sRemoteLockDialogRef;

    private volatile static boolean status = false;
    private static volatile boolean singletonOpenStatus = false;

    public static boolean isWifiInitializationDialogShowing() {
        return isHandleShowing(sWifiInitDialogRef);
    }

    /**
     * @param isSuccess 0 failure; 1 success; 2 waiting (dismissible); 3 blocking firmware progress
     */
    public static Boolean showStatusDialog(Context context, int isSuccess, String title, String content) {
        return showStatusDialog(context, isSuccess, title, content, null);
    }

    public static Boolean showStatusDialog(
            Context context,
            int isSuccess,
            String title,
            String content,
            @Nullable Runnable onDismissed) {
        if (deferDuringBootSelfCheck()) {
            return false;
        }
        if (WarnDialogUtil.isDialogShowing()) {
            Log.d(TAG, "defer status dialog while warn dialog is visible");
            return false;
        }
        if (context == null || (context instanceof android.app.Activity act && act.isFinishing())) {
            return false;
        }
        Boolean shown = FrostStatusDialog.show(context, isSuccess, title, content, onDismissed);
        if (Boolean.TRUE.equals(shown)) {
            status = true;
        }
        return shown;
    }

    public static void dismissBlockingStatusAndShowResult(
            Context context, int isSuccess, String title, String content) {
        dismissBlockingStatusAndShowResult(context, isSuccess, title, content, null);
    }

    public static void dismissBlockingStatusAndShowResult(
            Context context,
            int isSuccess,
            String title,
            String content,
            @Nullable Runnable onDismissed) {
        closeDialog();
        showStatusDialog(context, isSuccess, title, content, onDismissed);
    }

    public static void updateFirmwareUpgradeProgress(int percent) {
        FrostStatusDialog.updateFirmwareProgress(percent);
    }

    public static void closeDialog() {
        FrostStatusDialog.dismissActive();
        markStatusClosed();
        clearDialogRef(sDialogRef);
    }

    /** Called when the frosted-glass status overlay is dismissed. */
    static void markStatusClosed() {
        status = false;
        singletonOpenStatus = false;
    }

    public static void onDestroy() {
        closeDialog();
        resetAllDialogHandles();
    }

    /** Tear down overlays and dialog handles when an Activity is destroyed. */
    public static void onActivityDestroyed(@NonNull android.app.Activity activity) {
        clearHandleRefIfHost(activity, sDialogRef);
        clearHandleRefIfHost(activity, sWifiInitDialogRef);
        clearHandleRefIfHost(activity, sBundledFirmwareDialogRef);
        clearHandleRefIfHost(activity, sBindDeviceDialogRef);
        clearHandleRefIfHost(activity, sDeviceRegistrationDialogRef);
        clearHandleRefIfHost(activity, sRemoteLockDialogRef);
        FrostStatusDialog.onActivityDestroyed(activity);
        FrostOverlayHost.onActivityDestroyed(activity);
        BootSelfCheckCoordinator.onHostDestroyed(activity);
        AutoDialogQueue.get().onActivityDestroyed(activity);
        markStatusClosed();
        singletonOpenStatus = false;
    }

    public static void singletonOpen(Context context, int isSuccess, String title, String content) {
        if (singletonOpenStatus) {
            return;
        }
        synchronized (GlobalDialogUtil.class) {
            if (singletonOpenStatus) {
                return;
            }
            singletonOpenStatus = true;
            try {
                if (!Boolean.TRUE.equals(showStatusDialog(context, isSuccess, title, content))) {
                    singletonOpenStatus = false;
                }
            } catch (Exception exception) {
                singletonOpenStatus = false;
                Log.d(TAG, "singletonOpen failed", exception);
            }
        }
    }

    public static boolean showSelectAppEnvDialog(
            Context context,
            String title,
            String[] labels,
            int checkedIndex,
            Consumer<Integer> onOptionChosen) {
        if (deferDuringBootSelfCheck()) {
            return false;
        }
        dismissIfOtherShowing(sDialogRef);
        if (context == null || (context instanceof android.app.Activity act && act.isFinishing())) {
            return false;
        }
        if (labels == null || labels.length == 0) {
            return false;
        }
        final FrostDialog.Handle[] dialogHandle = new FrostDialog.Handle[1];
        FrostDialog.Handle handle = FrostDialog.prompt(context)
                .replaceExistingIfOccupied(true)
                .title(title)
                .customBodyView(R.layout.dialog_frost_body_app_env, body -> {
                    RadioGroup rg = body.findViewById(R.id.rg_app_env_options);
                    if (rg == null) {
                        return;
                    }
                    rg.removeAllViews();
                    float density = context.getResources().getDisplayMetrics().density;
                    int padV = (int) (20 * density + 0.5f);
                    int padH = (int) (16 * density + 0.5f);
                    int accent = ContextCompat.getColor(context, R.color.side_tab_active_color);
                    ColorStateList textColors = ContextCompat.getColorStateList(context, R.color.app_env_radio_text);
                    int[] optionIds = new int[labels.length];
                    RadioGroup.LayoutParams lp = new RadioGroup.LayoutParams(
                            RadioGroup.LayoutParams.MATCH_PARENT,
                            RadioGroup.LayoutParams.WRAP_CONTENT);
                    for (int i = 0; i < labels.length; i++) {
                        AppCompatRadioButton rb = new AppCompatRadioButton(context);
                        rb.setText(labels[i]);
                        rb.setTextSize(TypedValue.COMPLEX_UNIT_SP, 32);
                        if (textColors != null) {
                            rb.setTextColor(textColors);
                        }
                        rb.setPadding(padH, padV, padH, padV);
                        rb.setButtonTintList(ColorStateList.valueOf(accent));
                        rb.setId(View.generateViewId());
                        optionIds[i] = rb.getId();
                        rg.addView(rb, lp);
                    }
                    final boolean[] listenerReady = {false};
                    rg.setOnCheckedChangeListener((group, checkedId) -> {
                        if (!listenerReady[0] || checkedId == View.NO_ID) {
                            return;
                        }
                        int idx = -1;
                        for (int j = 0; j < optionIds.length; j++) {
                            if (optionIds[j] == checkedId) {
                                idx = j;
                                break;
                            }
                        }
                        if (idx < 0) {
                            return;
                        }
                        if (dialogHandle[0] != null) {
                            dialogHandle[0].dismiss();
                        }
                        status = false;
                        if (onOptionChosen != null) {
                            onOptionChosen.accept(idx);
                        }
                    });
                    if (checkedIndex >= 0 && checkedIndex < labels.length) {
                        rg.check(optionIds[checkedIndex]);
                    }
                    listenerReady[0] = true;
                })
                .showConfirm(false)
                .cancelText(R.string.cancel_text)
                .onCancel(() -> status = false)
                .show();
        dialogHandle[0] = handle;
        if (handle == null) {
            status = false;
            return false;
        }
        status = true;
        sDialogRef = new WeakReference<>(handle);
        return true;
    }

    public static boolean showRemoteLockDialog(Context context, String title, String message) {
        return showRemoteLockDialog(context, title, message, null);
    }

    public static boolean showRemoteLockDialog(
            Context context,
            String title,
            String message,
            @Nullable Runnable onDismissed) {
        if (deferDuringBootSelfCheck()) {
            return false;
        }
        if (context == null) {
            return false;
        }
        if (context instanceof android.app.Activity act && (act.isFinishing() || act.isDestroyed())) {
            return false;
        }
        if (isHandleShowing(sRemoteLockDialogRef)) {
            return true;
        }
        clearStaleHandleRef(sRemoteLockDialogRef);
        FrostDialog.Handle handle = FrostDialog.prompt(context)
                .replaceExistingIfOccupied(false)
                .title(title)
                .message(message)
                .confirmText(R.string.ok_text)
                .showCancel(false)
                .showActionBar(true)
                .dismissOnScrimClick(true)
                .onConfirm(() -> clearHandleRef(sRemoteLockDialogRef))
                .onCancel(() -> clearHandleRef(sRemoteLockDialogRef))
                .onDismiss(onDismissed)
                .show();
        if (handle == null) {
            return false;
        }
        sRemoteLockDialogRef = new WeakReference<>(handle);
        return true;
    }

    public static void dismissRemoteLockDialog() {
        dismissHandleRef(sRemoteLockDialogRef);
        sRemoteLockDialogRef = null;
    }

    public static boolean showForcedDisconnectDialog(Context context, String title, String message) {
        return showForcedDisconnectDialog(context, title, message, null);
    }

    public static boolean showForcedDisconnectDialog(
            Context context,
            String title,
            String message,
            @Nullable Runnable onDismissed) {
        if (context == null) {
            return false;
        }
        if (context instanceof android.app.Activity act) {
            if (act.isFinishing() || act.isDestroyed()) {
                return false;
            }
        }
        return FrostDialog.prompt(context)
                .replaceExistingIfOccupied(false)
                .title(title)
                .message(message)
                .confirmText(R.string.ok_text)
                .showConfirm(true)
                .dismissOnScrimClick(false)
                .onDismiss(onDismissed)
                .show() != null;
    }

    public static boolean showFrostPromptDialog(
            Context context,
            String title,
            String message,
            String confirmText,
            String cancelText,
            Runnable onCancel,
            Runnable onConfirm) {
        return showFrostPromptDialog(
                context, title, message, confirmText, cancelText, true, onCancel, onConfirm);
    }

    public static boolean showFrostPromptDialog(
            Context context,
            String title,
            String message,
            @Nullable String confirmText,
            @Nullable String cancelText,
            boolean showCancel,
            Runnable onCancel,
            Runnable onConfirm) {
        if (deferDuringBootSelfCheck()) {
            return false;
        }
        FrostDialog.PromptBuilder builder = FrostDialog.prompt(context)
                .replaceExistingIfOccupied(true)
                .title(title)
                .message(message)
                .showTitle(true)
                .showActionBar(true)
                .showCancel(showCancel)
                .onCancel(onCancel)
                .onConfirm(onConfirm);
        if (confirmText != null) {
            builder.confirmText(confirmText);
        }
        if (showCancel && cancelText != null) {
            builder.cancelText(cancelText);
        }
        return builder.show() != null;
    }

    public static boolean showWifiInitializationDialog(
            Context context,
            String title,
            String message,
            String confirmText,
            String cancelText,
            Runnable onCancel,
            Runnable onConfirm) {
        return showWifiInitializationDialog(
                context, title, message, confirmText, cancelText, onCancel, onConfirm, null);
    }

    public static boolean showWifiInitializationDialog(
            Context context,
            String title,
            String message,
            String confirmText,
            String cancelText,
            Runnable onCancel,
            Runnable onConfirm,
            @Nullable Runnable onDismissed) {
        if (context == null || (context instanceof android.app.Activity act && act.isFinishing())) {
            return false;
        }
        clearStaleHandleRef(sWifiInitDialogRef);
        if (isHandleShowing(sWifiInitDialogRef)) {
            return true;
        }
        FrostDialog.Handle handle = FrostDialog.prompt(context)
                .replaceExistingIfOccupied(false)
                .title(title)
                .message(message)
                .confirmText(R.string.ok_text)
                .cancelText(cancelText)
                .dismissOnScrimClick(false)
                .onCancel(() -> {
                    clearHandleRef(sWifiInitDialogRef);
                    if (onCancel != null) {
                        onCancel.run();
                    }
                })
                .onConfirm(() -> {
                    clearHandleRef(sWifiInitDialogRef);
                    if (onConfirm != null) {
                        onConfirm.run();
                    }
                })
                .onDismiss(onDismissed)
                .show();
        if (handle == null) {
            Log.w(TAG, "showWifiInitializationDialog failed to attach overlay");
            return false;
        }
        sWifiInitDialogRef = new WeakReference<>(handle);
        return true;
    }

    public static boolean showBundledFirmwareUpgradeDialog(
            Context context,
            String title,
            String message,
            String confirmText,
            String cancelText,
            Runnable onCancel,
            Runnable onConfirm) {
        return showBundledFirmwareUpgradeDialog(
                context, title, message, confirmText, cancelText, onCancel, onConfirm, null);
    }

    public static boolean showBundledFirmwareUpgradeDialog(
            Context context,
            String title,
            String message,
            String confirmText,
            String cancelText,
            Runnable onCancel,
            Runnable onConfirm,
            @Nullable Runnable onDismissed) {
        if (context == null || (context instanceof android.app.Activity act && act.isFinishing())) {
            return false;
        }
        if (isHandleShowing(sBundledFirmwareDialogRef)) {
            return true;
        }
        clearStaleHandleRef(sBundledFirmwareDialogRef);
        FrostDialog.Handle handle = FrostDialog.prompt(context)
                .replaceExistingIfOccupied(false)
                .title(title)
                .message(message)
                .confirmText(R.string.ok_text)
                .cancelText(cancelText)
                .dismissOnScrimClick(false)
                .onCancel(() -> {
                    clearHandleRef(sBundledFirmwareDialogRef);
                    if (onCancel != null) {
                        onCancel.run();
                    }
                })
                .onConfirm(() -> {
                    clearHandleRef(sBundledFirmwareDialogRef);
                    if (onConfirm != null) {
                        onConfirm.run();
                    }
                })
                .onDismiss(onDismissed)
                .show();
        if (handle == null) {
            return false;
        }
        sBundledFirmwareDialogRef = new WeakReference<>(handle);
        return true;
    }

    public static boolean showBindDeviceDialog(
            Context context,
            String title,
            String subtitle,
            Bitmap qrBitmap) {
        return showBindDeviceDialog(context, title, subtitle, qrBitmap, null);
    }

    public static boolean showBindDeviceDialog(
            Context context,
            String title,
            String subtitle,
            Bitmap qrBitmap,
            @Nullable Runnable onDismissed) {
        return showBindDeviceDialog(context, title, subtitle, qrBitmap, null, onDismissed);
    }

    public static boolean showBindDeviceDialog(
            Context context,
            String title,
            String subtitle,
            Bitmap qrBitmap,
            @Nullable CharSequence confirmText,
            @Nullable Runnable onDismissed) {
        Context appContext = context != null ? context.getApplicationContext() : null;
        CharSequence resolvedConfirm = confirmText != null
                ? confirmText
                : (appContext != null ? appContext.getString(R.string.ok_text) : "OK");
        return showBindOrRegistrationDialog(context, title, subtitle, qrBitmap,
                resolvedConfirm, null, true, onDismissed);
    }

    public static void dismissBindDeviceDialog() {
        dismissHandleRef(sBindDeviceDialogRef);
        sBindDeviceDialogRef = null;
    }

    public static boolean showDeviceRegistrationDialog(
            Context context,
            String title,
            String message,
            Bitmap qrBitmap,
            Runnable onReconnect) {
        return showDeviceRegistrationDialog(context, title, message, qrBitmap, onReconnect, null);
    }

    public static boolean showDeviceRegistrationDialog(
            Context context,
            String title,
            String message,
            Bitmap qrBitmap,
            @Nullable Runnable onReconnect,
            @Nullable Runnable onDismissed) {
        return showDeviceRegistrationDialog(context, title, message, qrBitmap, onReconnect, null, onDismissed);
    }

    public static boolean showDeviceRegistrationDialog(
            Context context,
            String title,
            String message,
            Bitmap qrBitmap,
            @Nullable Runnable onReconnect,
            @Nullable CharSequence confirmText,
            @Nullable Runnable onDismissed) {
        Context appContext = context != null ? context.getApplicationContext() : null;
        CharSequence resolvedConfirm = confirmText != null
                ? confirmText
                : (appContext != null ? appContext.getString(R.string.ok_text) : "OK");
        return showBindOrRegistrationDialog(context, title, message, qrBitmap,
                resolvedConfirm, onReconnect, false, onDismissed);
    }

    public static void dismissCurrentDialog() {
        dismissHandleRef(sWifiInitDialogRef);
    }

    private static boolean showBindOrRegistrationDialog(
            Context context,
            String title,
            String subtitle,
            Bitmap qrBitmap,
            @Nullable CharSequence confirmText,
            @Nullable Runnable onConfirmExtra,
            boolean isBindDevice,
            @Nullable Runnable onDismissed) {
        if (context == null || (context instanceof android.app.Activity act && act.isFinishing())) {
            return false;
        }
        WeakReference<FrostDialog.Handle> refForCallback = isBindDevice ? sBindDeviceDialogRef : sDeviceRegistrationDialogRef;
        clearStaleHandleRef(refForCallback);
        FrostDialog.PromptBuilder builder = FrostDialog.prompt(context)
                .replaceExistingIfOccupied(false)
                .widthFraction(0.6f)
                .title(title)
                .customBodyView(R.layout.dialog_frost_body_bind_device, body -> {
                    TextView tvSubtitle = body.findViewById(R.id.tv_bind_device_subtitle);
                    ImageView ivQr = body.findViewById(R.id.iv_bind_device_qr);
                    if (tvSubtitle != null) {
                        tvSubtitle.setText(subtitle);
                    }
                    if (ivQr != null) {
                        if (qrBitmap != null && !qrBitmap.isRecycled()) {
                            ivQr.setImageBitmap(qrBitmap);
                            ivQr.setVisibility(View.VISIBLE);
                        } else {
                            ivQr.setVisibility(View.GONE);
                        }
                    }
                })
                .showCancel(false);
        if (confirmText != null) {
            builder.confirmText(confirmText);
        }
        FrostDialog.Handle handle = builder
                .onCancel(() -> {
                    status = false;
                    clearHandleRef(refForCallback);
                })
                .onConfirm(() -> {
                    status = false;
                    clearHandleRef(refForCallback);
                    if (onConfirmExtra != null) {
                        onConfirmExtra.run();
                    }
                })
                .onDismiss(onDismissed)
                .show();
        if (handle == null) {
            return false;
        }
        if (isBindDevice) {
            sBindDeviceDialogRef = new WeakReference<>(handle);
        } else {
            sDeviceRegistrationDialogRef = new WeakReference<>(handle);
        }
        return true;
    }

    private static boolean isHandleShowing(@Nullable WeakReference<FrostDialog.Handle> ref) {
        if (ref == null) {
            return false;
        }
        FrostDialog.Handle handle = ref.get();
        if (handle == null || !handle.isShowing()) {
            ref.clear();
            return false;
        }
        return true;
    }

    private static void clearStaleHandleRef(@Nullable WeakReference<FrostDialog.Handle> ref) {
        if (ref == null) {
            return;
        }
        FrostDialog.Handle handle = ref.get();
        if (handle == null || !handle.isShowing()) {
            ref.clear();
        }
    }

    private static void clearHandleRefIfHost(
            @NonNull android.app.Activity activity,
            @Nullable WeakReference<FrostDialog.Handle> ref) {
        if (ref == null) {
            return;
        }
        FrostDialog.Handle handle = ref.get();
        if (handle == null) {
            ref.clear();
            return;
        }
        android.app.Activity host = resolveHandleActivity(handle);
        if (host == activity) {
            dismissHandleRef(ref);
            ref.clear();
        }
    }

    @Nullable
    private static android.app.Activity resolveHandleActivity(@NonNull FrostDialog.Handle handle) {
        View root = handle.getRootView();
        if (root == null) {
            return null;
        }
        return FrostOverlayHost.findActivity(root.getContext());
    }

    private static void resetAllDialogHandles() {
        clearRefOnly(sDialogRef);
        clearRefOnly(sWifiInitDialogRef);
        clearRefOnly(sBundledFirmwareDialogRef);
        clearRefOnly(sBindDeviceDialogRef);
        clearRefOnly(sDeviceRegistrationDialogRef);
        clearRefOnly(sRemoteLockDialogRef);
        sBindDeviceDialogRef = null;
        sDeviceRegistrationDialogRef = null;
        sRemoteLockDialogRef = null;
    }

    private static void clearRefOnly(@Nullable WeakReference<FrostDialog.Handle> ref) {
        if (ref != null) {
            ref.clear();
        }
    }

    private static void dismissHandleRef(@Nullable WeakReference<FrostDialog.Handle> ref) {
        if (ref == null) {
            return;
        }
        FrostDialog.Handle handle = ref.get();
        if (handle != null && handle.isShowing()) {
            handle.dismiss();
        }
    }

    private static void clearHandleRef(@Nullable WeakReference<FrostDialog.Handle> ref) {
        dismissHandleRef(ref);
    }

    private static void dismissIfOtherShowing(@Nullable WeakReference<FrostDialog.Handle> ref) {
        if (status && ref != null && ref.get() != null) {
            status = false;
            dismissHandleRef(ref);
        }
    }

    private static boolean deferDuringBootSelfCheck() {
        if (!BootSelfCheckGate.isActive()) {
            return false;
        }
        Log.d(TAG, "defer 雾化玻璃设计 dialog until boot self-check completes");
        return true;
    }

    private static void clearDialogRef(@Nullable WeakReference<FrostDialog.Handle> ref) {
        if (ref != null) {
            ref.clear();
        }
    }
}
