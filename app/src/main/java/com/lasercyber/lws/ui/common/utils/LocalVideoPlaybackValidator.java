package com.lasercyber.lws.ui.common.utils;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.File;

/**
 * Validates local MP4 files before persisting a process-video row or handing them to ExoPlayer.
 * Rejects Lavf/FFmpeg moov-only shells (~262 B) that report duration but contain no decodable frames.
 */
public final class LocalVideoPlaybackValidator {

    private static final String TAG = "LocalVideoPlaybackValidator";

    /** Moov-only empty containers from failed RTSP record stops are ~262 B. */
    public static final long MIN_FILE_BYTES = 4L * 1024L;

    /** Files smaller than this must yield a decodable first frame via {@link VideoCoverExtractor}. */
    private static final long SMALL_FILE_FRAME_REQUIRED_BYTES = 32L * 1024L;

    private LocalVideoPlaybackValidator() {
    }

    public static boolean hasMinimumFileSize(@Nullable File file) {
        return file != null && file.isFile() && file.length() >= MIN_FILE_BYTES;
    }

    public static boolean isPlayable(@Nullable File file) {
        return evaluate(file).playable;
    }

    @NonNull
    public static Result evaluate(@Nullable File file) {
        if (file == null || !file.isFile()) {
            return Result.notPlayable("missing");
        }
        long length = file.length();
        if (length <= 0L) {
            return Result.notPlayable("empty");
        }
        if (length < MIN_FILE_BYTES) {
            return Result.notPlayable("too_small:" + length);
        }
        VideoCoverExtractor.Probe probe = VideoCoverExtractor.probeVideoFile(file);
        try {
            if (probe.durationMs <= 0L) {
                return Result.notPlayable("no_duration");
            }
            if (length < SMALL_FILE_FRAME_REQUIRED_BYTES && probe.coverBitmap == null) {
                return Result.notPlayable("no_decodable_frame");
            }
            return Result.playable();
        } finally {
            if (probe.coverBitmap != null) {
                probe.coverBitmap.recycle();
            }
        }
    }

    /**
     * Deletes tiny failed recordings so they do not clutter the movie folder.
     */
    public static void deleteIfKnownInvalidShell(@Nullable File file) {
        if (file == null || !file.isFile()) {
            return;
        }
        if (file.length() >= MIN_FILE_BYTES) {
            return;
        }
        if (!file.delete()) {
            Log.w(TAG, "deleteIfKnownInvalidShell: failed path=" + file.getAbsolutePath());
        }
    }

    public static final class Result {
        public final boolean playable;
        @NonNull
        public final String reason;

        private Result(boolean playable, @NonNull String reason) {
            this.playable = playable;
            this.reason = reason;
        }

        @NonNull
        static Result playable() {
            return new Result(true, "ok");
        }

        @NonNull
        static Result notPlayable(@NonNull String reason) {
            return new Result(false, reason);
        }
    }
}
