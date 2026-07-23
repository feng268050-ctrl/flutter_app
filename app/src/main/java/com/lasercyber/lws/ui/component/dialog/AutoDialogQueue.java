package com.lasercyber.lws.ui.component.dialog;

import android.app.Activity;
import android.content.Context;
import android.graphics.Bitmap;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.blankj.utilcode.util.ActivityUtils;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.vo.WarnDialogVo;
import com.lasercyber.lws.ui.common.boot.BootSelfCheckGate;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.queue.EnqueuePolicy;
import com.lasercyber.lws.ui.common.queue.SerialTask;
import com.lasercyber.lws.ui.common.queue.SerialTaskQueue;

/**
 * Global serial queue for automatic HMI dialogs (home startup prompts, passive alarms, WS prompts).
 * <p>
 * Only one auto dialog is visible at a time; every enqueued dialog gets a turn in priority/FIFO order.
 * User-initiated immediate dialogs can use {@link #enqueueImmediateWarn} (higher priority).
 * <p>
 * Built on {@link SerialTaskQueue} which can be reused for other non-dialog serial work.
 */
public final class AutoDialogQueue {

    private static final String TAG = LogTAGConstant.AutoDialogQueue;
    private static final AutoDialogQueue INSTANCE = new AutoDialogQueue();

    private final SerialTaskQueue queue = new SerialTaskQueue("auto-dialog");

    private AutoDialogQueue() {
    }

    public static AutoDialogQueue get() {
        return INSTANCE;
    }

    /** Exposed for other serial scenarios that should share the same runner (advanced use). */
    @NonNull
    public SerialTaskQueue serialQueue() {
        return queue;
    }

    public void enqueue(@NonNull AutoDialogTask task) {
        enqueue(task, EnqueuePolicy.SKIP_IF_PENDING);
    }

    public void enqueue(@NonNull AutoDialogTask task, @NonNull EnqueuePolicy policy) {
        if (BootSelfCheckGate.isActive()) {
            Log.d(TAG, "defer " + task.id() + " while boot self-check gate is active");
            return;
        }
        queue.enqueue(task, policy);
    }

    public void enqueue(@NonNull SerialTask task, @NonNull EnqueuePolicy policy) {
        queue.enqueue(task, policy);
    }

    public void scheduleDrain() {
        queue.scheduleDrain();
    }

    public boolean isIdle() {
        return queue.isIdle();
    }

    public void enqueuePassiveWarn(@NonNull Context context, @NonNull WarnDialogVo vo) {
        enqueue(WarnAutoDialogTask.passive(context, vo), EnqueuePolicy.SKIP_IF_PENDING);
    }

    /** Drops a queued (not yet visible) warn dialog for {@code errorCode}. */
    public void cancelPendingWarn(@Nullable String errorCode) {
        queue.cancelPending(WarnAutoDialogTask.taskId(errorCode));
    }

    /** User-initiated warn (e.g. quick laser check). */
    public void enqueueImmediateWarn(@NonNull Context context, @NonNull WarnDialogVo vo) {
        enqueue(WarnAutoDialogTask.immediate(context, vo), EnqueuePolicy.REPLACE_PENDING);
    }

    public void enqueueFrostDialog(
            @NonNull String taskId,
            int priority,
            @NonNull FrostDialogPresenter presenter) {
        enqueue(new FrostAutoDialogTask(taskId, priority, presenter), EnqueuePolicy.SKIP_IF_PENDING);
    }

    /** Shows a Frost dialog; call {@code onDismissed} when the dialog closes. */
    @FunctionalInterface
    public interface FrostDialogPresenter {
        /** @return {@code true} when the dialog was attached */
        boolean show(@NonNull Runnable onDismissed);
    }

    public void enqueueRemoteProcessParamReceived(
            @NonNull ProcessParametersData data,
            boolean useMMUnit) {
        Context appContext = ActivityUtils.getTopActivity();
        if (appContext == null) {
            appContext = com.blankj.utilcode.util.Utils.getApp();
        }
        final Context context = appContext;
        String taskId = "ws:process_param_received:"
                + (data.getId() != null ? data.getId() : System.identityHashCode(data));
        enqueueFrostDialog(
                taskId,
                AutoDialogTask.PRIORITY_REMOTE_PROCESS_PARAM,
                onDismissed -> {
                    Activity activity = resolveForegroundActivity(context);
                    if (activity == null) {
                        return false;
                    }
                    return RemoteProcessParamReceivedDialog.show(activity, data, useMMUnit, onDismissed) != null;
                });
    }

    public void enqueueForcedWsDisconnect(
            @NonNull Context context,
            @NonNull String title,
            @NonNull String message) {
        enqueueFrostDialog(
                "ws:forced_disconnect",
                AutoDialogTask.PRIORITY_FORCED_WS_DISCONNECT,
                onDismissed -> GlobalDialogUtil.showForcedDisconnectDialog(
                        context, title, message, onDismissed));
    }

    public void enqueueDeviceRegistration(
            @NonNull Context context,
            @NonNull String title,
            @NonNull String message,
            @Nullable Bitmap qrBitmap,
            @Nullable Runnable onReconnect) {
        enqueueFrostDialog(
                "ws:device_registration",
                AutoDialogTask.PRIORITY_DEVICE_REGISTRATION,
                onDismissed -> GlobalDialogUtil.showDeviceRegistrationDialog(
                        context, title, message, qrBitmap, onReconnect, onDismissed));
    }

    /** Retry deferred auto dialogs after boot self-check completes. */
    public void onBootSelfCheckFinished() {
        scheduleDrain();
    }

    /** Unblocks the queue when the foreground Activity is destroyed mid-dialog. */
    public void onActivityDestroyed(@NonNull Activity activity) {
        queue.abandonActiveTask("host destroyed: " + activity.getClass().getSimpleName());
        scheduleDrain();
    }

    @Nullable
    public Activity resolveForegroundActivity(@Nullable Context context) {
        if (context instanceof Activity activity
                && !activity.isFinishing()
                && !activity.isDestroyed()) {
            return activity;
        }
        Activity top = ActivityUtils.getTopActivity();
        if (top != null && !top.isFinishing() && !top.isDestroyed()) {
            return top;
        }
        return null;
    }
}
