package com.lasercyber.lws.ui.common.ai.video;

import android.content.Context;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ai.sampling.AiFrameSamplingInterval;
import com.lasercyber.lws.ai.Nv12FrameUtil;
import com.lasercyber.lws.ai.model.AiStainDetectResult;
import com.lasercyber.lws.ai.engine.AiManager;
import com.lasercyber.lws.ai.stain.AiStainDetectResultMapper;
import com.lasercyber.lws.ai.AiDetectOverlayFrames;
import com.lasercyber.lws.ai.stain.LensDetConsecutiveOkFilter;
import com.lasercyber.lws.ai.stain.LensStainBoxTemporalReducer;
import com.lasercyber.lws.ai.stain.StainDetectAlertMapper;
import com.lasercyber.lws.ai.model.StainDetectSource;
import com.lasercyber.lws.ai.model.OpencvStainDetectResult;
import com.lasercyber.lws.ui.bean.event.LensCheckResultEvent;
import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.network.http.local.AiInferenceSseHub;
import com.lasercyber.lws.ui.network.http.local.AiInferenceSseJson;

import org.greenrobot.eventbus.EventBus;

import java.io.File;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.UUID;

/**
 * Real-time AI Vision processing for one process video: timeline inference, SSE fan-out,
 * and playback clock for UI overlay sync.
 */
public final class ProcessVideoAiSession {

    public enum CreateFailure {
        NONE,
        SOURCE_INVALID,
        OFFLINE_JNI_UNAVAILABLE,
        ENGINE_NOT_RUNNING,
        DURATION_UNAVAILABLE
    }

    public static final class CreateResult {
        @Nullable
        private final ProcessVideoAiSession session;
        @NonNull
        private final CreateFailure failure;

        private CreateResult(@Nullable ProcessVideoAiSession session, @NonNull CreateFailure failure) {
            this.session = session;
            this.failure = failure;
        }

        @NonNull
        public static CreateResult success(@NonNull ProcessVideoAiSession session) {
            return new CreateResult(session, CreateFailure.NONE);
        }

        @NonNull
        public static CreateResult failure(@NonNull CreateFailure failure) {
            return new CreateResult(null, failure);
        }

        @Nullable
        public ProcessVideoAiSession getSession() {
            return session;
        }

        @NonNull
        public CreateFailure getFailure() {
            return failure;
        }

        public boolean isSuccess() {
            return session != null;
        }
    }

    private static final String TAG = LogTAGConstant.PROCESS_VIDEO_AI_HTTP;
    private static final int PLAYBACK_FPS = 15;
    private static final long PLAYBACK_FRAME_STEP_MS = 1000L / PLAYBACK_FPS;
    private static final long PLAYBACK_TICK_MS = PLAYBACK_FRAME_STEP_MS;

    private final Context appContext;
    private final ProcessParamsVideoVo processVideo;
    private final File sourceFile;
    private final String cacheKey;
    private final File finalMp4;
    private final File tmpMp4;
    private final ProcessVideoAiTimeline timeline;
    private final List<StainDetectSample> stainDetectSamples = new ArrayList<>();
    private final AtomicLong stainDetectInferTotalMs = new AtomicLong();
    private final AtomicInteger stainDetectInferCount = new AtomicInteger();
    private final long durationMs;
    private final AiInferenceSseHub sseHub;
    @Nullable
    private volatile String sseSessionId;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final HandlerThread workerThread;
    private final Handler workerHandler;
    private final AtomicInteger uiRefs = new AtomicInteger();
    private final AtomicInteger httpRefs = new AtomicInteger();
    private final AtomicBoolean running = new AtomicBoolean(false);
    private final AtomicBoolean finalized = new AtomicBoolean(false);
    private final Object subscriberLock = new Object();
    private final List<SseHttpSubscriber> sseHttpSubscribers = new ArrayList<>();

    private volatile long playbackPositionMs;
    private long nextClockPositionMs;
    private volatile boolean playbackEnded;
    private volatile boolean playbackPaused;

    public interface OnFinalizeListener {
        void onFinalized(@NonNull ProcessVideoAiSession session, boolean mp4Ready);
    }

    public interface OnPlaybackEndedListener {
        void onPlaybackEnded(@NonNull ProcessVideoAiSession session);
    }

    /** Called on the main thread when a timeline sample is appended. */
    public interface OnTimelineFrameListener {
        void onTimelineFrameAdded(long sampleMs, @NonNull ProcessVideoAiTimeline.Frame frame);
    }

    @Nullable
    private volatile OnFinalizeListener finalizeListener;
    @Nullable
    private volatile OnPlaybackEndedListener playbackEndedListener;
    @Nullable
    private volatile OnTimelineFrameListener timelineFrameListener;

    private final ExecutorService inferExecutor;
    private final Nv12FrameUtil.DirectBufferPool nv12Pool = new Nv12FrameUtil.DirectBufferPool();
    private volatile long lastScheduledSampleMs = -1L;
    @Nullable
    private volatile String classificationLine;
    @Nullable
    private volatile String pendingStopReason;

    private ProcessVideoAiSession(@NonNull Context appContext,
                                  @NonNull ProcessParamsVideoVo processVideo,
                                  @NonNull File sourceFile,
                                  @NonNull String cacheKey,
                                  long durationMs) {
        this.appContext = appContext;
        this.processVideo = processVideo;
        this.sourceFile = sourceFile;
        this.cacheKey = cacheKey;
        this.finalMp4 = ProcessVideoAiInferencePaths.inferenceMp4(appContext, processVideo, cacheKey);
        this.tmpMp4 = ProcessVideoAiInferencePaths.inferenceMp4Tmp(finalMp4);
        this.durationMs = durationMs;
        this.timeline = new ProcessVideoAiTimeline(
                cacheKey,
                durationMs,
                AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO.getIntervalMs());
        this.sseHub = AiInferenceSseHub.forProcessVideo(TAG, () -> playbackPositionMs);
        this.workerThread = new HandlerThread("process-video-ai-" + cacheKey.substring(0, 8));
        this.workerThread.start();
        this.workerHandler = new Handler(workerThread.getLooper());
        this.inferExecutor = Executors.newSingleThreadExecutor(r -> {
            Thread t = new Thread(r, "process-video-infer-" + cacheKey.substring(0, 8));
            t.setPriority(Thread.NORM_PRIORITY - 1);
            return t;
        });
    }

    @NonNull
    static CreateResult tryCreate(@NonNull Context appContext,
                                  @NonNull ProcessParamsVideoVo processVideo,
                                  @NonNull File sourceFile,
                                  @NonNull String cacheKey) {
        if (!sourceFile.isFile() || sourceFile.length() <= 0L) {
            return CreateResult.failure(CreateFailure.SOURCE_INVALID);
        }
        if (!isProcessVideoOfflineInferenceAvailable()) {
            Log.w(TAG, "process video offline infer unavailable lens_det session missing");
            return CreateResult.failure(CreateFailure.OFFLINE_JNI_UNAVAILABLE);
        }
        if (!isEngineReadyForOfflineInference()) {
            Log.w(TAG, "offline infer engine not ready (OpenCV lens_det)");
            return CreateResult.failure(CreateFailure.ENGINE_NOT_RUNNING);
        }
        long durationMs = resolveDurationMs(appContext, processVideo, sourceFile);
        if (durationMs <= 0L) {
            Log.w(TAG, "video duration unavailable");
            return CreateResult.failure(CreateFailure.DURATION_UNAVAILABLE);
        }
        return CreateResult.success(
                new ProcessVideoAiSession(appContext, processVideo, sourceFile, cacheKey, durationMs));
    }

    @NonNull
    public String getCacheKey() {
        return cacheKey;
    }

    @NonNull
    public String getVideoId() {
        String id = processVideo.getVideoId();
        return id == null ? "" : id;
    }

    @NonNull
    public ProcessVideoAiTimeline getTimeline() {
        return timeline;
    }

    @Nullable
    public OpencvStainDetectResult findStainDetectResultAt(long positionMs) {
        synchronized (stainDetectSamples) {
            if (stainDetectSamples.isEmpty()) {
                return null;
            }
            StainDetectSample selected = stainDetectSamples.get(0);
            for (StainDetectSample sample : stainDetectSamples) {
                if (sample.timeMs <= positionMs) {
                    selected = sample;
                } else {
                    break;
                }
            }
            return selected.result;
        }
    }

    public void setClassificationLine(@Nullable String line) {
        if (line == null || line.trim().isEmpty()) {
            classificationLine = null;
        } else {
            classificationLine = line.trim();
        }
    }

    @Nullable
    public String getClassificationLine() {
        return classificationLine;
    }

    public boolean isRunning() {
        return running.get() && !finalized.get();
    }

    /** Legacy composited MP4 artifact; no longer produced by this session. */
    public boolean isFinalMp4Ready() {
        return finalMp4.isFile() && finalMp4.length() > 0L;
    }

    public void setOnFinalizeListener(@Nullable OnFinalizeListener listener) {
        finalizeListener = listener;
    }

    public void setOnPlaybackEndedListener(@Nullable OnPlaybackEndedListener listener) {
        playbackEndedListener = listener;
    }

    public void setOnTimelineFrameListener(@Nullable OnTimelineFrameListener listener) {
        timelineFrameListener = listener;
    }

    public long getPlaybackPositionMs() {
        return playbackPositionMs;
    }

    public boolean isPlaybackPaused() {
        return playbackPaused;
    }

    public boolean hasPlaybackEnded() {
        return playbackEnded;
    }

    public void pausePlaybackClock() {
        playbackPaused = !playbackEnded;
    }

    public void resumePlaybackClock() {
        if (!playbackEnded) {
            playbackPaused = false;
        }
    }

    @NonNull
    public File getFinalMp4File() {
        return finalMp4;
    }

    public void addRef(@NonNull ProcessVideoAiSessionRegistry.Holder holder) {
        if (holder == ProcessVideoAiSessionRegistry.Holder.UI) {
            uiRefs.incrementAndGet();
        } else {
            httpRefs.incrementAndGet();
        }
    }

    public int releaseRef(@NonNull ProcessVideoAiSessionRegistry.Holder holder) {
        if (holder == ProcessVideoAiSessionRegistry.Holder.UI) {
            uiRefs.decrementAndGet();
        } else {
            httpRefs.decrementAndGet();
        }
        return uiRefs.get() + httpRefs.get();
    }

    public boolean start() {
        if (!running.compareAndSet(false, true)) {
            return true;
        }
        deleteArtifacts();
        playbackPositionMs = 0L;
        nextClockPositionMs = 0L;
        playbackEnded = false;
        playbackPaused = false;
        lastScheduledSampleMs = -1L;
        synchronized (stainDetectSamples) {
            stainDetectSamples.clear();
        }
        stainDetectInferTotalMs.set(0L);
        stainDetectInferCount.set(0);
        AiManager.getInstance().resetOpencvProcessVideoFrameSampling();
        sseSessionId = UUID.randomUUID().toString();
        sseHub.notifySessionStarted(new AiInferenceSseJson.SessionStart(
                sseSessionId,
                StainDetectSource.OFFLINE,
                AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO.getIntervalMs(),
                null,
                null));
        mainHandler.post(clockTickRunnable);
        Log.i(TAG, "session start videoId=" + getVideoId() + " cacheKey=" + cacheKey
                + " durationMs=" + durationMs);
        return true;
    }

    public void stop(boolean forceDeleteArtifacts) {
        stop(forceDeleteArtifacts, forceDeleteArtifacts ? "force_restart" : "release");
    }

    public void stop(boolean forceDeleteArtifacts, @NonNull String stopReason) {
        if (!running.compareAndSet(true, false)) {
            if (forceDeleteArtifacts) {
                deleteArtifacts();
            }
            return;
        }
        AiManager.getInstance().resetOpencvProcessVideoFrameSampling();
        mainHandler.removeCallbacks(clockTickRunnable);
        playbackEnded = true;
        pendingStopReason = stopReason;
        if (forceDeleteArtifacts) {
            inferExecutor.shutdownNow();
        } else {
            inferExecutor.shutdown();
        }
        workerHandler.post(() -> {
            finalizeSessionOnWorker(forceDeleteArtifacts);
            workerThread.quitSafely();
        });
        Log.i(TAG, "session stop videoId=" + getVideoId() + " forceDelete=" + forceDeleteArtifacts
                + " reason=" + stopReason);
    }

    public void onPlaybackEnded() {
        if (playbackEnded) {
            return;
        }
        playbackEnded = true;
        running.set(false);
        mainHandler.removeCallbacks(clockTickRunnable);
        pendingStopReason = "session_complete";
        inferExecutor.shutdown();
        workerHandler.post(() -> finalizeSessionOnWorker(false));
        mainHandler.post(this::notifyPlaybackEnded);
    }

    private long stopMediaTimestampMs() {
        if (durationMs > 0L) {
            return durationMs;
        }
        return Math.max(0L, playbackPositionMs);
    }

    private void publishSessionStop(@NonNull String reason, long mediaTimestampMs) {
        String sessionId = sseSessionId;
        if (sessionId == null) {
            return;
        }
        sseSessionId = null;
        sseHub.notifySessionStopped(sessionId, reason, mediaTimestampMs);
    }

    private void notifyPlaybackEnded() {
        OnPlaybackEndedListener listener = playbackEndedListener;
        if (listener != null) {
            listener.onPlaybackEnded(this);
        }
    }

    @Nullable
    public SseHttpSubscriber acquireSseSubscriber() {
        if (!running.get()) {
            return null;
        }
        synchronized (subscriberLock) {
            AiInferenceSseHub.SseSubscriber delegate = sseHub.acquireSubscriber();
            SseHttpSubscriber sub = new SseHttpSubscriber(this, delegate);
            sseHttpSubscribers.add(sub);
            return sub;
        }
    }

    void releaseSseSubscriber(@NonNull SseHttpSubscriber subscriber) {
        synchronized (subscriberLock) {
            if (!sseHttpSubscribers.remove(subscriber)) {
                return;
            }
            subscriber.close();
        }
    }

    private final Runnable clockTickRunnable = new Runnable() {
        @Override
        public void run() {
            if (!running.get() || playbackEnded || playbackPaused) {
                if (running.get() && !playbackEnded) {
                    mainHandler.postDelayed(this, PLAYBACK_TICK_MS);
                }
                return;
            }
            workerHandler.post(ProcessVideoAiSession.this::clockTickOnWorker);
            if (running.get() && !playbackEnded) {
                mainHandler.postDelayed(this, PLAYBACK_TICK_MS);
            }
        }
    };

    private void scheduleInferSample(long sampleMs) {
        if (!running.get() || playbackEnded || sampleMs < 0L) {
            return;
        }
        if (sampleMs <= lastScheduledSampleMs) {
            return;
        }
        if (timeline.hasSampleAt(sampleMs)) {
            lastScheduledSampleMs = sampleMs;
            return;
        }
        lastScheduledSampleMs = sampleMs;
        try {
            inferExecutor.execute(() -> runInferSample(sampleMs));
        } catch (RejectedExecutionException e) {
            Log.w(TAG, "infer task rejected at " + sampleMs);
        }
    }

    /**
     * Queued infer tasks continue after {@link #playbackEnded} so samples scheduled during 1×
     * playback are not dropped when native infer is slower than real time. New samples are still
     * blocked in {@link #scheduleInferSample}.
     */
    @VisibleForTesting
    static boolean shouldRunQueuedInferSample(boolean finalized) {
        return !finalized;
    }

    private void runInferSample(long sampleMs) {
        if (!shouldRunQueuedInferSample(finalized.get())) {
            return;
        }
        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            retriever.setDataSource(sourceFile.getAbsolutePath());
            Bitmap bitmap = retriever.getFrameAtTime(sampleMs * 1000L, MediaMetadataRetriever.OPTION_CLOSEST);
            if (bitmap == null) {
                return;
            }
            try {
                Nv12FrameUtil.Frame nv12Frame = null;
                try {
                    nv12Frame = Nv12FrameUtil.fromBitmap(bitmap, nv12Pool);
                    if (nv12Frame == null) {
                        return;
                    }
                    int frameW = nv12Frame.width;
                    int frameH = nv12Frame.height;
                    ByteBuffer nv12Buffer = nv12Frame.toDirectBuffer();
                    long inferStartNs = System.nanoTime();
                    OpencvStainDetectResult opencvStainDetectResult = AiManager.getInstance().opencvStainDetectFromNv12(
                            nv12Buffer,
                            frameW,
                            frameH,
                            StainDetectSource.OFFLINE);
                    long inferMs = (System.nanoTime() - inferStartNs) / 1_000_000L;
                    if (opencvStainDetectResult.code == AiManager.CODE_INFER_BUSY) {
                        return;
                    }
                    stainDetectInferTotalMs.addAndGet(inferMs);
                    stainDetectInferCount.incrementAndGet();
                    synchronized (stainDetectSamples) {
                        stainDetectSamples.add(new StainDetectSample(sampleMs, opencvStainDetectResult));
                    }
                    if (opencvStainDetectResult.hasTarget()) {
                        Log.i(TAG, "process_video sample_ok ms=" + sampleMs
                                + " infer_ms=" + inferMs
                                + " target=" + opencvStainDetectResult.targetX + "," + opencvStainDetectResult.targetY);
                    } else if (!opencvStainDetectResult.success) {
                        Log.w(TAG, "process_video sample_fail ms=" + sampleMs
                                + " infer_ms=" + inferMs
                                + " code=" + opencvStainDetectResult.code + " msg=" + opencvStainDetectResult.message);
                    }
                    AiStainDetectResult result = AiStainDetectResultMapper.processVideoStainDetectRow(
                            opencvStainDetectResult,
                            frameW,
                            frameH,
                            sampleMs,
                            StainDetectSource.OFFLINE);
                    ProcessVideoAiTimeline.Frame frame = AiDetectOverlayFrames.toTimelineFrame(
                            result,
                            bitmap.getWidth(),
                            bitmap.getHeight());
                    timeline.addFrame(frame);
                    sseHub.publishRunning(result, sampleMs, sseSessionId);
                    notifyTimelineFrameAdded(sampleMs, frame);
                } finally {
                    if (nv12Frame != null) {
                        nv12Pool.release(nv12Frame.nv12);
                    }
                }
            } finally {
                if (!bitmap.isRecycled()) {
                    bitmap.recycle();
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "infer sample failed at " + sampleMs, e);
        } finally {
            try {
                retriever.release();
            } catch (Exception ignored) {
            }
        }
    }

    private void notifyTimelineFrameAdded(long sampleMs, @NonNull ProcessVideoAiTimeline.Frame frame) {
        mainHandler.post(() -> {
            OnTimelineFrameListener listener = timelineFrameListener;
            if (listener != null) {
                listener.onTimelineFrameAdded(sampleMs, frame);
            }
        });
    }

    private void clockTickOnWorker() {
        if (!running.get() || playbackEnded || playbackPaused) {
            return;
        }
        if (durationMs > 0L && nextClockPositionMs >= durationMs) {
            mainHandler.post(this::onPlaybackEnded);
            return;
        }
        long posMs = nextClockPositionMs;
        scheduleInferSample(sampleMsForClockPosition(posMs));
        playbackPositionMs = posMs;
        nextClockPositionMs += PLAYBACK_FRAME_STEP_MS;
        if (durationMs > 0L && nextClockPositionMs >= durationMs) {
            mainHandler.post(this::onPlaybackEnded);
        }
    }

    /**
     * Maps playback clock position to the infer sample timestamp on the configured interval grid.
     * The first sample is at {@code intervalMs}; 0 ms is never sampled.
     *
     * @return sample time in ms, or {@code -1} when no sample should be scheduled yet
     */
    static long sampleMsForClockPosition(long clockPosMs, long intervalMs) {
        if (intervalMs <= 0L) {
            return -1L;
        }
        long bucket = (clockPosMs / intervalMs) * intervalMs;
        if (bucket < intervalMs) {
            return -1L;
        }
        return bucket;
    }

    private long sampleMsForClockPosition(long clockPosMs) {
        return sampleMsForClockPosition(
                clockPosMs,
                AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO.getIntervalMs());
    }

    private void logStainDetectSessionTiming(@NonNull String reason) {
        int count = stainDetectInferCount.get();
        if (count <= 0) {
            return;
        }
        long totalMs = stainDetectInferTotalMs.get();
        Log.i(TAG, "process_video_stain_detect timing reason=" + reason
                + " samples=" + count
                + " total_infer_ms=" + totalMs
                + " avg_infer_ms=" + (totalMs / count));
    }

    private void finalizeSessionOnWorker(boolean forceDeleteArtifacts) {
        logStainDetectSessionTiming(forceDeleteArtifacts ? "force_delete" : "finalize");
        nv12Pool.clear();
        if (forceDeleteArtifacts) {
            publishPendingSessionStop();
            deleteArtifacts();
            finalized.set(true);
            running.set(false);
            closeSseSubscribers();
            return;
        }
        awaitInferExecutorDrain();
        Log.i(TAG, "infer queue drained videoId=" + getVideoId()
                + " stain_detect_samples=" + stainDetectInferCount.get()
                + " timeline_frames=" + timeline.snapshotFrames().size());
        appendTemporalSummaryAndPublish();
        publishPendingSessionStop();
        if (tmpMp4.exists()) {
            tmpMp4.delete();
        }
        persistTimelineForReplay();
        finalized.set(true);
        running.set(false);
        closeSseSubscribers();
        final boolean timelineReady = ProcessVideoAiTimelinePersistence.hasReplayData(
                ProcessVideoAiInferencePaths.inferenceTimelineJson(
                        appContext, processVideo, cacheKey));
        mainHandler.post(() -> {
            OnFinalizeListener listener = finalizeListener;
            if (listener != null) {
                listener.onFinalized(ProcessVideoAiSession.this, timelineReady);
            }
        });
    }

    private void awaitInferExecutorDrain() {
        try {
            if (!inferExecutor.awaitTermination(60L, TimeUnit.SECONDS)) {
                Log.w(TAG, "infer executor drain timed out; forcing shutdown");
                inferExecutor.shutdownNow();
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            inferExecutor.shutdownNow();
        }
    }

    private void appendTemporalSummaryAndPublish() {
        timeline.applyLensDetConsecutiveOkFilter(
                AiManager.getInstance().getMinConsecutiveOkFrames(),
                AiManager.getInstance().getBlueMinConsecutiveOkFrames());
        List<ProcessVideoAiTimeline.Frame> frames = timeline.snapshotFrames();
        LensStainBoxTemporalReducer.Result reduced = LensStainBoxTemporalReducer.reduce(frames);
        long summaryTimeMs = stopMediaTimestampMs();
        ProcessVideoAiTimeline.Frame summaryFrame =
                AiDetectOverlayFrames.buildTemporalSummaryFrame(reduced, summaryTimeMs);
        timeline.addFrame(summaryFrame);
        AiStainDetectResult summaryResult = AiStainDetectResultMapper.fromTimelineFrame(
                summaryFrame,
                StainDetectSource.OFFLINE);
        String sessionId = sseSessionId;
        if (sessionId != null) {
            sseHub.publishRunning(summaryResult, summaryTimeMs, sessionId);
        }
        publishOfflineSummaryAlert(summaryResult);
        notifyTimelineFrameAdded(summaryTimeMs, summaryFrame);
        Log.i(TAG, "temporal summary frames=" + frames.size()
                + " persistentBoxes=" + reduced.boxes.size()
                + " contaminated=" + reduced.hasContamination());
    }

    private void publishOfflineSummaryAlert(@NonNull AiStainDetectResult summaryResult) {
        LensCheckResultEvent event = StainDetectAlertMapper.toOfflineSummaryLensCheckResult(summaryResult);
        if (event == null) {
            return;
        }
        mainHandler.post(() -> EventBus.getDefault().post(event));
    }

    private void publishPendingSessionStop() {
        String reason = pendingStopReason;
        if (reason == null || reason.trim().isEmpty()) {
            reason = "release";
        }
        pendingStopReason = null;
        publishSessionStop(reason, stopMediaTimestampMs());
    }

    private void persistTimelineForReplay() {
        File timelineFile = ProcessVideoAiInferencePaths.inferenceTimelineJson(
                appContext, processVideo, cacheKey);
        try {
            ProcessVideoAiTimelinePersistence.save(timelineFile, timeline, classificationLine);
            Log.i(TAG, "timeline saved frames=" + timeline.snapshotFrames().size()
                    + " path=" + timelineFile.getAbsolutePath());
        } catch (Exception e) {
            Log.w(TAG, "timeline save failed", e);
        }
    }

    private void closeSseSubscribers() {
        synchronized (subscriberLock) {
            for (SseHttpSubscriber sub : new ArrayList<>(sseHttpSubscribers)) {
                sub.close();
            }
            sseHttpSubscribers.clear();
        }
    }

    private void deleteArtifacts() {
        if (tmpMp4.exists() && !tmpMp4.delete()) {
            Log.w(TAG, "failed to delete tmp");
        }
        if (finalMp4.exists() && !finalMp4.delete()) {
            Log.w(TAG, "failed to delete inference mp4");
        }
        ProcessVideoAiTimelinePersistence.delete(
                ProcessVideoAiInferencePaths.inferenceTimelineJson(appContext, processVideo, cacheKey));
    }

    private static long resolveDurationMs(@NonNull Context context,
                                          @NonNull ProcessParamsVideoVo processVideo,
                                          @NonNull File sourceFile) {
        long fromFile = readDurationMsFromFile(sourceFile);
        long fromMeta = processVideo.getDuration();
        if (fromFile > 0L && fromMeta > 0L) {
            long chosen = Math.max(fromFile, fromMeta);
            if (Math.abs(fromFile - fromMeta) > 500L) {
                Log.w(TAG, "duration mismatch fileMs=" + fromFile + " metaMs=" + fromMeta + " using=" + chosen);
            }
            return chosen;
        }
        if (fromFile > 0L) {
            return fromFile;
        }
        return fromMeta;
    }

    private static long readDurationMsFromFile(@NonNull File sourceFile) {
        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            retriever.setDataSource(sourceFile.getAbsolutePath());
            String durationText = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
            if (durationText != null) {
                return Long.parseLong(durationText);
            }
        } catch (Exception e) {
            Log.w(TAG, "duration read failed", e);
        } finally {
            try {
                retriever.release();
            } catch (Exception ignored) {
            }
        }
        return 0L;
    }

    public static final class SseHttpSubscriber {
        private final ProcessVideoAiSession session;
        private final AiInferenceSseHub.SseSubscriber delegate;
        private volatile boolean released;

        SseHttpSubscriber(@NonNull ProcessVideoAiSession session,
                          @NonNull AiInferenceSseHub.SseSubscriber delegate) {
            this.session = session;
            this.delegate = delegate;
        }

        @NonNull
        public AiInferenceSseHub.SseSubscriber hubSubscriber() {
            return delegate;
        }

        @NonNull
        public InputStream getInputStream() {
            return new SseHttpInputStream(this);
        }

        public void close() {
            delegate.closeFromClient();
        }

        public void releaseHttpHolder() {
            if (released) {
                return;
            }
            released = true;
            ProcessVideoAiSessionRegistry.getInstance().release(
                    session,
                    ProcessVideoAiSessionRegistry.Holder.HTTP);
        }
    }

    private static final class SseHttpInputStream extends InputStream {
        private final SseHttpSubscriber subscriber;
        private final InputStream delegate;

        SseHttpInputStream(@NonNull SseHttpSubscriber subscriber) {
            this.subscriber = subscriber;
            this.delegate = subscriber.delegate.getInputStream();
        }

        @Override
        public void close() throws java.io.IOException {
            delegate.close();
            subscriber.releaseHttpHolder();
        }

        @Override
        public int read(@NonNull byte[] buffer, int offset, int len) throws java.io.IOException {
            return delegate.read(buffer, offset, len);
        }

        @Override
        public int read() throws java.io.IOException {
            return delegate.read();
        }
    }

    private static boolean isProcessVideoOfflineInferenceAvailable() {
        return AiManager.getInstance().isOpencvStainDetectSessionActive();
    }

    private static boolean isEngineReadyForOfflineInference() {
        return AiManager.getInstance().isOpencvStainDetectSessionActive();
    }

    private static final class StainDetectSample {
        final long timeMs;
        @NonNull
        final OpencvStainDetectResult result;

        StainDetectSample(long timeMs, @NonNull OpencvStainDetectResult result) {
            this.timeMs = timeMs;
            this.result = result;
        }
    }

    @VisibleForTesting
    static void resetSubscribersForTest() {
        ProcessVideoAiSessionRegistry.getInstance().resetForTest();
    }
}
