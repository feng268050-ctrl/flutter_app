package com.lasercyber.lws.ui.common.camera;

import android.annotation.SuppressLint;
import android.graphics.SurfaceTexture;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.ResultReceiver;
import android.util.Log;
import android.view.Surface;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.utils.AndroidEmulatorUtils;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.common.utils.VideoFileUtil;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayCoordinator;
import com.lasercyber.lws.ui.network.mediamtx.MediaMtxRelayUrls;

import org.easydarwin.video.Client;
import org.easydarwin.video.EasyPlayerClient;

import java.io.File;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import cn.hutool.core.date.DateUtil;
import lombok.Setter;

/**
 * PR0 process-video recording via EasyPlayer RTSP ingest + EasyMuxer2 (local MediaMTX fan-out).
 */
public class EasyPlayerClientManger {
    private static volatile EasyPlayerClientManger INSTANCE;
    private static final String TAG = LogTAGConstant.EasyPlayerClientManger;
    private static final Handler handler = new Handler(Looper.getMainLooper());
    static final long MUXER_START_TIMEOUT_MS = 20_000L;
    /** Extra slack for URL failover while waiting on first muxer frame (HTTP / remote sync). */
    static final long MUXER_WRITE_AWAIT_MS = MUXER_START_TIMEOUT_MS * 3L + 5_000L;

    private EasyPlayerClient client;

    private String path;
    private Runnable task;
    private Runnable muxerStartTimeoutTask;
    /** True after {@link EasyPlayerClient#start} succeeds until {@link #stop()} completes. */
    private volatile boolean recordingSessionActive;
    /** True after first muxer frame is written ({@link EasyPlayerClient#RESULT_RECORD_FRAME_WRITTEN}). */
    private volatile boolean mediaWriteActive;
    @Nullable
    private Runnable mediaWriteStartedListener;
    @Nullable
    private Runnable mediaStartFailedListener;
    @Nullable
    private Runnable durationLimitListener;
    @Nullable
    private RecordElapsedListener mediaWriteProgressListener;
    private long startTime;
    private long pauseTime;
    @Setter
    private IPlayerClientListener listener;
    private Surface virtualSurface;
    private List<String> recordUrlCandidates = Collections.emptyList();
    private int recordUrlCandidateIndex;
    private boolean temporaryRecording;
    private long recordingTimeoutMs;
    @Nullable
    private volatile CountDownLatch muxerReadyAwaitLatch;

    private EasyPlayerClientManger() {
        Surface surface = null;
        try {
            SystemSettingUtils.setCameraNetworkSegment();
            surface = createVirtualSurface();
            client = new EasyPlayerClient(Utils.getApp(), surface,
                    new ResultReceiver(new Handler(Looper.getMainLooper())) {
                        @Override
                        protected void onReceiveResult(int resultCode, Bundle resultData) {
                            if (resultCode == EasyPlayerClient.RESULT_RECORD_FRAME_WRITTEN) {
                                onMuxerFrameWritten();
                                notifyRecordElapsed(resultData);
                            } else if (resultCode == EasyPlayerClient.RESULT_RECORD_PROGRESS) {
                                notifyRecordElapsed(resultData);
                            }
                        }
                    },
                    null,
                    null);
            virtualSurface = surface;
        } catch (Throwable t) {
            Log.e(TAG, "EasyPlayer init skipped (emulator, missing YNH/camera stack, or JNI)", t);
            if (surface != null) {
                try {
                    surface.release();
                } catch (Throwable ignored) {
                }
            }
            virtualSurface = null;
            client = null;
        }
    }

    public boolean isRecorderReady() {
        return client != null;
    }

    public boolean isRecordingActive() {
        return client != null && client.isRecording();
    }

    public boolean isMuxerWriteActive() {
        return mediaWriteActive;
    }

    /**
     * Blocks until the muxer writes its first frame, the session fails, or {@code timeoutMs} elapses.
     * Used by HTTP record control so callers observe the same readiness as the UI record button.
     */
    public boolean awaitMuxerWriteActive(long timeoutMs) throws InterruptedException {
        long deadline = System.currentTimeMillis() + timeoutMs;
        while (System.currentTimeMillis() < deadline) {
            if (mediaWriteActive) {
                return true;
            }
            if (!recordingSessionActive && (client == null || !client.isRecording())) {
                return false;
            }
            long remaining = deadline - System.currentTimeMillis();
            if (remaining <= 0L) {
                break;
            }
            CountDownLatch latch = new CountDownLatch(1);
            muxerReadyAwaitLatch = latch;
            try {
                if (mediaWriteActive) {
                    return true;
                }
                latch.await(Math.min(remaining, 250L), TimeUnit.MILLISECONDS);
            } finally {
                if (muxerReadyAwaitLatch == latch) {
                    muxerReadyAwaitLatch = null;
                }
            }
        }
        return mediaWriteActive;
    }

    @NonNull
    public static EasyPlayerClientManger getInstance() {
        if (INSTANCE == null) {
            synchronized (EasyPlayerClientManger.class) {
                if (INSTANCE == null) {
                    INSTANCE = new EasyPlayerClientManger();
                }
            }
        }
        return INSTANCE;
    }

    @SuppressLint("Recycle")
    private Surface createVirtualSurface() {
        SurfaceTexture virtualTexture = new SurfaceTexture(0);
        virtualTexture.setDefaultBufferSize(
                CameraConfig.VIDEO_RESOLUTION_WIDTH, CameraConfig.VIDEO_RESOLUTION_HEIGHT);
        return new Surface(virtualTexture);
    }

    public boolean start() {
        String toDay = DateUtil.format(new Date(), "yyyy-MM-dd");
        return startRecordingToPath(
                VideoFileUtil.getMovieName(toDay).getPath(),
                false,
                CameraConfig.DEFAULT_VIDEO_DURATION * 60 * 1000L);
    }

    public boolean startTemporaryRecording(String temporaryPath, long timeoutMs) {
        if (temporaryPath == null || temporaryPath.trim().isEmpty()) {
            Log.w(TAG, "startTemporaryRecording: empty path");
            return false;
        }
        File file = new File(temporaryPath);
        File parent = file.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            Log.w(TAG, "startTemporaryRecording: failed to create parent=" + parent.getAbsolutePath());
            return false;
        }
        return startRecordingToPath(
                file.getAbsolutePath(),
                true,
                timeoutMs <= 0L ? CameraConfig.DEFAULT_VIDEO_DURATION * 60 * 1000L : timeoutMs);
    }

    private boolean startRecordingToPath(String targetPath, boolean temporary, long timeoutMs) {
        if (client == null) {
            Log.w(TAG, "start: recorder unavailable");
            return false;
        }
        if (client.isRecording()) {
            Log.e(TAG, "当前已开始录制");
            return false;
        }
        clearMuxerStartTimeout();
        if (task != null) {
            handler.removeCallbacks(task);
        }
        mediaWriteActive = false;
        if (!VideoFileUtil.ensureParentDirs(targetPath)) {
            Log.e(TAG, "start: recording path not writable path=" + targetPath);
            return false;
        }
        path = targetPath;
        temporaryRecording = temporary;
        recordingTimeoutMs = timeoutMs;
        boolean localRelay = MediaMtxRelayCoordinator.getInstance().isRelayReady();
        recordUrlCandidates = CameraConfig.getPr0IngestCandidates(localRelay);
        recordUrlCandidateIndex = 0;
        if (recordUrlCandidates.isEmpty()) {
            Log.e(TAG, "start: no PR0 recording URL"
                    + " emulator=" + AndroidEmulatorUtils.isLikelyEmulator()
                    + " peerRelayConfigured=" + CameraConfig.isPeerRelayCameraIpConfigured());
            return false;
        }
        if (!localRelay) {
            Log.w(TAG, "start: local relay_not_ready; pr0 candidates=" + recordUrlCandidates);
        }
        Log.d(TAG, "startRecorderVideo: 正在录制视频，存储到：" + path);
        if (!tryStartNextRecordUrl()) {
            Log.e(TAG, "RECORD_RTSP all candidates failed count=" + recordUrlCandidates.size());
            return false;
        }
        return true;
    }

    private boolean tryStartNextRecordUrl() {
        if (client == null) {
            return false;
        }
        int transportMode = Client.TRANSTYPE_TCP;
        while (recordUrlCandidateIndex < recordUrlCandidates.size()) {
            String recordUrl = recordUrlCandidates.get(recordUrlCandidateIndex);
            String reason = temporaryRecording ? "zero_point_auto_temp" : "record_start";
            Log.i(TAG, "RECORD_RTSP start reason=" + reason
                    + " profile=main url=" + recordUrl
                    + " candidate=" + (recordUrlCandidateIndex + 1) + "/" + recordUrlCandidates.size());
            String user = "";
            String pass = "";
            if (!MediaMtxRelayUrls.isMediamtxFanoutUrl(recordUrl)) {
                user = CameraConfig.CAMERA_USER_NAME;
                pass = CameraConfig.CAMERA_PASSWORD;
            }
            int start = client.start(
                    recordUrl,
                    transportMode,
                    0,
                    Client.EASY_SDK_VIDEO_FRAME_FLAG | Client.EASY_SDK_AUDIO_FRAME_FLAG,
                    user,
                    pass,
                    path
            );
            Log.d(TAG, "start: 打开摄像头结果:" + start + " url=" + recordUrl);
            if (start == 0) {
                recordingSessionActive = !temporaryRecording;
                startTime = System.currentTimeMillis();
                scheduleMuxerStartTimeout();
                if (task != null) {
                    handler.removeCallbacks(task);
                }
                task = temporaryRecording ? this::stopTemporaryRecording : this::onProcessRecordDurationLimit;
                handler.postDelayed(task, recordingTimeoutMs);
                return true;
            }
            client.stop();
            recordUrlCandidateIndex++;
        }
        return false;
    }

    private void retryNextRecordUrlAfterFailure(@NonNull String reason) {
        if (client == null) {
            return;
        }
        clearMuxerStartTimeout();
        mediaWriteActive = false;
        client.stop();
        recordUrlCandidateIndex++;
        Log.w(TAG, "RECORD_RTSP retry reason=" + reason
                + " nextCandidate=" + (recordUrlCandidateIndex + 1) + "/" + recordUrlCandidates.size());
        if (tryStartNextRecordUrl()) {
            return;
        }
        boolean wasSession = recordingSessionActive;
        stopInternal(false, reason);
        releaseMuxerAwaitLatch();
        Runnable failed = mediaStartFailedListener;
        if (failed != null) {
            handler.post(failed);
        }
        if (listener != null && wasSession) {
            listener.recordingAborted();
        }
    }

    private void scheduleMuxerStartTimeout() {
        clearMuxerStartTimeout();
        muxerStartTimeoutTask = () -> {
            if (mediaWriteActive || !recordingSessionActive) {
                return;
            }
            Log.e(TAG, "RECORD_RTSP muxer start timeout path=" + path);
            retryNextRecordUrlAfterFailure("muxer_start_timeout");
        };
        handler.postDelayed(muxerStartTimeoutTask, MUXER_START_TIMEOUT_MS);
    }

    private void notifyRecordElapsed(@Nullable Bundle resultData) {
        if (resultData == null) {
            return;
        }
        long elapsedMs = resultData.getLong(EasyPlayerClient.EXTRA_RECORD_ELAPSED_MS, 0L);
        RecordElapsedListener progressListener = mediaWriteProgressListener;
        if (progressListener != null) {
            handler.post(() -> progressListener.onRecordElapsed(elapsedMs));
        }
    }

    private void onMuxerFrameWritten() {
        if (mediaWriteActive) {
            return;
        }
        clearMuxerStartTimeout();
        mediaWriteActive = true;
        Log.i(TAG, "RECORD_RTSP muxer writing frames path=" + path);
        Runnable writeStarted = mediaWriteStartedListener;
        if (writeStarted != null) {
            handler.post(writeStarted);
        }
        if (listener != null && recordingSessionActive) {
            listener.startRecording();
        }
        releaseMuxerAwaitLatch();
    }

    private void releaseMuxerAwaitLatch() {
        CountDownLatch latch = muxerReadyAwaitLatch;
        if (latch != null) {
            muxerReadyAwaitLatch = null;
            latch.countDown();
        }
    }

    private void clearMuxerStartTimeout() {
        if (muxerStartTimeoutTask != null) {
            handler.removeCallbacks(muxerStartTimeoutTask);
            muxerStartTimeoutTask = null;
        }
    }

    public void setMuxerBeganListener(@Nullable Runnable listener) {
        mediaWriteStartedListener = listener;
    }

    public void setMuxerStartFailedListener(@Nullable Runnable listener) {
        mediaStartFailedListener = listener;
    }

    public void setMuxerProgressListener(@Nullable RecordElapsedListener listener) {
        mediaWriteProgressListener = listener;
    }

    /**
     * Invoked on the main thread after a process-video segment hits
     * {@link CameraConfig#DEFAULT_VIDEO_DURATION} and has been stopped/saved.
     */
    public void setDurationLimitListener(@Nullable Runnable listener) {
        durationLimitListener = listener;
    }

    /** Muxer timeline updates for UI elapsed display. */
    public interface RecordElapsedListener {
        void onRecordElapsed(long elapsedMs);
    }

    /**
     * 10-minute segment ceiling: save current file, then notify UI to optionally roll over.
     */
    private void onProcessRecordDurationLimit() {
        Log.i(TAG, "RECORD_RTSP duration limit reached path=" + path
                + " limitMs=" + recordingTimeoutMs);
        stopInternal(true, "duration_limit");
        Runnable rollover = durationLimitListener;
        if (rollover != null) {
            handler.post(rollover);
        }
    }

    public boolean stop() {
        return stopInternal(true, "record_stop");
    }

    public boolean stopTemporaryRecording() {
        return stopInternal(false, "zero_point_auto_temp");
    }

    private boolean stopInternal(boolean notifySaveListener, String reason) {
        Log.i(TAG, "RECORD_RTSP stop reason=" + reason + " profile=main");
        clearMuxerStartTimeout();
        if (task != null) {
            handler.removeCallbacks(task);
            task = null;
        }
        if (client == null) {
            recordingSessionActive = false;
            mediaWriteActive = false;
            return false;
        }
        client.stop();
        File saved = path == null ? null : new File(path);
        boolean hasSaveableFile = mediaWriteActive
                && saved != null
                && saved.exists()
                && saved.length() > 0L;
        if (notifySaveListener && listener != null && recordingSessionActive) {
            if (hasSaveableFile) {
                listener.stopRecording(path);
            } else {
                Log.w(TAG, "RECORD_RTSP stop: no saveable file path=" + path
                        + " mediaWriteActive=" + mediaWriteActive
                        + " exists=" + (saved != null && saved.exists())
                        + " bytes=" + (saved != null ? saved.length() : 0));
                listener.recordingAborted();
            }
        }
        recordingSessionActive = false;
        mediaWriteActive = false;
        releaseMuxerAwaitLatch();
        return true;
    }

    public boolean cancel() {
        Log.d(TAG, "cancel: 正在取消录制");
        clearMuxerStartTimeout();
        if (task != null) {
            handler.removeCallbacks(task);
            task = null;
        }
        if (client == null) {
            recordingSessionActive = false;
            mediaWriteActive = false;
            return false;
        }
        client.stop();
        recordingSessionActive = false;
        mediaWriteActive = false;
        return true;
    }

    public boolean pause() {
        if (client == null) {
            return false;
        }
        if (!client.isRecording()) {
            Log.e(TAG, "当前未开始录制");
            return false;
        }
        if (task != null) {
            handler.removeCallbacks(task);
        }
        client.pauseRecord();
        pauseTime = System.currentTimeMillis();
        if (listener != null) {
            listener.pauseRecording();
        }
        return true;
    }

    public boolean resume() {
        if (client == null) {
            return false;
        }
        if (client.isRecording()) {
            Log.e(TAG, "当前已开始录制");
            return false;
        }
        if (task != null) {
            handler.removeCallbacks(task);
        }
        client.resumeRecord();
        long remainingDuration = CameraConfig.DEFAULT_VIDEO_DURATION * 60 * 1000L - pauseTime - startTime;
        if (remainingDuration >= 0) {
            task = this::stop;
            handler.postDelayed(task, remainingDuration);
        } else {
            stop();
        }
        if (listener != null) {
            listener.resumeRecording();
        }
        return true;
    }

    public void clearReference() {
        listener = null;
        if (this.task != null) {
            handler.removeCallbacks(this.task);
            this.task = null;
        }
        clearMuxerStartTimeout();
        handler.removeCallbacksAndMessages(null);
    }

    public interface IPlayerClientListener {
        void startRecording();

        void stopRecording(String path);

        void pauseRecording();

        void resumeRecording();

        default void recordingAborted() {
        }
    }
}
