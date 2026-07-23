package com.lasercyber.lws.ui.common.camera;

import android.content.Context;
import android.util.Log;

import com.lasercyber.lws.ai.engine.AiManager;
import com.lasercyber.lws.ai.sampling.LiveInferGraceCoordinator;
import com.lasercyber.lws.ai.stream.NativeStreamDetectCoordinator;
import com.lasercyber.lws.ui.common.gpio.LaserEnableStateHolder;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

/**
 * Binds native {@code StreamDetectPipeline} lifecycle to laser enable (Laser Enable / End of work)
 * plus post-enable-OFF grace in weld modes.
 */
public class LivePr1InferenceStreamCoordinator implements LaserEnableStateHolder.Listener,
        LiveInferGraceCoordinator.GraceEndedListener {

    private static final String TAG = LogTAGConstant.EasyPlayerClientManger;

    private final NativeStreamDetectCoordinator nativeStreamDetectCoordinator =
            NativeStreamDetectCoordinator.getInstance();

    private Context appContext;
    private volatile boolean attached;
    private volatile Boolean lastLaserEnableActive;

    public void attach(Context context) {
        if (attached) {
            return;
        }
        appContext = context.getApplicationContext();
        attached = true;
        nativeStreamDetectCoordinator.attach(context);
        LaserEnableStateHolder.addListener(this);
        LiveInferGraceCoordinator.getInstance().addGraceEndedListener(this);
        Log.i(TAG, "Live PR1 inference coordinator attached (native pipeline)");
        applyLaserEnableState("attach", LaserEnableStateHolder.isActive());
    }

    public void detach() {
        if (!attached) {
            return;
        }
        LaserEnableStateHolder.removeListener(this);
        LiveInferGraceCoordinator.getInstance().removeGraceEndedListener(this);
        nativeStreamDetectCoordinator.detach();
        attached = false;
        lastLaserEnableActive = null;
        appContext = null;
        Log.i(TAG, "Live PR1 inference coordinator detached");
    }

    public boolean isStreaming() {
        return nativeStreamDetectCoordinator.isRunning();
    }

    @Override
    public void onLiveInferGraceEnded(String trigger) {
        if (!attached) {
            return;
        }
        nativeStreamDetectCoordinator.onLaserEnableChanged(false);
    }

    @Override
    public void onLaserEnableChanged(boolean active) {
        applyLaserEnableState("laser_enable", active);
    }

    private void applyLaserEnableState(String trigger, boolean laserEnableActive) {
        if (!attached || appContext == null) {
            return;
        }
        Boolean previous = lastLaserEnableActive;
        if (previous != null && previous == laserEnableActive) {
            return;
        }
        lastLaserEnableActive = laserEnableActive;

        AiManager aiManager = AiManager.getInstance();
        boolean liveInferActive = LiveInferGraceCoordinator.getInstance().isLiveInferActive();
        if (!shouldRunInferenceStream(attached, liveInferActive, aiManager.isOpencvStainDetectSessionActive())) {
            nativeStreamDetectCoordinator.onLaserEnableChanged(false);
            Log.d(TAG, "INFER_NATIVE idle trigger=" + trigger
                    + " laserEnableActive=" + laserEnableActive
                    + " liveInferActive=" + liveInferActive
                    + " opencvSessionActive=" + aiManager.isOpencvStainDetectSessionActive());
            return;
        }

        if (!nativeStreamDetectCoordinator.onLaserEnableChanged(true)) {
            Log.w(TAG, "INFER_NATIVE failed to start trigger=" + trigger);
        }
    }

    /**
     * Package-visible for unit tests.
     */
    static boolean shouldRunInferenceStream(boolean attached, boolean liveInferActive, boolean opencvSessionActive) {
        return attached && liveInferActive && opencvSessionActive;
    }
}
