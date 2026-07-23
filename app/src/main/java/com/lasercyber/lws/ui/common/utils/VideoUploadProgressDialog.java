package com.lasercyber.lws.ui.common.utils;

import android.app.Activity;
import android.content.Context;
import android.content.ContextWrapper;
import android.view.View;
import android.widget.SeekBar;
import android.widget.TextView;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.component.dialog.FrostDialog;

/**
 * Process video upload progress on {@link FrostDialog}.
 */
public final class VideoUploadProgressDialog {

    public interface OnCancelUploadListener {
        void onCancelUpload();
    }

    private final Activity activity;
    private final OnCancelUploadListener cancelListener;
    @Nullable
    private final CharSequence title;
    @Nullable
    private FrostDialog.Handle handle;
    @Nullable
    private SeekBar progressBar;
    @Nullable
    private TextView messageView;

    public VideoUploadProgressDialog(Context context, OnCancelUploadListener cancelListener) {
        this(context, null, cancelListener);
    }

    public VideoUploadProgressDialog(Context context,
                                     @Nullable CharSequence title,
                                     OnCancelUploadListener cancelListener) {
        this.activity = requireActivity(context);
        this.title = title;
        this.cancelListener = cancelListener;
    }

    private static Activity requireActivity(Context context) {
        Context c = context;
        while (c instanceof ContextWrapper) {
            if (c instanceof Activity) {
                return (Activity) c;
            }
            c = ((ContextWrapper) c).getBaseContext();
        }
        throw new IllegalArgumentException("Context is not an Activity: " + context);
    }

    public void show() {
        if (!canShow() || handle != null) {
            return;
        }
        CharSequence dialogTitle = title != null ? title : activity.getString(R.string.uploading_in_progress);
        handle = FrostDialog.prompt(activity)
                .replaceExistingIfOccupied(true)
                .title(dialogTitle)
                .customBodyView(R.layout.dialog_frost_body_upload_progress, body -> {
                    SeekBar bar = body.findViewById(R.id.frost_dialog_upload_progress_bar);
                    TextView message = body.findViewById(R.id.frost_dialog_upload_progress_message);
                    if (bar != null) {
                        bar.setMax(100);
                        bar.setProgress(0);
                    }
                    if (message != null) {
                        message.setText("");
                    }
                })
                .cancelText(R.string.cancel_text)
                .showConfirm(false)
                .dismissOnScrimClick(false)
                .onCancel(cancelListener::onCancelUpload)
                .show();
        if (handle == null) {
            return;
        }
        View root = handle.getRootView();
        progressBar = root != null ? root.findViewById(R.id.frost_dialog_upload_progress_bar) : null;
        messageView = root != null ? root.findViewById(R.id.frost_dialog_upload_progress_message) : null;
    }

    public void dismiss() {
        if (handle != null && handle.isShowing()) {
            handle.dismiss();
        }
        handle = null;
    }

    public void updateProgress(int percent0to100, @Nullable CharSequence message) {
        if (handle == null || !handle.isShowing()) {
            return;
        }
        int p = Math.max(0, Math.min(100, percent0to100));
        activity.runOnUiThread(() -> {
            if (handle == null || !handle.isShowing()) {
                return;
            }
            if (progressBar != null) {
                progressBar.setProgress(p);
            }
            if (message != null && messageView != null) {
                messageView.setText(message);
            }
        });
    }

    private boolean canShow() {
        return !activity.isFinishing() && !activity.isDestroyed();
    }
}
