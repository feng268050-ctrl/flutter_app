package com.lasercyber.lws.ai.zeropoint;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ai.stream.NativeStreamDetectCoordinator;
import com.lasercyber.lws.ai.stream.StreamDetectEvent;
import com.lasercyber.lws.ai.stream.StreamDetectResultBus;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.camera.EasyPlayerClientManger;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.utils.VideoFileUtil;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicLong;

/**
 * State machine for manual Advanced Settings zero-offset auto correction.
 */
final class ZeroPointManualAutoWorkflow implements MemoryCacheManager.OnCacheChangedListener,
        StreamDetectResultBus.DetectResultListener,
        ZeroPointVideoAnalyzer.RunGuard {

    private static final String TAG = "ZeroPointManualAuto";
    private static final long ONLINE_SAMPLE_INTERVAL_MS = 500L;
    private static final long STOP_RECORDING_AFTER_LASER_OFF_MS = 3_000L;
    private static final long TEMP_RECORDING_TIMEOUT_MS = 10 * 60 * 1000L;

    private final Object lock = new Object();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final AtomicLong runSeq = new AtomicLong(0L);
    private final ExecutorService worker = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "zero-point-manual-auto");
        t.setPriority(Thread.NORM_PRIORITY - 1);
        return t;
    });
    private final ZeroPointLaserController laserController = new ZeroPointLaserController();
    private final ZeroPointVideoAnalyzer videoAnalyzer = new ZeroPointVideoAnalyzer();

    @Nullable
    private Context appContext;
    @Nullable
    private ZeroPointManualAutoCoordinator.Callback callback;
    @Nullable
    private Runnable onlineSampleRunnable;
    @Nullable
    private Runnable stopAfterLaserOffRunnable;
    @Nullable
    private Runnable autoLaserCloseRunnable;
    @Nullable
    private File tempVideoFile;
    private boolean manualStreamLeaseHeld;
    private boolean running;
    private boolean laserSeenOn;
    private boolean onlineSamplingActive;
    private boolean tempRecordingStarted;
    private boolean autoLaserCommandOpen;
    private boolean finalizeInFlight;
    private long activeRunId;
    private int onlineSampleCount;
    private final List<Double> onlineOffsetX = new ArrayList<>();
    private final List<Double> onlineOffsetY = new ArrayList<>();

    boolean start(@NonNull Context context, @NonNull ZeroPointManualAutoCoordinator.Callback callback) {
        long runId;
        ZeroPointPendingCorrectionStore.PendingCorrection pendingCorrection;
        synchronized (lock) {
            if (running) {
                return false;
            }
            pendingCorrection = ZeroPointPendingCorrectionStore.getInstance().consumeLatest();
            running = true;
            laserSeenOn = false;
            onlineSamplingActive = false;
            tempRecordingStarted = false;
            autoLaserCommandOpen = false;
            onlineSampleCount = 0;
            onlineOffsetX.clear();
            onlineOffsetY.clear();
            tempVideoFile = null;
            finalizeInFlight = false;
            manualStreamLeaseHeld = false;
            appContext = context.getApplicationContext();
            this.callback = callback;
            activeRunId = runSeq.incrementAndGet();
            runId = activeRunId;
        }
        if (pendingCorrection != null) {
            Log.i(TAG, "manual_auto start runId=" + runId + " path=pending_json"
                    + " eventId=" + pendingCorrection.eventId
                    + " validSamples=" + pendingCorrection.validSamples
                    + " meanOffsetX=" + pendingCorrection.meanOffsetX
                    + " meanOffsetY=" + pendingCorrection.meanOffsetY);
            postProgress(runId, 55, context.getString(R.string.zero_point_auto_progress_finalizing_online));
            ZeroPointPendingCorrectionStore.PendingCorrection pending = pendingCorrection;
            worker.execute(() -> completeWithPendingCorrection(runId, pending));
            return true;
        }
        ZeroPointDetectCoordinator.getInstance().setManualAutoActive(true);
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
        Log.i(TAG, "manual_auto start runId=" + runId + " path=full_flow");
        postProgress(runId, 3, context.getString(R.string.zero_point_auto_progress_waiting_laser));
        worker.execute(() -> startRecordingAndOpenLaser(runId));
        return true;
    }

    void cancel() {
        long runId;
        synchronized (lock) {
            if (!running) {
                return;
            }
            runId = activeRunId;
        }
        worker.execute(() -> {
            closeAutoLaserIfNeeded(runId, "cancel");
            stopTemporaryRecordingIfNeeded(runId);
            deleteTempVideo(runId);
            finishCancelled(runId);
        });
    }

    boolean isRunning() {
        synchronized (lock) {
            return running;
        }
    }

    @Override
    public void onCacheChanged(String key) {
        if (!CacheKey.DEVICE_STATUS_KEY.equals(key)) {
            return;
        }
        mainHandler.post(() -> applyLaserState("device_status"));
    }

    @Override
    public boolean isCurrentRun(long runId) {
        synchronized (lock) {
            return isCurrentRunLocked(runId);
        }
    }

    @Override
    @Nullable
    public Context context() {
        return appContext;
    }

    private void applyLaserState(@NonNull String trigger) {
        long runId;
        synchronized (lock) {
            if (!running) {
                return;
            }
            runId = activeRunId;
        }
        boolean laserOn = laserController.isPhysicallyOn();
        if (laserOn) {
            onLaserOn(runId, trigger);
        } else {
            onLaserOff(runId, trigger);
        }
    }

    private void onLaserOn(long runId, @NonNull String trigger) {
        boolean firstLaserOn;
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                return;
            }
            firstLaserOn = !laserSeenOn;
            laserSeenOn = true;
            if (stopAfterLaserOffRunnable != null) {
                mainHandler.removeCallbacks(stopAfterLaserOffRunnable);
                stopAfterLaserOffRunnable = null;
            }
        }
        if (!firstLaserOn) {
            if (!onlineSamplingActive) {
                scheduleOnlineSample(runId, ONLINE_SAMPLE_INTERVAL_MS);
            }
            return;
        }
        Log.i(TAG, "manual_auto laser_on runId=" + runId + " trigger=" + trigger);
        postProgress(runId, 10, stringForRun(R.string.zero_point_auto_progress_online));
        if (isTempRecordingStarted(runId)) {
            mainHandler.post(() -> scheduleOnlineSample(runId, ONLINE_SAMPLE_INTERVAL_MS));
        } else {
            worker.execute(() -> startRecordingAndLiveStream(runId));
        }
    }

    private void onLaserOff(long runId, @NonNull String trigger) {
        synchronized (lock) {
            if (!scheduleRecordingTailStopLocked(runId, false)) {
                return;
            }
        }
        Log.i(TAG, "manual_auto laser_off runId=" + runId + " trigger=" + trigger);
        postProgress(runId, 50, stringForRun(R.string.zero_point_auto_progress_recording_tail));
    }

    private boolean scheduleRecordingTailStopLocked(long runId, boolean force) {
        if (!isCurrentRunLocked(runId) || (!force && !laserSeenOn)) {
            return false;
        }
        if (!onlineSamplingActive && stopAfterLaserOffRunnable != null) {
            return false;
        }
        onlineSamplingActive = false;
        if (onlineSampleRunnable != null) {
            mainHandler.removeCallbacks(onlineSampleRunnable);
            onlineSampleRunnable = null;
        }
        stopAfterLaserOffRunnable = () -> finishRecordingAndDetect(runId);
        mainHandler.postDelayed(stopAfterLaserOffRunnable, STOP_RECORDING_AFTER_LASER_OFF_MS);
        return true;
    }

    private boolean startRecordingAndLiveStream(long runId) {
        if (!isCurrentRun(runId)) {
            return false;
        }
        Context context = appContext;
        if (context == null) {
            failMethod2(runId);
            return false;
        }
        File tempFile = VideoFileUtil.getMovieName(ZeroPointVideoAnalyzer.AUTO_TEMP_VIDEO_DIR_KEY);
        boolean recordingStarted = EasyPlayerClientManger.getInstance()
                .startTemporaryRecording(tempFile.getAbsolutePath(), TEMP_RECORDING_TIMEOUT_MS);
        if (!recordingStarted) {
            Log.w(TAG, "manual_auto temp_record_start_failed runId=" + runId
                    + " path=" + tempFile.getAbsolutePath());
            failMethod2(runId);
            return false;
        }
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                EasyPlayerClientManger.getInstance().stopTemporaryRecording();
                ZeroPointVideoAnalyzer.quietDelete(tempFile);
                return false;
            }
            tempVideoFile = tempFile;
            tempRecordingStarted = true;
        }

        startManualLiveStreamIfNeeded(context, runId);
        mainHandler.post(() -> scheduleOnlineSample(runId, ONLINE_SAMPLE_INTERVAL_MS));
        return true;
    }

    private void startRecordingAndOpenLaser(long runId) {
        Context context = appContext;
        if (context == null || !laserController.prepareWeldContext(context, runId) || !isCurrentRun(runId)) {
            failMethod2(runId);
            return;
        }
        if (!startRecordingAndLiveStream(runId)) {
            return;
        }
        openAutoLaser(runId);
    }

    private boolean isTempRecordingStarted(long runId) {
        synchronized (lock) {
            return isCurrentRunLocked(runId) && tempRecordingStarted;
        }
    }

    private void openAutoLaser(long runId) {
        if (!isCurrentRun(runId)) {
            return;
        }
        laserController.openLaser(runId, new ZeroPointLaserController.OpenCallback() {
            @Override
            public void onSuccess() {
                synchronized (lock) {
                    if (!isCurrentRunLocked(runId)) {
                        laserController.closeLaserQuietly(runId, "open_after_cancel");
                        return;
                    }
                    autoLaserCommandOpen = true;
                }
                mainHandler.post(() -> {
                    applyLaserState("manual_auto_modbus_open");
                    scheduleAutoLaserClose(runId);
                });
            }

            @Override
            public void onFailure() {
                worker.execute(() -> {
                    stopTemporaryRecordingIfNeeded(runId);
                    deleteTempVideo(runId);
                    failMethod2(runId);
                });
            }
        });
    }

    private void scheduleAutoLaserClose(long runId) {
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                return;
            }
            Runnable previous = autoLaserCloseRunnable;
            autoLaserCloseRunnable = () -> worker.execute(() -> closeAutoLaser(runId, "pulse_timeout"));
            laserController.scheduleAutoClose(runId, mainHandler, autoLaserCloseRunnable, previous);
        }
    }

    private void closeAutoLaserIfNeeded(long runId, @NonNull String reason) {
        boolean shouldClose;
        synchronized (lock) {
            shouldClose = isCurrentRunLocked(runId) && autoLaserCommandOpen;
            laserController.cancelScheduledClose(mainHandler, autoLaserCloseRunnable);
            autoLaserCloseRunnable = null;
            autoLaserCommandOpen = false;
        }
        if (shouldClose) {
            laserController.closeLaserQuietly(runId, reason);
        }
    }

    private void closeAutoLaser(long runId, @NonNull String reason) {
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                return;
            }
            autoLaserCommandOpen = false;
            laserController.cancelScheduledClose(mainHandler, autoLaserCloseRunnable);
            autoLaserCloseRunnable = null;
        }
        laserController.closeLaser(runId, reason, new ModbusManagerRtu.WriteCallback() {
            @Override
            public void onSuccess() {
                Log.i(TAG, "manual_auto laser_modbus_close runId=" + runId + " reason=" + reason);
                mainHandler.post(() -> onAutoLaserClosed(runId, reason));
            }

            @Override
            public void onFailure() {
                Log.w(TAG, "manual_auto laser_modbus_close_failed runId=" + runId + " reason=" + reason);
                mainHandler.post(() -> onAutoLaserClosed(runId, reason + "_close_failed"));
            }
        });
    }

    private void onAutoLaserClosed(long runId, @NonNull String reason) {
        boolean sawPhysicalLaser;
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                return;
            }
            sawPhysicalLaser = laserSeenOn;
            if (!sawPhysicalLaser) {
                Log.w(TAG, "manual_auto no_physical_laser runId=" + runId + " reason=" + reason);
            }
            if (!scheduleRecordingTailStopLocked(runId, true)) {
                return;
            }
        }
        if (!sawPhysicalLaser) {
            worker.execute(() -> {
                stopTemporaryRecordingIfNeeded(runId);
                deleteTempVideo(runId);
                failMethod2(runId);
            });
            return;
        }
        Log.i(TAG, "manual_auto laser_auto_closed runId=" + runId + " reason=" + reason);
        postProgress(runId, 50, stringForRun(R.string.zero_point_auto_progress_recording_tail));
    }

    private void startManualLiveStreamIfNeeded(@NonNull Context context, long runId) {
        if (NativeStreamDetectCoordinator.getInstance().acquireManualZeroPoint(context)) {
            synchronized (lock) {
                if (isCurrentRunLocked(runId)) {
                    manualStreamLeaseHeld = true;
                }
            }
            StreamDetectResultBus.getInstance().addListener(this);
        } else {
            Log.w(TAG, "manual_auto native_stream_start_failed runId=" + runId);
        }
    }

    private void scheduleOnlineSample(long runId, long delayMs) {
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                return;
            }
            if (!laserController.isPhysicallyOn()) {
                onlineSamplingActive = false;
                return;
            }
            onlineSamplingActive = true;
            if (onlineSampleRunnable != null) {
                mainHandler.removeCallbacks(onlineSampleRunnable);
            }
            onlineSampleRunnable = () -> onlineSampleTick(runId);
            mainHandler.postDelayed(onlineSampleRunnable, delayMs);
        }
    }

    private void onlineSampleTick(long runId) {
        int sampleIndex;
        synchronized (lock) {
            if (!isCurrentRunLocked(runId) || !onlineSamplingActive || !laserController.isPhysicallyOn()) {
                return;
            }
            sampleIndex = onlineSampleCount;
        }
        int progress = Math.min(45, 15 + sampleIndex * 3);
        postProgress(runId, progress, stringForRun(R.string.zero_point_auto_progress_online));
        if (ZeroPointMockJsonLoader.mockFileExists()) {
            worker.execute(() -> runOnlineMockSample(runId, sampleIndex));
        }
        scheduleOnlineSample(runId, ONLINE_SAMPLE_INTERVAL_MS);
    }

    private void runOnlineMockSample(long runId, int sampleIndex) {
        ZeroPointDetectJson.Sample sample = ZeroPointMockJsonLoader.tryLoadSample();
        if (sample == null) {
            return;
        }
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                return;
            }
            onlineSampleCount++;
            if (sample.ok) {
                onlineOffsetX.add(sample.offsetX);
                onlineOffsetY.add(sample.offsetY);
                Log.i(TAG, "manual_auto online_sample_ok runId=" + runId
                        + " index=" + sampleIndex
                        + " offset_x=" + sample.offsetX
                        + " offset_y=" + sample.offsetY);
            }
        }
    }

    @Override
    public void onDetectResult(@NonNull StreamDetectEvent.DetectResult event) {
        if (!"zero_point".equals(event.module)) {
            return;
        }
        long runId;
        int sampleIndex;
        synchronized (lock) {
            if (!onlineSamplingActive || !isCurrentRunLocked(activeRunId)) {
                return;
            }
            runId = activeRunId;
            sampleIndex = onlineSampleCount++;
        }
        ZeroPointDetectJson.Sample sample = ZeroPointMockJsonLoader.tryLoadSample();
        if (sample == null) {
            sample = ZeroPointDetectJson.parse(event.summaryJson);
        }
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                return;
            }
            if (sample.ok) {
                onlineOffsetX.add(sample.offsetX);
                onlineOffsetY.add(sample.offsetY);
                Log.i(TAG, "manual_auto online_sample_ok runId=" + runId
                        + " index=" + sampleIndex
                        + " offset_x=" + sample.offsetX
                        + " offset_y=" + sample.offsetY);
                ZeroPointOverlayPublisher.publishFromSample(
                        appContext, sample, event.imageWidth, event.imageHeight);
            } else {
                String reason = sample.reason.isEmpty() ? "detect_fail" : sample.reason;
                Log.d(TAG, "detect_result module=zero_point runId=" + runId
                        + " index=" + sampleIndex
                        + " code=" + sample.code
                        + " reason=" + reason);
            }
        }
    }

    @Override
    public void onSessionStart(@NonNull StreamDetectEvent.SessionStart event) {
    }

    @Override
    public void onSessionStop(@NonNull StreamDetectEvent.SessionStop event) {
    }

    @Override
    public void onPipelineState(@NonNull StreamDetectEvent.PipelineState event) {
    }

    private void finishRecordingAndDetect(long runId) {
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                return;
            }
            if (finalizeInFlight) {
                Log.d(TAG, "manual_auto finalize_skip runId=" + runId + " reason=already_in_flight");
                return;
            }
            finalizeInFlight = true;
            stopAfterLaserOffRunnable = null;
        }
        postProgress(runId, 55, stringForRun(R.string.zero_point_auto_progress_finalizing_online));
        worker.execute(() -> finishRecordingAndDetectOnWorker(runId));
    }

    private void finishRecordingAndDetectOnWorker(long runId) {
        stopTemporaryRecordingIfNeeded(runId);
        SystemClock.sleep(300L);
        try {
            ZeroPointManualAutoStageAggregate online = snapshotOnlineAggregate(runId, "online_500ms");
            if (online.hasValidSamples()) {
                completeWithMeasuredAggregate(runId, online);
                return;
            }
            Log.i(TAG, "manual_auto finalize_online_empty runId=" + runId
                    + " validSamples=" + online.validSamples);

            File video = resolveTempVideoForOffline(runId);
            if (video == null) {
                Log.w(TAG, "manual_auto missing_temp_video runId=" + runId + " path=null");
                failMethod2(runId);
                return;
            }

            postProgress(runId, 60, stringForRun(R.string.zero_point_auto_progress_offline_200));
            ZeroPointManualAutoStageAggregate offline200 = runOfflineStage(runId, video, 200L, "offline_200ms", 60, 78);
            if (offline200.hasValidSamples()) {
                completeWithMeasuredAggregate(runId, offline200);
                return;
            }

            postProgress(runId, 80, stringForRun(R.string.zero_point_auto_progress_offline_100));
            ZeroPointManualAutoStageAggregate offline100 = runOfflineStage(runId, video, 100L, "offline_100ms", 80, 96);
            if (offline100.hasValidSamples()) {
                completeWithMeasuredAggregate(runId, offline100);
                return;
            }

            failMethod2(runId);
        } finally {
            deleteTempVideo(runId);
        }
    }

    @NonNull
    private ZeroPointManualAutoStageAggregate snapshotOnlineAggregate(long runId, @NonNull String stageName) {
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                return ZeroPointManualAutoStageAggregate.empty(stageName);
            }
            return ZeroPointManualAutoStageAggregate.from(stageName, onlineOffsetX, onlineOffsetY);
        }
    }

    @NonNull
    private ZeroPointManualAutoStageAggregate runOfflineStage(long runId,
                                                              @NonNull File video,
                                                              long intervalMs,
                                                              @NonNull String stageName,
                                                              int progressStart,
                                                              int progressEnd) {
        return videoAnalyzer.runOfflineStage(
                runId,
                video,
                intervalMs,
                stageName,
                progressStart,
                progressEnd,
                this,
                (id, percent, stageIntervalMs) -> postProgress(
                        id,
                        percent,
                        stageIntervalMs == 200L
                                ? stringForRun(R.string.zero_point_auto_progress_offline_200)
                                : stringForRun(R.string.zero_point_auto_progress_offline_100)));
    }

    private void completeWithMeasuredAggregate(long runId, @NonNull ZeroPointManualAutoStageAggregate aggregate) {
        Context context = appContext;
        if (context == null || !isCurrentRun(runId)) {
            return;
        }
        ZeroPointCorrectionWriter.ApplyResult applyResult =
                ZeroPointCorrectionWriter.applyAbsoluteFromZeroBaseline(
                        context,
                        runId,
                        aggregate.meanOffsetX,
                        aggregate.meanOffsetY);
        finishAggregateCompletion(runId, aggregate, applyResult);
    }

    private void completeWithPendingAggregate(long runId, @NonNull ZeroPointManualAutoStageAggregate aggregate) {
        Context context = appContext;
        if (context == null || !isCurrentRun(runId)) {
            return;
        }
        int uiDelta = ZeroPointCorrectionMapper.isWithinPositionTolerance(
                aggregate.meanOffsetX,
                aggregate.meanOffsetY)
                ? 0
                : ZeroPointCorrectionMapper.uiDeltaFromOffsetPx(aggregate.meanOffsetX);
        ZeroPointCorrectionWriter.ApplyResult applyResult =
                ZeroPointCorrectionWriter.applyIncrementalCorrection(
                        context,
                        uiDelta,
                        runId,
                        aggregate.meanOffsetX,
                        aggregate.meanOffsetY);
        finishAggregateCompletion(runId, aggregate, applyResult);
    }

    private void finishAggregateCompletion(long runId,
                                           @NonNull ZeroPointManualAutoStageAggregate aggregate,
                                           @NonNull ZeroPointCorrectionWriter.ApplyResult applyResult) {
        ZeroPointManualAutoCoordinator.CompletionResult result =
                new ZeroPointManualAutoCoordinator.CompletionResult(
                        aggregate.stageName,
                        aggregate.validSamples,
                        aggregate.meanOffsetX,
                        aggregate.meanOffsetY,
                        applyResult.currentUi,
                        applyResult.newUi,
                        applyResult.uiDelta,
                        applyResult.changed);
        postProgress(runId, 100, stringForRun(R.string.zero_point_auto_progress_success));
        finishSuccess(runId, result);
    }

    private void completeWithPendingCorrection(
            long runId,
            @NonNull ZeroPointPendingCorrectionStore.PendingCorrection pendingCorrection) {
        Log.i(TAG, "manual_auto pending_json_apply runId=" + runId
                + " eventId=" + pendingCorrection.eventId
                + " validSamples=" + pendingCorrection.validSamples
                + " meanOffsetX=" + pendingCorrection.meanOffsetX
                + " meanOffsetY=" + pendingCorrection.meanOffsetY);
        completeWithPendingAggregate(runId, ZeroPointManualAutoStageAggregate.from(pendingCorrection));
    }

    private boolean isCurrentRunLocked(long runId) {
        return running && activeRunId == runId;
    }

    private void postProgress(long runId, int percent, @NonNull String message) {
        mainHandler.post(() -> {
            ZeroPointManualAutoCoordinator.Callback cb;
            synchronized (lock) {
                if (!isCurrentRunLocked(runId)) {
                    return;
                }
                cb = callback;
            }
            if (cb != null) {
                cb.onProgress(percent, message);
            }
        });
    }

    @NonNull
    private String stringForRun(int resId) {
        Context context = appContext;
        if (context == null) {
            return "";
        }
        return context.getString(resId);
    }

    @NonNull
    private String method2FailureMessage() {
        return stringForRun(R.string.zero_point_auto_correction_failed);
    }

    private void failMethod2(long runId) {
        fail(runId, method2FailureMessage());
    }

    private void fail(long runId, @NonNull String message) {
        mainHandler.post(() -> finishFailureOnMain(runId, message));
    }

    private void finishSuccess(long runId, @NonNull ZeroPointManualAutoCoordinator.CompletionResult result) {
        mainHandler.post(() -> finishSuccessOnMain(runId, result));
    }

    private void finishCancelled(long runId) {
        mainHandler.post(() -> finishCancelledOnMain(runId));
    }

    private void finishSuccessOnMain(long runId, @NonNull ZeroPointManualAutoCoordinator.CompletionResult result) {
        ZeroPointManualAutoCoordinator.Callback cb = cleanupRunOnMain(runId);
        if (cb != null) {
            cb.onComplete(result);
        }
    }

    private void finishFailureOnMain(long runId, @NonNull String message) {
        ZeroPointManualAutoCoordinator.Callback cb = cleanupRunOnMain(runId);
        if (cb != null) {
            cb.onFailure(message);
        }
    }

    private void finishCancelledOnMain(long runId) {
        ZeroPointManualAutoCoordinator.Callback cb = cleanupRunOnMain(runId);
        if (cb != null) {
            cb.onCancelled();
        }
    }

    @Nullable
    private ZeroPointManualAutoCoordinator.Callback cleanupRunOnMain(long runId) {
        ZeroPointManualAutoCoordinator.Callback cb;
        boolean releaseManualStream;
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                return null;
            }
            if (onlineSampleRunnable != null) {
                mainHandler.removeCallbacks(onlineSampleRunnable);
                onlineSampleRunnable = null;
            }
            if (stopAfterLaserOffRunnable != null) {
                mainHandler.removeCallbacks(stopAfterLaserOffRunnable);
                stopAfterLaserOffRunnable = null;
            }
            laserController.cancelScheduledClose(mainHandler, autoLaserCloseRunnable);
            autoLaserCloseRunnable = null;
            cb = callback;
            releaseManualStream = manualStreamLeaseHeld;
            running = false;
            laserSeenOn = false;
            onlineSamplingActive = false;
            tempRecordingStarted = false;
            autoLaserCommandOpen = false;
            finalizeInFlight = false;
            callback = null;
            appContext = null;
            tempVideoFile = null;
            manualStreamLeaseHeld = false;
            laserController.reset();
            onlineOffsetX.clear();
            onlineOffsetY.clear();
        }
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
        ZeroPointDetectCoordinator.getInstance().setManualAutoActive(false);
        if (releaseManualStream) {
            StreamDetectResultBus.getInstance().removeListener(this);
            NativeStreamDetectCoordinator.getInstance().releaseManualZeroPoint("manual_auto_finish");
        }
        return cb;
    }

    private void stopTemporaryRecordingIfNeeded(long runId) {
        boolean shouldStop;
        synchronized (lock) {
            shouldStop = isCurrentRunLocked(runId) && tempRecordingStarted;
            tempRecordingStarted = false;
        }
        if (shouldStop) {
            EasyPlayerClientManger.getInstance().stopTemporaryRecording();
        }
    }

    private void deleteTempVideo(long runId) {
        File file;
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                return;
            }
            file = tempVideoFile;
        }
        ZeroPointVideoAnalyzer.quietDelete(file);
    }

    @Nullable
    private File resolveTempVideoForOffline(long runId) {
        File held;
        synchronized (lock) {
            if (!isCurrentRunLocked(runId)) {
                return null;
            }
            held = tempVideoFile;
        }
        File resolved = videoAnalyzer.resolveTempVideo(held, runId);
        if (resolved != null && resolved != held) {
            synchronized (lock) {
                if (isCurrentRunLocked(runId)) {
                    tempVideoFile = resolved;
                }
            }
        }
        return resolved;
    }
}
