package com.lasercyber.lws.ai.zeropoint;

import android.content.Context;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ai.Nv12FrameUtil;
import com.lasercyber.lws.ui.common.utils.VideoFileUtil;

import java.io.File;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;

/**
 * Offline temporary-video sampling and native zero-point detect for manual auto correction.
 */
final class ZeroPointVideoAnalyzer {

    private static final String TAG = "ZeroPointManualAuto";
    static final String AUTO_TEMP_VIDEO_DIR_KEY = "zero_point_auto_tmp";

    private final ZeroPointDetectNativeSession nativeSession = new ZeroPointDetectNativeSession();

    @NonNull
    ZeroPointManualAutoStageAggregate runOfflineStage(
            long runId,
            @NonNull File video,
            long intervalMs,
            @NonNull String stageName,
            int progressStart,
            int progressEnd,
            @NonNull RunGuard runGuard,
            @NonNull ProgressReporter progressReporter) {
        if (!ZeroPointMockJsonLoader.mockFileExists() && !ensureDetector(runGuard.context())) {
            return ZeroPointManualAutoStageAggregate.empty(stageName);
        }
        List<Double> validX = new ArrayList<>();
        List<Double> validY = new ArrayList<>();
        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            retriever.setDataSource(video.getAbsolutePath());
            long durationMs = readDurationMs(retriever);
            if (durationMs <= 0L) {
                Log.w(TAG, "manual_auto offline_duration_unavailable stage=" + stageName
                        + " path=" + video.getAbsolutePath());
                return ZeroPointManualAutoStageAggregate.empty(stageName);
            }
            long sampleMs = 0L;
            int index = 0;
            while (sampleMs <= durationMs && runGuard.isCurrentRun(runId)) {
                int progress = progressStart + (int) Math.min(
                        progressEnd - progressStart,
                        ((sampleMs * (long) (progressEnd - progressStart)) / Math.max(1L, durationMs)));
                progressReporter.report(runId, progress, intervalMs);
                Bitmap bitmap = retriever.getFrameAtTime(
                        sampleMs * 1000L,
                        MediaMetadataRetriever.OPTION_CLOSEST);
                if (bitmap != null) {
                    try {
                        Nv12FrameUtil.Frame frame = Nv12FrameUtil.fromBitmap(bitmap);
                        if (frame != null) {
                            ZeroPointDetectJson.Sample sample = detectFrame(
                                    frame.toDirectBuffer(),
                                    frame.width,
                                    frame.height);
                            if (sample.ok) {
                                validX.add(sample.offsetX);
                                validY.add(sample.offsetY);
                                Log.i(TAG, "manual_auto offline_sample_ok runId=" + runId
                                        + " stage=" + stageName
                                        + " index=" + index
                                        + " ms=" + sampleMs
                                        + " offset_x=" + sample.offsetX
                                        + " offset_y=" + sample.offsetY);
                            }
                        }
                    } finally {
                        if (!bitmap.isRecycled()) {
                            bitmap.recycle();
                        }
                    }
                }
                sampleMs += intervalMs;
                index++;
            }
        } catch (Exception e) {
            Log.w(TAG, "manual_auto offline_stage_failed stage=" + stageName, e);
        } finally {
            try {
                retriever.release();
            } catch (Exception ignored) {
            }
        }
        return ZeroPointManualAutoStageAggregate.from(stageName, validX, validY);
    }

    @NonNull
    ZeroPointDetectJson.Sample detectFrame(@NonNull ByteBuffer nv12, int width, int height) {
        return nativeSession.detect(
                ZeroPointDetectTargetMode.POINT,
                nv12,
                width,
                height).sample;
    }

    boolean ensureDetector(@Nullable Context context) {
        if (context == null) {
            return false;
        }
        try {
            nativeSession.ensureReady(context);
            return nativeSession.isDetectorReady();
        } catch (Throwable t) {
            Log.e(TAG, "manual_auto detector_create_failed", t);
            return false;
        }
    }

    @Nullable
    File resolveTempVideo(@Nullable File held, long runId) {
        if (isValidTempVideo(held)) {
            return held;
        }
        File fallback = findLatestTempVideoInAutoDir();
        if (fallback == null) {
            Log.w(TAG, "manual_auto temp_video_unresolved runId=" + runId
                    + " held=" + (held == null ? "null" : held.getAbsolutePath()));
            return null;
        }
        Log.i(TAG, "manual_auto temp_video_fallback runId=" + runId
                + " held=" + (held == null ? "null" : held.getAbsolutePath())
                + " fallback=" + fallback.getAbsolutePath()
                + " bytes=" + fallback.length());
        return fallback;
    }

    static boolean isValidTempVideo(@Nullable File file) {
        return file != null && file.isFile() && file.length() > 0L;
    }

    @Nullable
    static File findLatestTempVideoInAutoDir() {
        File dir = new File(VideoFileUtil.getMoviePath(AUTO_TEMP_VIDEO_DIR_KEY));
        if (!dir.isDirectory()) {
            return null;
        }
        File[] files = dir.listFiles((candidate, name) -> name != null && name.endsWith(".mp4"));
        if (files == null || files.length == 0) {
            return null;
        }
        File latest = null;
        long latestModified = 0L;
        for (File candidate : files) {
            if (!candidate.isFile() || candidate.length() <= 0L) {
                continue;
            }
            long modified = candidate.lastModified();
            if (latest == null || modified >= latestModified) {
                latest = candidate;
                latestModified = modified;
            }
        }
        return latest;
    }

    static void quietDelete(@Nullable File file) {
        if (file == null || !file.exists()) {
            return;
        }
        if (!file.delete()) {
            Log.w(TAG, "manual_auto temp_delete_failed path=" + file.getAbsolutePath());
        }
    }

    private static long readDurationMs(@NonNull MediaMetadataRetriever retriever) {
        try {
            String value = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
            return value == null ? 0L : Long.parseLong(value);
        } catch (Exception e) {
            return 0L;
        }
    }

    interface RunGuard {
        boolean isCurrentRun(long runId);

        @Nullable
        Context context();
    }

    interface ProgressReporter {
        void report(long runId, int percent, long intervalMs);
    }
}
