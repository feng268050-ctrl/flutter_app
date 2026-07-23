package com.lasercyber.lws.ai.stream;
import com.lasercyber.lws.ai.engine.AiManager;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectCoordinator;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.settings.AiAssistanceSettings;

/**
 * Shared PR1 burst coordination for live zero_point and lens_det on the native pipeline bus.
 */
public final class LaserDetectSamplingCoordinator {

    private static final String TAG = "LaserDetectSampling";

    public enum Module {
        ZERO_POINT,
        LENS_DET
    }

    private enum Mode {
        NORMAL,
        BURST
    }

    private static volatile LaserDetectSamplingCoordinator instance;

    private Mode mode = Mode.NORMAL;
    private boolean burstLensDetOk;
    private boolean burstZeroPointOk;

    public static LaserDetectSamplingCoordinator getInstance() {
        if (instance == null) {
            synchronized (LaserDetectSamplingCoordinator.class) {
                if (instance == null) {
                    instance = new LaserDetectSamplingCoordinator();
                }
            }
        }
        return instance;
    }

    public void onZeroPointRoundStart() {
        // Native pipeline resets sampling on session boundaries.
    }

    public void onLaserOff() {
        if (mode == Mode.BURST) {
            setModeNormal("laser_off");
        }
    }

    public void reportDetectResult(@NonNull Module module,
                                   boolean ok,
                                   int code,
                                   @Nullable String reason) {
        OpencvDetectCodes detectCode = OpencvDetectCodes.fromCode(code);
        if (detectCode.isFrameRejected()) {
            enterBurst(module, reason);
            return;
        }
        if (ok && code == OpencvDetectCodes.OK.code()) {
            if (mode == Mode.BURST) {
                if (module == Module.LENS_DET) {
                    burstLensDetOk = true;
                } else {
                    burstZeroPointOk = true;
                }
                maybeExitBurst();
            }
        }
    }

    /** Package-visible for unit tests. */
    public boolean isBurstMode() {
        return mode == Mode.BURST;
    }

    private void enterBurst(@NonNull Module triggerModule, @Nullable String reason) {
        boolean wasNormal = mode == Mode.NORMAL;
        if (wasNormal) {
            burstLensDetOk = false;
            burstZeroPointOk = false;
            mode = Mode.BURST;
            Log.i(TAG, "mode=burst reason=frame_rejected module=" + moduleName(triggerModule)
                    + (reason != null && !reason.isEmpty() ? " detail=" + reason : ""));
        }
    }

    private void maybeExitBurst() {
        AiManager manager = AiManager.getInstance();
        boolean lensDetActive = manager.isOpencvStainDetectSessionActive();
        boolean zeroPointActive = ZeroPointDetectCoordinator.getInstance().isRoundActive();
        boolean lensDetSatisfied = !lensDetActive || burstLensDetOk;
        boolean zeroPointSatisfied = !zeroPointActive || burstZeroPointOk;
        if (!lensDetSatisfied || !zeroPointSatisfied) {
            return;
        }
        setModeNormal("all_ok");
        Log.i(TAG, "mode=normal restored lens_det_ok=" + burstLensDetOk
                + " zero_point_ok=" + burstZeroPointOk);
    }

    private void setModeNormal(@NonNull String trigger) {
        mode = Mode.NORMAL;
        burstLensDetOk = false;
        burstZeroPointOk = false;
        Log.d(TAG, "mode=normal trigger=" + trigger);
    }

    private static String moduleName(@NonNull Module module) {
        if (module == Module.LENS_DET) {
            return "lens_det";
        }
        return "zero_point";
    }
}
