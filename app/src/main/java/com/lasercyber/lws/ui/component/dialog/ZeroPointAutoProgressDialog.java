package com.lasercyber.lws.ui.component.dialog;

import android.content.Context;
import android.view.View;
import android.widget.SeekBar;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.StringRes;

import com.lasercyber.lws.ui.R;

/**
 * Zero Offset Auto Correction progress UI built on {@link FrostDialog} custom body.
 * Progress behaviour lives in the feature layout, not in the generic dialog component.
 */
public final class ZeroPointAutoProgressDialog {

    private final FrostDialog.Handle dialogHandle;
    @Nullable
    private final SeekBar progressBar;
    @Nullable
    private final TextView messageView;

    private ZeroPointAutoProgressDialog(
            @NonNull FrostDialog.Handle dialogHandle,
            @Nullable SeekBar progressBar,
            @Nullable TextView messageView) {
        this.dialogHandle = dialogHandle;
        this.progressBar = progressBar;
        this.messageView = messageView;
    }

    @Nullable
    public static ZeroPointAutoProgressDialog show(
            @NonNull Context context,
            @Nullable CharSequence title,
            @Nullable Runnable onCancel) {
        FrostDialog.Handle handle = FrostDialog.prompt(context)
                .title(title)
                .customBodyView(R.layout.dialog_frost_body_zero_point_progress, body -> {
                    SeekBar bar = body.findViewById(R.id.zero_point_progress_bar);
                    if (bar != null) {
                        bar.setMax(100);
                        bar.setProgress(0);
                    }
                    TextView message = body.findViewById(R.id.zero_point_progress_message);
                    if (message != null) {
                        message.setText("");
                    }
                })
                .cancelText(R.string.cancel_text)
                .showConfirm(false)
                .dismissOnScrimClick(false)
                .onCancel(onCancel)
                .show();
        if (handle == null) {
            return null;
        }
        View root = handle.getRootView();
        SeekBar progressBar = root != null ? root.findViewById(R.id.zero_point_progress_bar) : null;
        TextView messageView = root != null ? root.findViewById(R.id.zero_point_progress_message) : null;
        return new ZeroPointAutoProgressDialog(handle, progressBar, messageView);
    }

    public static ZeroPointAutoProgressDialog show(
            @NonNull Context context,
            @StringRes int titleRes,
            @Nullable Runnable onCancel) {
        return show(context, context.getString(titleRes), onCancel);
    }

    public void updateProgress(int percent0to100, @Nullable CharSequence message) {
        if (!isShowing()) {
            return;
        }
        int percent = Math.max(0, Math.min(100, percent0to100));
        View root = dialogHandle.getRootView();
        if (root == null) {
            return;
        }
        root.post(() -> {
            if (!isShowing()) {
                return;
            }
            if (progressBar != null) {
                progressBar.setProgress(percent);
            }
            if (message != null && messageView != null) {
                messageView.setText(message);
            }
        });
    }

    public void dismiss() {
        dialogHandle.dismiss();
    }

    public boolean isShowing() {
        return dialogHandle.isShowing();
    }

    @NonNull
    public FrostDialog.Handle getDialogHandle() {
        return dialogHandle;
    }
}
