package com.lasercyber.lws.ui.component.dialog;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.SeekBar;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.frostui.dialog.FrostOverlayHost;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.boot.BootSelfCheckGate;

/**
 * Global operation status UI (success / failure / waiting / blocking firmware progress)
 * on {@link FrostDialog}.
 */
public final class FrostStatusDialog {

    @Nullable
    private static FrostStatusDialog sActive;

    private final FrostDialog.Handle handle;
    @Nullable
    private final ImageView iconView;
    @Nullable
    private final TextView contentView;
    @Nullable
    private final SeekBar progressBar;
    @Nullable
    private final TextView progressText;
    private int mode;

    @Nullable
    private final Runnable onDismissed;
    private boolean dismissNotified;

    private FrostStatusDialog(
            @NonNull FrostDialog.Handle handle,
            @Nullable ImageView iconView,
            @Nullable TextView contentView,
            @Nullable SeekBar progressBar,
            @Nullable TextView progressText,
            int mode,
            @Nullable Runnable onDismissed) {
        this.handle = handle;
        this.iconView = iconView;
        this.contentView = contentView;
        this.progressBar = progressBar;
        this.progressText = progressText;
        this.mode = mode;
        this.onDismissed = onDismissed;
    }

    @Nullable
    public static Boolean show(@NonNull Context context, int mode, @Nullable String title, @Nullable String content) {
        return show(context, mode, title, content, null);
    }

    @Nullable
    public static Boolean show(
            @NonNull Context context,
            int mode,
            @Nullable String title,
            @Nullable String content,
            @Nullable Runnable onDismissed) {
        if (BootSelfCheckGate.isActive()) {
            return false;
        }
        if (WarnDialogUtil.isDialogShowing()) {
            return false;
        }
        if (sActive != null && sActive.isHandleShowing()) {
            if (mode == 3 && sActive.mode == 3) {
                sActive.apply(mode, title, content);
                return true;
            }
            sActive.dismissInternal(false);
        }

        boolean showConfirm = mode == 0 || mode == 1;
        boolean dismissOnScrim = mode != 3;

        FrostDialog.Handle handle = FrostDialog.prompt(context)
                .replaceExistingIfOccupied(false)
                .title(title)
                .customBodyView(R.layout.dialog_frost_body_status, body -> applyToBody(body, mode, content))
                .showActionBar(showConfirm)
                .showConfirm(showConfirm)
                .showCancel(false)
                .confirmText(R.string.ok_text)
                .dismissOnScrimClick(dismissOnScrim)
                .onConfirm(() -> dismissActive(onDismissed))
                .onCancel(() -> dismissActive(onDismissed))
                .show();
        if (handle == null) {
            return false;
        }

        View root = handle.getRootView();
        sActive = new FrostStatusDialog(
                handle,
                root != null ? root.findViewById(R.id.frost_dialog_status_icon) : null,
                root != null ? root.findViewById(R.id.frost_dialog_status_content) : null,
                root != null ? root.findViewById(R.id.frost_dialog_status_progress) : null,
                root != null ? root.findViewById(R.id.frost_dialog_status_progress_text) : null,
                mode,
                onDismissed);
        return true;
    }

    public static void updateFirmwareProgress(int percent) {
        if (sActive == null || !sActive.isHandleShowing() || sActive.mode != 3) {
            return;
        }
        sActive.updateProgressInternal(percent);
    }

    public static void dismissActive() {
        dismissActive(null);
    }

    public static void dismissActive(@Nullable Runnable onDismissed) {
        if (sActive != null) {
            sActive.dismissInternal(true, onDismissed);
        } else if (onDismissed != null) {
            onDismissed.run();
        }
    }

    static void onActivityDestroyed(@NonNull android.app.Activity activity) {
        if (sActive == null) {
            return;
        }
        View root = sActive.handle.getRootView();
        android.app.Activity host = root != null
                ? FrostOverlayHost.findActivity(root.getContext()) : null;
        if (host == activity) {
            dismissActive(null);
        }
    }

    public static boolean isShowing() {
        return sActive != null && sActive.isHandleShowing();
    }

    private static void applyToBody(@NonNull View body, int mode, @Nullable String content) {
        ImageView icon = body.findViewById(R.id.frost_dialog_status_icon);
        TextView tvContent = body.findViewById(R.id.frost_dialog_status_content);
        SeekBar bar = body.findViewById(R.id.frost_dialog_status_progress);
        TextView tvProgress = body.findViewById(R.id.frost_dialog_status_progress_text);

        if (icon != null) {
            icon.setImageResource(mode == 1 ? R.mipmap.dialog_succd
                    : (mode == 2 || mode == 3) ? R.mipmap.dialog_loding : R.mipmap.dialog_error);
        }
        if (tvContent != null) {
            tvContent.setText(content != null ? content : "");
        }
        boolean showProgress = mode == 3;
        if (bar != null) {
            bar.setVisibility(showProgress ? View.VISIBLE : View.GONE);
            if (showProgress) {
                bar.setProgress(0);
            }
        }
        if (tvProgress != null) {
            tvProgress.setVisibility(showProgress ? View.VISIBLE : View.GONE);
            if (showProgress) {
                tvProgress.setText(body.getContext().getString(R.string.bundled_firmware_progress_percent, 0));
            }
        }
    }

    private void apply(int mode, @Nullable String title, @Nullable String content) {
        this.mode = mode;
        View root = handle.getRootView();
        if (root == null) {
            return;
        }
        TextView titleView = root.findViewById(R.id.tv_title);
        if (titleView != null && title != null) {
            titleView.setText(title);
        }
        View bodySlot = handle.getBodySlot();
        if (bodySlot instanceof ViewGroup group && group.getChildCount() > 0) {
            applyToBody(group.getChildAt(0), mode, content);
        }
    }

    private void updateProgressInternal(int percent) {
        int clamped = Math.max(0, Math.min(100, percent));
        View root = handle.getRootView();
        if (root == null) {
            return;
        }
        root.post(() -> {
            if (!isHandleShowing()) {
                return;
            }
            if (progressBar != null && progressBar.getVisibility() == View.VISIBLE) {
                progressBar.setProgress(clamped);
            }
            if (progressText != null && progressText.getVisibility() == View.VISIBLE) {
                progressText.setText(root.getContext().getString(R.string.bundled_firmware_progress_percent, clamped));
            }
        });
    }

    private boolean isHandleShowing() {
        return handle.isShowing();
    }

    private void dismissInternal(boolean notifyDismiss) {
        dismissInternal(notifyDismiss, onDismissed);
    }

    private void dismissInternal(boolean notifyDismiss, @Nullable Runnable overrideDismissed) {
        handle.dismiss();
        Runnable callback = overrideDismissed != null ? overrideDismissed : onDismissed;
        clearActiveInstance();
        if (notifyDismiss) {
            notifyDismissed(callback);
        }
    }

    private void notifyDismissed(@Nullable Runnable callback) {
        if (dismissNotified || callback == null) {
            return;
        }
        dismissNotified = true;
        callback.run();
    }

    private static void clearActiveInstance() {
        sActive = null;
        GlobalDialogUtil.markStatusClosed();
    }
}
