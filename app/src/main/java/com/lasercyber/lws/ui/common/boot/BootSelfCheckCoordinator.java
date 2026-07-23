package com.lasercyber.lws.ui.common.boot;

import android.app.Activity;
import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.camera.CameraCommunicationMonitor;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.component.dialog.AutoDialogQueue;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;

import java.lang.ref.WeakReference;

/**
 * Orchestrates one-per-process boot self-check when the HMI home page is entered.
 */
public final class BootSelfCheckCoordinator {

    private static final String TAG = LogTAGConstant.BootSelfCheck;
    static final long MIN_STEP_DURATION_MS = 50L;

    private static volatile boolean completedInProcess;
    private static volatile boolean running;
    @Nullable
    private static volatile Runnable sessionOnComplete;
    @Nullable
    private static volatile WeakReference<Activity> selfCheckHostRef;

    private BootSelfCheckCoordinator() {
    }

    public static boolean isCompletedInProcess() {
        return completedInProcess;
    }

    public static boolean isRunning() {
        return running;
    }

    /**
     * Runs boot self-check outside {@link AutoDialogQueue} when enabled. Invokes {@code onComplete}
     * after the self-check dialog is dismissed so home prompts can start. When the setting is off,
     * self-check does not run and {@code onComplete} is invoked immediately.
     */
    public static void startWhenHomeEntered(@NonNull Activity activity, @NonNull Runnable onComplete) {
        if (activity.isFinishing()) {
            onComplete.run();
            return;
        }
        if (completedInProcess) {
            CameraCommunicationMonitor.startWhenHomeEntered(activity);
            onComplete.run();
            return;
        }
        if (!BootSelfCheckSettings.isEnabledBlocking(activity.getApplicationContext())) {
            skipSelfCheckAndStartDialogQueue(activity, onComplete);
            return;
        }
        synchronized (BootSelfCheckCoordinator.class) {
            if (completedInProcess) {
                activity.runOnUiThread(onComplete);
                return;
            }
            if (running) {
                Runnable previous = sessionOnComplete;
                sessionOnComplete = () -> {
                    if (previous != null) {
                        previous.run();
                    }
                    onComplete.run();
                };
                return;
            }
            sessionOnComplete = onComplete;
            BootSelfCheckGate.setActive(true);
        }
        ThreadPoolManager.getExecutor().execute(() -> runStartupPipeline(activity));
    }

    /** @deprecated Use {@link #startWhenHomeEntered}. */
    @Deprecated
    public static void startFromHomeQueue(@NonNull Activity activity, @NonNull Runnable onComplete) {
        startWhenHomeEntered(activity, onComplete);
    }

    /** @deprecated Use {@link #startWhenHomeEntered}. */
    @Deprecated
    public static void tryStartWhenHomeReady(@Nullable Activity activity) {
        if (activity == null || activity.isFinishing()) {
            return;
        }
        startWhenHomeEntered(activity, () -> { });
    }

    private static void runStartupPipeline(@NonNull Activity activity) {
        synchronized (BootSelfCheckCoordinator.class) {
            if (completedInProcess) {
                activity.runOnUiThread(() -> completeSession(activity));
                return;
            }
            if (running) {
                return;
            }
        }
        activity.runOnUiThread(() -> beginSelfCheck(activity));
    }

    private static void skipSelfCheckAndStartDialogQueue(
            @NonNull Activity activity,
            @NonNull Runnable onComplete) {
        markSessionHandled();
        Log.d(TAG, "boot self-check disabled; starting auto dialog queue immediately");
        if (!activity.isFinishing()) {
            CameraCommunicationMonitor.startWhenHomeEntered(activity);
        }
        activity.runOnUiThread(() -> {
            onComplete.run();
            AutoDialogQueue.get().onBootSelfCheckFinished();
        });
    }

    private static void beginSelfCheck(Activity activity) {
        if (activity.isFinishing()) {
            completeSession(activity);
            return;
        }
        if (completedInProcess) {
            completeSession(activity);
            return;
        }
        if (running) {
            return;
        }
        running = true;
        selfCheckHostRef = new WeakReference<>(activity);
        BootSelfCheckDialog dialog = new BootSelfCheckDialog(activity);
        dialog.setOnDismissCallback(() -> onDialogDismissed(activity));
        ThreadPoolManager.getExecutor().execute(() -> runPipeline(activity, dialog));
    }

    private static void runPipeline(Activity activity, BootSelfCheckDialog dialog) {
        boolean controllerReady = false;
        BootSelfCheckEvaluator.ModbusSnapshot snapshot = null;

        try {
            dialog.showAndWait();
            for (BootSelfCheckItem item : BootSelfCheckItem.values()) {
                String label = activity.getString(item.getLabelResId());
                final boolean modbusReady = BootSelfCheckEvaluator.isModbusSelfCheckAvailable();
                final boolean controllerReadyAtStep = controllerReady;
                final BootSelfCheckEvaluator.ModbusSnapshot snapshotAtStep = snapshot;

                BootSelfCheckStatus result;
                if (item == BootSelfCheckItem.CONTROLLER_COMM) {
                    result = runStep(dialog, item, label, () -> {
                        if (!modbusReady) {
                            return BootSelfCheckStatus.SKIPPED;
                        }
                        DeviceStatus status = BootSelfCheckEvaluator.readDeviceStatusBlocking(
                                BootSelfCheckEvaluator.MODBUS_READ_TIMEOUT_MS);
                        return BootSelfCheckEvaluator.evaluateControllerReady(status)
                                ? BootSelfCheckStatus.PASS
                                : BootSelfCheckStatus.FAIL;
                    });
                    if (!modbusReady) {
                        controllerReady = false;
                    } else if (result == BootSelfCheckStatus.PASS) {
                        controllerReady = true;
                        snapshot = BootSelfCheckEvaluator.readFullModbusSnapshotBlocking(
                                BootSelfCheckEvaluator.MODBUS_READ_TIMEOUT_MS);
                        if (snapshot != null) {
                            controllerReady = snapshot.controllerReady;
                        }
                    } else {
                        controllerReady = false;
                    }
                } else if (item == BootSelfCheckItem.CAMERA_COMM) {
                    result = runStep(dialog, item, label, () ->
                            BootSelfCheckEvaluator.evaluateItem(
                                    item, snapshotAtStep, controllerReadyAtStep));
                } else if (!modbusReady || !controllerReadyAtStep) {
                    result = runStep(dialog, item, label, () -> BootSelfCheckStatus.SKIPPED);
                } else {
                    result = runStep(dialog, item, label, () -> {
                        BootSelfCheckEvaluator.ModbusSnapshot activeSnapshot = snapshotAtStep;
                        if (activeSnapshot == null) {
                            activeSnapshot = BootSelfCheckEvaluator.readFullModbusSnapshotBlocking(
                                    BootSelfCheckEvaluator.MODBUS_READ_TIMEOUT_MS);
                        }
                        boolean ready = activeSnapshot != null && activeSnapshot.controllerReady;
                        return BootSelfCheckEvaluator.evaluateItem(item, activeSnapshot, ready);
                    });
                    if (snapshot == null && modbusReady && controllerReadyAtStep) {
                        snapshot = BootSelfCheckEvaluator.readFullModbusSnapshotBlocking(
                                BootSelfCheckEvaluator.MODBUS_READ_TIMEOUT_MS);
                        if (snapshot != null) {
                            controllerReady = snapshot.controllerReady;
                        }
                    }
                }
            }
        } catch (Throwable t) {
            Log.e(TAG, "boot self-check pipeline failed", t);
        } finally {
            scheduleDialogClose(dialog);
        }
    }

    private static BootSelfCheckStatus runStep(
            BootSelfCheckDialog dialog,
            BootSelfCheckItem item,
            String label,
            StepEvaluator evaluator) {
        long stepStartMs = SystemClock.elapsedRealtime();
        dialog.appendCheckingSync(item, label);
        BootSelfCheckStatus result = evaluator.evaluate();
        ensureMinStepDuration(stepStartMs);
        dialog.updateStatusSync(item, result);
        return result;
    }

    private static void ensureMinStepDuration(long stepStartMs) {
        long elapsed = SystemClock.elapsedRealtime() - stepStartMs;
        long remaining = MIN_STEP_DURATION_MS - elapsed;
        if (remaining <= 0) {
            return;
        }
        try {
            Thread.sleep(remaining);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    private static void markSessionHandled() {
        completedInProcess = true;
    }

    private static void scheduleDialogClose(BootSelfCheckDialog dialog) {
        markSessionHandled();
        dialog.showFooterSync();
        dialog.scheduleAutoDismiss(BootSelfCheckDialog.AUTO_DISMISS_DELAY_MS);
        Log.d(TAG, "boot self-check pipeline finished; auto-dismiss in "
                + BootSelfCheckDialog.AUTO_DISMISS_DELAY_MS + "ms unless dismissed by close button");
    }

    private static void onDialogDismissed(Activity activity) {
        running = false;
        selfCheckHostRef = null;
        completeSession(activity);
        Log.d(TAG, "boot self-check dialog dismissed");
    }

    /**
     * Safety net when the self-check host Activity is destroyed before {@link BootSelfCheckDialog}
     * dismiss callbacks run (e.g. overlay torn down without animation completion).
     */
    public static void onHostDestroyed(@NonNull Activity activity) {
        if (!BootSelfCheckGate.isActive() && !running) {
            return;
        }
        Activity trackedHost = selfCheckHostRef != null ? selfCheckHostRef.get() : null;
        if (trackedHost != null && trackedHost != activity) {
            return;
        }
        Log.w(TAG, "self-check host destroyed; clearing in-memory gate and queue");
        abortInFlightSelfCheck(activity);
    }

    private static void abortInFlightSelfCheck(@NonNull Activity activity) {
        running = false;
        selfCheckHostRef = null;
        completeSession(activity);
    }

    private static void completeSession(@NonNull Activity activity) {
        BootSelfCheckGate.setActive(false);
        Runnable complete = sessionOnComplete;
        sessionOnComplete = null;
        if (complete != null) {
            activity.runOnUiThread(complete);
        }
        AutoDialogQueue.get().onBootSelfCheckFinished();
        if (!activity.isFinishing()) {
            CameraCommunicationMonitor.startWhenHomeEntered(activity);
        }
    }

    @FunctionalInterface
    private interface StepEvaluator {
        BootSelfCheckStatus evaluate();
    }

    /** Visible for unit tests. */
    static boolean isCompletedForTest() {
        return completedInProcess;
    }

    /** Visible for unit tests. */
    static boolean isRunningForTest() {
        return running;
    }

    /** Visible for unit tests. */
    static void resetForTest() {
        completedInProcess = false;
        running = false;
        sessionOnComplete = null;
        selfCheckHostRef = null;
        BootSelfCheckGate.resetForTest();
    }
}
