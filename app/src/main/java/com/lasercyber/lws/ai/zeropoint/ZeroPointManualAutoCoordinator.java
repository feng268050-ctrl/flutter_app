package com.lasercyber.lws.ai.zeropoint;

import android.content.Context;

import androidx.annotation.NonNull;

/**
 * Public facade for manual Advanced Settings zero-offset auto correction.
 *
 * <p>Delegates to {@link ZeroPointManualAutoWorkflow} (state machine),
 * {@link ZeroPointLaserController} (Modbus / laser), and
 * {@link ZeroPointVideoAnalyzer} (offline video sampling).</p>
 */
public final class ZeroPointManualAutoCoordinator {

    private static volatile ZeroPointManualAutoCoordinator instance;
    private final ZeroPointManualAutoWorkflow workflow = new ZeroPointManualAutoWorkflow();

    public static ZeroPointManualAutoCoordinator getInstance() {
        if (instance == null) {
            synchronized (ZeroPointManualAutoCoordinator.class) {
                if (instance == null) {
                    instance = new ZeroPointManualAutoCoordinator();
                }
            }
        }
        return instance;
    }

    private ZeroPointManualAutoCoordinator() {
    }

    public boolean start(@NonNull Context context, @NonNull Callback callback) {
        return workflow.start(context, callback);
    }

    public void cancel() {
        workflow.cancel();
    }

    public boolean isRunning() {
        return workflow.isRunning();
    }

    public interface Callback {
        void onProgress(int percent, @NonNull String message);

        void onComplete(@NonNull CompletionResult result);

        void onFailure(@NonNull String message);

        void onCancelled();
    }

    public static final class CompletionResult {
        @NonNull
        public final String stageName;
        public final int validSamples;
        public final double meanOffsetX;
        public final double meanOffsetY;
        public final int currentUi;
        public final int newUi;
        public final int uiDelta;
        public final boolean changed;

        CompletionResult(@NonNull String stageName,
                         int validSamples,
                         double meanOffsetX,
                         double meanOffsetY,
                         int currentUi,
                         int newUi,
                         int uiDelta,
                         boolean changed) {
            this.stageName = stageName;
            this.validSamples = validSamples;
            this.meanOffsetX = meanOffsetX;
            this.meanOffsetY = meanOffsetY;
            this.currentUi = currentUi;
            this.newUi = newUi;
            this.uiDelta = uiDelta;
            this.changed = changed;
        }
    }
}
