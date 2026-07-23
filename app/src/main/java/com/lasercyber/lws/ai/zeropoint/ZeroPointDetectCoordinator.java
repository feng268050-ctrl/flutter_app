package com.lasercyber.lws.ai.zeropoint;
import com.lasercyber.lws.ai.daemon.AiDaemonSupervisor;
import com.lasercyber.lws.ai.sampling.AiFrameSamplingInterval;
import com.lasercyber.lws.ai.sampling.LiveInferGraceCoordinator;
import com.lasercyber.lws.ai.stream.LaserDetectSamplingCoordinator;
import com.lasercyber.lws.ai.stream.NativeStreamDetectCoordinator;
import com.lasercyber.lws.ai.stream.StreamDetectEvent;
import com.lasercyber.lws.ai.stream.StreamDetectResultBus;
import com.lasercyber.lws.ai.zeropoint.ZeroPointCorrectionMapper;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectAlgorithmSelector;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectClusterReducer;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectJson;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectNativeSession;
import com.lasercyber.lws.ai.zeropoint.ZeroPointDetectTargetMode;
import com.lasercyber.lws.ai.zeropoint.ZeroPointOverlayPublisher;
import com.lasercyber.lws.ai.zeropoint.ZeroPointOverlayState;
import com.lasercyber.lws.ai.zeropoint.ZeroPointPendingCorrectionStore;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.gpio.LaserEnableStateHolder;
import com.lasercyber.lws.ui.common.handler.WarnAlarmPipeline;
import com.lasercyber.lws.ui.common.handler.ZeroPointOffsetWarnAlarm;
import com.lasercyber.lws.ui.common.settings.AiAssistanceSettings;
import com.lasercyber.lws.ui.common.weld.WeldAlertScope;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Continuous zero-point detect while laser enable is active: PR1-driven samples at
 * {@link AiFrameSamplingInterval#ZERO_POINT_ON_LASER} (or burst interval); cluster finalize after
 * laser enable OFF grace ends.
 */
public final class ZeroPointDetectCoordinator implements LaserEnableStateHolder.Listener,
        LiveInferGraceCoordinator.GraceEndedListener,
        StreamDetectResultBus.DetectResultListener {

    private static final String TAG = "ZeroPointDetect";

    private static volatile ZeroPointDetectCoordinator instance;

    private final AtomicLong laserEventSeq = new AtomicLong(0L);
    private final AtomicInteger sampleSeq = new AtomicInteger(0);
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Object taskLock = new Object();

    private Context appContext;
    private volatile boolean attached;
    private volatile boolean manualAutoActive;
    private volatile Boolean lastLaserEnableActive;
    private long activeEventId;
    private int activeTargetMode = ZeroPointDetectTargetMode.POINT;
    private final ZeroPointDetectNativeSession nativeSession = new ZeroPointDetectNativeSession();
    private final List<Double> validOffsetX = new ArrayList<>();
    private final List<Double> validOffsetY = new ArrayList<>();

    public static ZeroPointDetectCoordinator getInstance() {
        if (instance == null) {
            synchronized (ZeroPointDetectCoordinator.class) {
                if (instance == null) {
                    instance = new ZeroPointDetectCoordinator();
                }
            }
        }
        return instance;
    }

    public void attach(Context context) {
        if (attached) {
            return;
        }
        appContext = context.getApplicationContext();
        attached = true;
        nativeSession.ensureReady(appContext);
        ZeroPointDetectAlgorithmSelector.logActiveAlgorithmOnce();
        LiveInferGraceCoordinator.getInstance().addGraceEndedListener(this);
        LaserEnableStateHolder.addListener(this);
        StreamDetectResultBus.getInstance().addListener(this);
        Log.i(TAG, "attached algorithm=ZERO_POINT");
        applyLaserEnableState("attach", LaserEnableStateHolder.isActive());
    }

    public void detach() {
        if (!attached) {
            return;
        }
        LaserEnableStateHolder.removeListener(this);
        LiveInferGraceCoordinator.getInstance().removeGraceEndedListener(this);
        StreamDetectResultBus.getInstance().removeListener(this);
        discardActiveRound("detach");
        destroyDetector();
        attached = false;
        lastLaserEnableActive = null;
        appContext = null;
        Log.i(TAG, "detached");
    }

    @Override
    public void onLiveInferGraceEnded(String trigger) {
        finalizeRoundOnLaserOff("laser_off_grace:" + trigger);
    }

    @Override
    public void onLaserEnableChanged(boolean active) {
        applyLaserEnableState("laser_enable", active);
    }

    private void applyLaserEnableState(String trigger, boolean laserEnableActive) {
        if (!attached) {
            return;
        }
        Boolean previous = lastLaserEnableActive;
        if (previous != null && previous == laserEnableActive) {
            return;
        }
        lastLaserEnableActive = laserEnableActive;

        if (!laserEnableActive) {
            Log.d(TAG, "laser_enable_off trigger=" + trigger
                    + " grace_infer_ms=" + LiveInferGraceCoordinator.DEFAULT_GRACE_AFTER_LASER_OFF_MS);
            return;
        }
        if (manualAutoActive) {
            discardActiveRound("manual_auto_active");
            Log.d(TAG, "skip_auto_task trigger=" + trigger + " reason=manual_auto_active");
            return;
        }
        if (!AiAssistanceSettings.isZeroPointOffsetDetectionEnabled(appContext)) {
            if (shouldStartTaskOnLaserEnableRisingEdge(previous, laserEnableActive)) {
                Log.d(TAG, "skip_auto_task trigger=" + trigger + " reason=zero_point_detection_disabled");
            }
            return;
        }
        if (shouldStartTaskOnLaserEnableRisingEdge(previous, laserEnableActive)) {
            startRound(trigger);
        }
    }

    public void setManualAutoActive(boolean active) {
        manualAutoActive = active;
        if (active) {
            discardActiveRound("manual_auto_active");
        }
    }

    @Override
    public void onDetectResult(@NonNull StreamDetectEvent.DetectResult event) {
        if (!"zero_point".equals(event.module)) {
            return;
        }
        if (!attached || manualAutoActive || !LiveInferGraceCoordinator.getInstance().isLiveInferActive()) {
            return;
        }
        if (!AiAssistanceSettings.isZeroPointOffsetDetectionEnabled(appContext)) {
            return;
        }
        long eventId;
        int targetMode;
        int sampleIndex;
        synchronized (taskLock) {
            if (activeEventId == 0L) {
                return;
            }
            if (sampleSeq.get() >= ZeroPointDetectAlgorithmSelector.FRAMES_PER_DETECT_ROUND) {
                return;
            }
            eventId = activeEventId;
            targetMode = activeTargetMode;
            sampleIndex = sampleSeq.getAndIncrement();
        }
        ZeroPointDetectNativeSession.DetectOutcome outcome =
                ZeroPointDetectNativeSession.DetectOutcome.fromZeroPoint(
                        ZeroPointDetectJson.parse(event.summaryJson));
        handleSampleResult(
                eventId,
                sampleIndex,
                targetMode,
                outcome,
                event.imageWidth,
                event.imageHeight);
    }

    @Override
    public void onSessionStart(@NonNull StreamDetectEvent.SessionStart event) {
        // no-op
    }

    @Override
    public void onSessionStop(@NonNull StreamDetectEvent.SessionStop event) {
        // grace / finalize handled via LiveInferGraceCoordinator
    }

    @Override
    public void onPipelineState(@NonNull StreamDetectEvent.PipelineState event) {
        Log.d(TAG, "pipeline_state state=" + event.state + " detail=" + event.detail);
    }

    /** Package-visible legacy hook; daemon owns ZP context (always 0). */
    public long getZeroPointHandleForNative() {
        return 0L;
    }

    /** Package-visible for burst exit. */
    public boolean isRoundActive() {
        synchronized (taskLock) {
            return activeEventId > 0L;
        }
    }

    /** Package-visible for unit tests. */
    public void activateRoundForTest() {
        synchronized (taskLock) {
            activeEventId = 1L;
        }
    }

    /** Package-visible for unit tests. */
    public void deactivateRoundForTest() {
        synchronized (taskLock) {
            activeEventId = 0L;
        }
    }

    private void startRound(String trigger) {
        synchronized (taskLock) {
            discardActiveRoundLocked("retrigger");
            activeEventId = laserEventSeq.incrementAndGet();
            sampleSeq.set(0);
            validOffsetX.clear();
            validOffsetY.clear();
            ZeroPointPendingCorrectionStore.getInstance().clear();
            LaserDetectSamplingCoordinator.getInstance().onZeroPointRoundStart();
            activeTargetMode = ZeroPointDetectTargetMode.resolveFromTopActivity();
            AiDaemonSupervisor.getInstance()
                    .setStreamDetectZeroPointTargetMode(activeTargetMode);
            Log.i(TAG, "task_start eventId=" + activeEventId + " trigger=" + trigger
                    + " sampling=pr1_continuous"
                    + " algorithm=ZERO_POINT"
                    + " mode=" + ZeroPointDetectTargetMode.logName(activeTargetMode)
                    + " frames_per_round=" + ZeroPointDetectAlgorithmSelector.FRAMES_PER_DETECT_ROUND);
        }
    }

    private void handleSampleResult(long eventId,
                                    int sampleIndex,
                                    int targetMode,
                                    @NonNull ZeroPointDetectNativeSession.DetectOutcome outcome,
                                    int frameWidth,
                                    int frameHeight) {
        ZeroPointDetectJson.Sample sample = outcome.sample;
        synchronized (taskLock) {
            if (eventId != activeEventId || !attached) {
                return;
            }
            LaserDetectSamplingCoordinator.getInstance().reportDetectResult(
                    LaserDetectSamplingCoordinator.Module.ZERO_POINT,
                    sample.ok,
                    sample.code,
                    sample.reason);
            if (sample.ok) {
                validOffsetX.add(sample.offsetX);
                validOffsetY.add(sample.offsetY);
                Log.d(TAG, "sample_ok eventId=" + eventId
                        + " index=" + sampleIndex
                        + " trigger=pr1"
                        + " module=zero_point"
                        + " mode=" + ZeroPointDetectTargetMode.logName(targetMode)
                        + " offset_x=" + sample.offsetX
                        + " offset_y=" + sample.offsetY);
                ZeroPointOverlayPublisher.publishFromSample(appContext, sample, frameWidth, frameHeight);
            } else {
                String reason = sample.reason.isEmpty() ? "detect_fail" : sample.reason;
                Log.d(TAG, "detect_result module=zero_point eventId=" + eventId
                        + " index=" + sampleIndex
                        + " trigger=pr1"
                        + " mode=" + ZeroPointDetectTargetMode.logName(targetMode)
                        + " code=" + sample.code
                        + " reason=" + reason);
            }
        }
    }

    private void finalizeRoundOnLaserOff(String trigger) {
        synchronized (taskLock) {
            if (activeEventId == 0L) {
                return;
            }
            finalizeTaskLocked(trigger);
            activeEventId = 0L;
            validOffsetX.clear();
            validOffsetY.clear();
        }
        ZeroPointOverlayState.getInstance().clear();
    }

    private void finalizeTaskLocked(@NonNull String trigger) {
        if (!AiAssistanceSettings.isZeroPointOffsetDetectionEnabled(appContext)) {
            Log.d(TAG, "task_done trigger=" + trigger + " skip_finalize=zero_point_detection_disabled");
            return;
        }
        long eventId = activeEventId;
        ZeroPointDetectClusterReducer.Result reduced =
                ZeroPointDetectClusterReducer.reduce(validOffsetX, validOffsetY);
        boolean hadValidResult = reduced.hasRepresentative;
        if (!hadValidResult) {
            Log.w(TAG, "task_done eventId=" + eventId + " trigger=" + trigger
                    + " validSamples=0 skip_write=true"
                    + " algorithm=ZERO_POINT");
            return;
        }
        logClusterReduction(eventId, validOffsetX.size(), reduced);
        double meanOffsetX = reduced.representativeOffsetX;
        double meanOffsetY = reduced.representativeOffsetY;
        if (ZeroPointCorrectionMapper.isWithinPositionTolerance(meanOffsetX, meanOffsetY)) {
            Log.i(TAG, "task_done eventId=" + eventId + " trigger=" + trigger
                    + " validSamples=" + reduced.winnerClusterSize
                    + " skip_write=within_tolerance"
                    + " meanOffsetX=" + meanOffsetX
                    + " meanOffsetY=" + meanOffsetY
                    + " tolerancePx=" + ZeroPointCorrectionMapper.POSITION_TOLERANCE_PX);
            return;
        }
        Context context = appContext;
        if (context == null) {
            return;
        }
        if (!WeldAlertScope.isEligibleFromTopActivity()) {
            Log.d(TAG, "task_done eventId=" + eventId + " trigger=" + trigger
                    + " validSamples=" + reduced.winnerClusterSize
                    + " skip_alert=out_of_scope"
                    + " meanOffsetX=" + meanOffsetX
                    + " meanOffsetY=" + meanOffsetY);
            return;
        }
        ZeroPointPendingCorrectionStore.getInstance().setWeldResult(
                eventId,
                reduced.winnerClusterSize,
                meanOffsetX,
                meanOffsetY);
        Log.i(TAG, "task_done eventId=" + eventId + " trigger=" + trigger
                + " validSamples=" + reduced.winnerClusterSize
                + " pending_manual_auto=true"
                + " meanOffsetX=" + meanOffsetX
                + " meanOffsetY=" + meanOffsetY);
        WarnAlarmPipeline.onLiveWeldFaultSignaled(ZeroPointOffsetWarnAlarm.INSTANCE, context);
    }

    private static void logClusterReduction(long eventId,
                                            int rawSampleCount,
                                            @NonNull ZeroPointDetectClusterReducer.Result reduced) {
        Log.i(TAG, "cluster_reduce eventId=" + eventId
                + " rawSamples=" + rawSampleCount
                + " clusterCount=" + reduced.clusterCount
                + " winnerClusterSize=" + reduced.winnerClusterSize
                + " anchorRejected=" + reduced.anchorRejectedCount
                + " usedFullSampleClustering=" + reduced.usedFullSampleClustering
                + " representativeOffsetX=" + reduced.representativeOffsetX
                + " representativeOffsetY=" + reduced.representativeOffsetY);
    }

    private void discardActiveRound(String reason) {
        synchronized (taskLock) {
            discardActiveRoundLocked(reason);
        }
    }

    private void discardActiveRoundLocked(String reason) {
        if (activeEventId > 0L && reason != null) {
            Log.d(TAG, "task_cancel eventId=" + activeEventId + " reason=" + reason);
        }
        activeEventId = 0L;
        validOffsetX.clear();
        validOffsetY.clear();
    }

    /** Ensures ROI assets are deployed for daemon offline/live ZP (idempotent). */
    public void ensureNativeDetectorReady() {
        if (!attached) {
            return;
        }
        nativeSession.ensureReady(appContext);
    }

    private void destroyDetector() {
        nativeSession.destroy();
    }

    /** Package-visible for unit tests. */
    static boolean shouldStartTaskOnLaserEnableRisingEdge(
            @Nullable Boolean previousLaserEnableActive, boolean currentLaserEnableActive) {
        return previousLaserEnableActive != null
                && !previousLaserEnableActive
                && currentLaserEnableActive;
    }
}
