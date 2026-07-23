package com.lasercyber.lws.ai.stain;
import com.lasercyber.lws.ai.daemon.AiDaemonSupervisor;
import com.lasercyber.lws.ai.engine.AiManager;
import com.lasercyber.lws.ai.model.OpencvDetectCodes;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.sampling.LiveInferGraceCoordinator;
import com.lasercyber.lws.ai.stain.LensDetConsecutiveOkFilter;
import com.lasercyber.lws.ai.stain.OpencvStainDetectResultMapper;
import com.lasercyber.lws.ai.stain.StainDetectAlertPublisher;
import com.lasercyber.lws.ai.stream.LaserDetectSamplingCoordinator;
import com.lasercyber.lws.ai.stream.StreamDetectEvent;
import com.lasercyber.lws.ai.stream.StreamDetectResultBus;
import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.ai.upload.StainAuditUploadCoordinator;
import com.lasercyber.lws.ui.common.handler.LensHeavyContaminationWarnAlarm;
import com.lasercyber.lws.ui.common.settings.AiAssistanceSettings;

/**
 * Live weld OpenCV stain-detect via {@link StreamDetectResultBus} (native pipeline).
 */
public final class OpencvStainDetectCoordinator implements LiveInferGraceCoordinator.GraceEndedListener,
        StreamDetectResultBus.DetectResultListener {

    private static final String TAG = "OpencvStainDetect";

    private static volatile OpencvStainDetectCoordinator instance;

    private Context appContext;
    private volatile boolean attached;
    private final LensDetConsecutiveOkFilter.LiveGate consecutiveOkGate =
            new LensDetConsecutiveOkFilter.LiveGate();
    private volatile boolean lensDetEffectivelyActive;

    public static OpencvStainDetectCoordinator getInstance() {
        if (instance == null) {
            synchronized (OpencvStainDetectCoordinator.class) {
                if (instance == null) {
                    instance = new OpencvStainDetectCoordinator();
                }
            }
        }
        return instance;
    }

    public void attach(@NonNull Context context) {
        if (attached) {
            return;
        }
        appContext = context.getApplicationContext();
        attached = true;
        LiveInferGraceCoordinator.getInstance().addGraceEndedListener(this);
        StreamDetectResultBus.getInstance().addListener(this);
        Log.i(TAG, "attached");
    }

    public void detach() {
        if (!attached) {
            return;
        }
        LiveInferGraceCoordinator.getInstance().removeGraceEndedListener(this);
        StreamDetectResultBus.getInstance().removeListener(this);
        attached = false;
        appContext = null;
        Log.i(TAG, "detached");
    }

    @Override
    public void onLiveInferGraceEnded(String trigger) {
        consecutiveOkGate.reset();
        lensDetEffectivelyActive = false;
        if (!AiAssistanceSettings.isLensContaminationDetectionEnabled(appContext)) {
            LensHeavyContaminationWarnAlarm.INSTANCE.onFaultCleared();
        }
        StainAuditUploadCoordinator.cleanupLiveSessionFrameArtifacts(appContext);
        Log.d(TAG, "laser_off_grace_end reset live-weld gate trigger=" + trigger);
    }

    @Override
    public void onDetectResult(@NonNull StreamDetectEvent.DetectResult event) {
        if (!"lens_det".equals(event.module)) {
            return;
        }
        if (!attached || !LiveInferGraceCoordinator.getInstance().isLiveInferActive()) {
            return;
        }
        if (!AiAssistanceSettings.isLensContaminationDetectionEnabled(appContext)) {
            return;
        }
        OpencvStainDetectResult result = OpencvStainDetectResultMapper.fromNativeSummary(
                event.summaryJson,
                event.imageWidth,
                event.imageHeight,
                event.timestampMs,
                StainDetectSource.LIVE);
        applyLiveWeldResult(result);
        StainAuditUploadCoordinator.maybeEnqueueLiveDetectFailed(appContext, event, result);
    }

    @Override
    public void onSessionStart(@NonNull StreamDetectEvent.SessionStart event) {
        // SSE session lifecycle handled by CameraAiHttpPublisher bus subscriber.
    }

    @Override
    public void onSessionStop(@NonNull StreamDetectEvent.SessionStop event) {
        consecutiveOkGate.reset();
        lensDetEffectivelyActive = false;
        StainAuditUploadCoordinator.cleanupLiveSessionFrameArtifacts(appContext);
    }

    @Override
    public void onPipelineState(@NonNull StreamDetectEvent.PipelineState event) {
        Log.d(TAG, "pipeline_state state=" + event.state + " detail=" + event.detail);
    }

    private void applyLiveWeldResult(@NonNull OpencvStainDetectResult result) {
        if (result.code != AiManager.CODE_OPENCV_STAIN_DETECT_DEFERRED
                && result.code != AiManager.CODE_INFER_BUSY) {
            if (result.code == OpencvDetectCodes.FRAME_REJECTED.code()) {
                AiDaemonSupervisor.getInstance()
                        .setStreamDetectBurstMode(true);
            } else if (result.success && result.code == 0) {
                AiDaemonSupervisor.getInstance()
                        .setStreamDetectBurstMode(false);
            }
            LaserDetectSamplingCoordinator.getInstance().reportDetectResult(
                    LaserDetectSamplingCoordinator.Module.LENS_DET,
                    result.success,
                    result.code,
                    result.message);
        }
        boolean effectiveOk = consecutiveOkGate.acceptNativeOk(
                result.success,
                result.frameKind,
                AiManager.getInstance().getMinConsecutiveOkFrames(),
                AiManager.getInstance().getBlueMinConsecutiveOkFrames());
        if (effectiveOk) {
            lensDetEffectivelyActive = true;
            Log.d(TAG, "sample_ok x=" + result.targetX + " y=" + result.targetY
                    + " source=" + result.source + " frame_kind=" + result.frameKind);
            StainDetectAlertPublisher.getInstance().publishFromWorker(result);
        } else if (result.success) {
            Log.d(TAG, "sample_pending_consecutive native_ok=true frame_kind=" + result.frameKind
                    + " red_min=" + AiManager.getInstance().getMinConsecutiveOkFrames()
                    + " blue_min=" + AiManager.getInstance().getBlueMinConsecutiveOkFrames());
        } else if (lensDetEffectivelyActive) {
            lensDetEffectivelyActive = false;
            LensHeavyContaminationWarnAlarm.INSTANCE.onFaultCleared();
        }
        if (!result.success
                && result.code != AiManager.CODE_OPENCV_STAIN_DETECT_DEFERRED
                && result.code != AiManager.CODE_INFER_BUSY) {
            Log.d(TAG, "detect_result module=lens_det code=" + result.code
                    + " reason=" + result.message);
        }
    }
}
