package com.lasercyber.lws.ui.common.boot;

import android.app.Activity;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.StringRes;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.frostui.button.interop.FrostButtonView;
import com.lasercyber.lws.ui.component.dialog.FrostDialog;
import com.lasercyber.lws.frostui.control.interop.FrostCheckboxView;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Boot self-check progress dialog with incremental item rows on {@link FrostDialog}.
 */
public final class BootSelfCheckDialog {

    static final long AUTO_DISMISS_DELAY_MS = 3000L;

    private final Activity activity;
    private final android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
    @Nullable
    private FrostDialog.Handle dialogHandle;
    @Nullable
    private LinearLayout itemList;
    @Nullable
    private View footer;
    @Nullable
    private FrostCheckboxView dontShowAgainCheckBox;
    private final Map<BootSelfCheckItem, View> rowViews = new HashMap<>();
    @Nullable
    private Runnable onDismissCallback;
    @Nullable
    private Runnable pendingAutoDismiss;
    private boolean dismissed;

    public BootSelfCheckDialog(@NonNull Activity activity) {
        this.activity = activity;
    }

    public void showAndWait() {
        if (activity.isFinishing()) {
            return;
        }
        CountDownLatch latch = new CountDownLatch(1);
        mainHandler.post(() -> {
            if (activity.isFinishing() || dialogHandle != null) {
                latch.countDown();
                return;
            }
            dialogHandle = FrostDialog.prompt(activity)
                    .title(R.string.boot_self_check_dialog_title)
                    .customBodyView(R.layout.dialog_frost_body_boot_self_check, body -> {
                        itemList = body.findViewById(R.id.boot_self_check_item_list);
                        footer = body.findViewById(R.id.boot_self_check_footer);
                        dontShowAgainCheckBox = body.findViewById(R.id.cb_boot_self_check_dont_show_again);
                        if (dontShowAgainCheckBox != null) {
                            dontShowAgainCheckBox.setOnCheckedChangeListener(
                                    (checkbox, isChecked) -> cancelPendingAutoDismiss());
                        }
                        FrostButtonView closeButton = body.findViewById(R.id.tv_boot_self_check_close);
                        if (closeButton != null) {
                            closeButton.setClickable(true);
                            closeButton.setFocusable(true);
                            closeButton.setOnClickListener(v -> {
                                cancelPendingAutoDismiss();
                                dismissFromUi();
                            });
                        }
                        bindCancelAutoDismissOnInteraction(body);
                    })
                    .showActionBar(false)
                    .dismissOnScrimClick(false)
                    .onDismiss(this::handleDismiss)
                    .show();
            if (dialogHandle != null) {
                bindCancelAutoDismissOnInteraction(
                        dialogHandle.findViewById(R.id.frost_dialog_content));
            }
            latch.countDown();
        });
        awaitLatch(latch, 2000L);
    }

    public void setOnDismissCallback(@Nullable Runnable callback) {
        onDismissCallback = callback;
    }

    public void showFooterSync() {
        CountDownLatch latch = new CountDownLatch(1);
        mainHandler.post(() -> {
            try {
                if (footer != null) {
                    footer.setVisibility(View.VISIBLE);
                }
            } finally {
                latch.countDown();
            }
        });
        awaitLatch(latch, 2000L);
    }

    public void appendCheckingSync(@NonNull BootSelfCheckItem item, @NonNull String label) {
        CountDownLatch latch = new CountDownLatch(1);
        mainHandler.post(() -> {
            try {
                if (itemList == null || rowViews.containsKey(item)) {
                    return;
                }
                View row = LayoutInflater.from(activity).inflate(R.layout.item_boot_self_check_row, itemList, false);
                TextView labelView = row.findViewById(R.id.tv_item_label);
                TextView statusView = row.findViewById(R.id.tv_item_status);
                labelView.setText(label);
                labelView.setTextColor(activity.getColor(R.color.white));
                statusView.setText(statusText(R.string.boot_self_check_status_checking));
                statusView.setTextColor(activity.getColor(R.color.side_tab_not_active_color));
                itemList.addView(row);
                rowViews.put(item, row);
            } finally {
                latch.countDown();
            }
        });
        awaitLatch(latch, 2000L);
    }

    public void updateStatusSync(@NonNull BootSelfCheckItem item, @NonNull BootSelfCheckStatus status) {
        CountDownLatch latch = new CountDownLatch(1);
        mainHandler.post(() -> {
            try {
                View row = rowViews.get(item);
                if (row == null) {
                    return;
                }
                TextView statusView = row.findViewById(R.id.tv_item_status);
                @StringRes int textRes;
                int colorRes;
                switch (status) {
                    case PASS:
                        textRes = R.string.boot_self_check_status_pass;
                        colorRes = R.color.switch_open;
                        break;
                    case FAIL:
                        textRes = R.string.boot_self_check_status_fail;
                        colorRes = R.color.orange;
                        break;
                    case SKIPPED:
                        textRes = R.string.boot_self_check_status_skipped;
                        colorRes = R.color.side_tab_not_active_color;
                        break;
                    case CHECKING:
                    default:
                        textRes = R.string.boot_self_check_status_checking;
                        colorRes = R.color.side_tab_not_active_color;
                        break;
                }
                statusView.setText(statusText(textRes));
                statusView.setTextColor(activity.getColor(colorRes));
            } finally {
                latch.countDown();
            }
        });
        awaitLatch(latch, 2000L);
    }

    public void scheduleAutoDismiss(long delayMs) {
        cancelPendingAutoDismiss();
        pendingAutoDismiss = this::dismissFromUi;
        mainHandler.postDelayed(pendingAutoDismiss, delayMs);
    }

    private void dismissFromUi() {
        cancelPendingAutoDismiss();
        if (dismissed) {
            return;
        }
        if (dialogHandle != null) {
            if (dialogHandle.isShowing()) {
                dialogHandle.dismiss();
            } else {
                dialogHandle.dismissImmediate();
            }
            return;
        }
        handleDismiss();
    }

    private void handleDismiss() {
        if (dismissed) {
            return;
        }
        dismissed = true;
        cancelPendingAutoDismiss();
        persistDontShowAgainIfChecked();
        dialogHandle = null;
        itemList = null;
        footer = null;
        dontShowAgainCheckBox = null;
        rowViews.clear();
        if (onDismissCallback != null) {
            Runnable callback = onDismissCallback;
            onDismissCallback = null;
            callback.run();
        }
    }

    private void persistDontShowAgainIfChecked() {
        if (dontShowAgainCheckBox != null && dontShowAgainCheckBox.isChecked()) {
            BootSelfCheckSettings.setEnabled(activity, false);
        }
    }

    private void cancelPendingAutoDismiss() {
        if (pendingAutoDismiss != null) {
            mainHandler.removeCallbacks(pendingAutoDismiss);
            pendingAutoDismiss = null;
        }
    }

    /** Any touch inside the dialog card cancels the post-completion auto-dismiss countdown. */
    private void bindCancelAutoDismissOnInteraction(@Nullable View root) {
        if (root == null) {
            return;
        }
        View.OnTouchListener listener = (v, event) -> {
            if (event.getActionMasked() == MotionEvent.ACTION_DOWN) {
                cancelPendingAutoDismiss();
            }
            return false;
        };
        applyCancelAutoDismissTouchListener(root, listener);
    }

    private void applyCancelAutoDismissTouchListener(
            @NonNull View view,
            @NonNull View.OnTouchListener listener) {
        view.setOnTouchListener(listener);
        if (view instanceof ViewGroup group) {
            for (int i = 0; i < group.getChildCount(); i++) {
                applyCancelAutoDismissTouchListener(group.getChildAt(i), listener);
            }
        }
    }

    private String statusText(@StringRes int resId) {
        return activity.getString(resId);
    }

    private static void awaitLatch(CountDownLatch latch, long timeoutMs) {
        try {
            latch.await(timeoutMs, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    boolean isShowingForTest() {
        return dialogHandle != null && dialogHandle.isShowing();
    }
}
