package com.lasercyber.lws.ui.common.utils;

import android.content.Context;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;

/**
 * First-frame / cover extraction for local video files. Used by Monitor cover OSS STS upload and by
 * {@link VideoFileUtils#readVideoFileInfo(String)} so retriever strategy stays in one place.
 * <p>
 * After {@code setDataSource(path)} fails, a <em>new</em> {@link MediaMetadataRetriever} is used for FD-based
 * sources (platform quirk); {@link ParcelFileDescriptor} is tried before {@link FileInputStream}.
 */
public final class VideoCoverExtractor {
    private static final String TAG = "VideoCoverExtractor";
    private static final int MAX_EDGE_PX = 720;
    private static final int JPEG_QUALITY = 85;

    /** Microsecond time offsets when t=0 / CLOSEST_SYNC fails (encoder or device quirks). */
    private static final long[] FRAME_TIME_US = new long[]{
            0L, 1_000L, 10_000L, 100_000L, 500_000L, 1_000_000L,
    };

    /** Duration, encoded resolution, and cover from a single {@link MediaMetadataRetriever} pass. */
    public static final class Probe {
        public final long durationMs;
        @Nullable
        public final String resolution;
        @Nullable
        public final Bitmap coverBitmap;

        public Probe(long durationMs, @Nullable String resolution, @Nullable Bitmap coverBitmap) {
            this.durationMs = durationMs;
            this.resolution = resolution;
            this.coverBitmap = coverBitmap;
        }
    }

    /**
     * Owns one {@link MediaMetadataRetriever} and exactly one backing descriptor/stream, if any.
     */
    private static final class RetrieverSession implements AutoCloseable {
        private final MediaMetadataRetriever retriever;
        @Nullable
        private final ParcelFileDescriptor parcelFd;
        @Nullable
        private final FileInputStream fileStream;

        private RetrieverSession(MediaMetadataRetriever retriever,
                @Nullable ParcelFileDescriptor parcelFd,
                @Nullable FileInputStream fileStream) {
            this.retriever = retriever;
            this.parcelFd = parcelFd;
            this.fileStream = fileStream;
        }

        static RetrieverSession open(@NonNull File videoFile) throws IOException {
            MediaMetadataRetriever mmr = new MediaMetadataRetriever();
            try {
                mmr.setDataSource(videoFile.getAbsolutePath());
                return new RetrieverSession(mmr, null, null);
            } catch (RuntimeException pathEx) {
                Log.i(TAG, "setDataSource(path) failed, try PFD/FIS: " + pathEx.getMessage());
                releaseRetrieverQuietly(mmr);
            }

            mmr = new MediaMetadataRetriever();
            ParcelFileDescriptor pfd = null;
            try {
                pfd = ParcelFileDescriptor.open(videoFile, ParcelFileDescriptor.MODE_READ_ONLY);
                mmr.setDataSource(pfd.getFileDescriptor());
                return new RetrieverSession(mmr, pfd, null);
            } catch (Throwable t) {
                if (pfd != null) {
                    try {
                        pfd.close();
                    } catch (IOException ignored) {
                    }
                }
                releaseRetrieverQuietly(mmr);
                Log.i(TAG, "setDataSource(ParcelFileDescriptor) failed: " + t.getMessage());
            }

            mmr = new MediaMetadataRetriever();
            FileInputStream in;
            try {
                in = new FileInputStream(videoFile);
            } catch (IOException ioe) {
                releaseRetrieverQuietly(mmr);
                throw new IOException("open video for retriever", ioe);
            }
            try {
                mmr.setDataSource(in.getFD());
                return new RetrieverSession(mmr, null, in);
            } catch (RuntimeException fdEx) {
                try {
                    in.close();
                } catch (IOException ignored) {
                }
                releaseRetrieverQuietly(mmr);
                throw new IOException("setDataSource(FileDescriptor) failed", fdEx);
            }
        }

        @Override
        public void close() {
            releaseRetrieverQuietly(retriever);
            if (parcelFd != null) {
                try {
                    parcelFd.close();
                } catch (IOException ignored) {
                }
            }
            closeQuietly(fileStream);
        }
    }

    private VideoCoverExtractor() {
    }

    /**
     * Reads duration (ms) and first usable frame as a downscaled cover bitmap, or zeros / null on failure.
     */
    @NonNull
    public static Probe probeVideoFile(@NonNull File videoFile) {
        if (!videoFile.isFile()) {
            return new Probe(0L, null, null);
        }
        try (RetrieverSession session = RetrieverSession.open(videoFile)) {
            MediaMetadataRetriever retriever = session.retriever;
            long durationMs = readDurationMs(retriever);
            String resolution = readResolution(retriever);
            Bitmap raw = decodeFirstUsableFrame(retriever);
            Bitmap cover = null;
            if (raw != null) {
                cover = scaleDownIfNeeded(raw);
                if (cover != raw) {
                    raw.recycle();
                }
            }
            return new Probe(durationMs, resolution, cover);
        } catch (IOException e) {
            Log.w(TAG, "probe attach/read failed path=" + videoFile.getAbsolutePath(), e);
            return new Probe(0L, null, null);
        } catch (RuntimeException e) {
            Log.w(TAG, "probe failed path=" + videoFile.getAbsolutePath() + " msg=" + e.getMessage(), e);
            return new Probe(0L, null, null);
        }
    }

    /**
     * Writes first frame as JPEG (720px max edge) into app cache for multipart upload.
     *
     * @throws IOException if path invalid, no frame, or IO error
     */
    @NonNull
    public static File extractFirstFrameJpeg(@NonNull Context context, @NonNull String videoPath,
            @NonNull String videoId) throws IOException {
        File videoFile = new File(videoPath);
        if (!videoFile.isFile()) {
            throw new IOException("video file not found: " + videoPath);
        }
        File out = new File(context.getCacheDir(), "video_cover_" + videoId.replaceAll("[^a-zA-Z0-9_-]", "_") + ".jpg");
        try (RetrieverSession session = RetrieverSession.open(videoFile)) {
            Bitmap frame = decodeFirstUsableFrame(session.retriever);
            if (frame == null) {
                throw new IOException("no decodable frame");
            }
            Bitmap scaled = scaleDownIfNeeded(frame);
            if (scaled != frame) {
                frame.recycle();
            }
            try (OutputStream os = new FileOutputStream(out)) {
                if (!scaled.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, os)) {
                    scaled.recycle();
                    throw new IOException("jpeg compress failed");
                }
            }
            scaled.recycle();
            return out;
        } catch (IOException e) {
            throw e;
        } catch (RuntimeException e) {
            Log.w(TAG, "extract failed path=" + videoPath + " msg=" + e.getMessage(), e);
            throw new IOException("metadata retriever failed", e);
        }
    }

    private static void releaseRetrieverQuietly(@Nullable MediaMetadataRetriever r) {
        if (r == null) {
            return;
        }
        try {
            r.release();
        } catch (RuntimeException | IOException ignored) {
        }
    }

    private static long readDurationMs(MediaMetadataRetriever retriever) {
        try {
            String durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
            return durationStr != null ? Long.parseLong(durationStr) : 0L;
        } catch (RuntimeException e) {
            return 0L;
        }
    }

    /**
     * Display-oriented resolution as {@code width}x{@code height} (swaps when rotation is 90°/270°).
     */
    @Nullable
    private static String readResolution(MediaMetadataRetriever retriever) {
        try {
            String widthStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH);
            String heightStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT);
            if (widthStr == null || heightStr == null) {
                return null;
            }
            int width = Integer.parseInt(widthStr);
            int height = Integer.parseInt(heightStr);
            if (width <= 0 || height <= 0) {
                return null;
            }
            String rotationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION);
            if (rotationStr != null) {
                int rotation = Integer.parseInt(rotationStr);
                if (rotation == 90 || rotation == 270) {
                    int swap = width;
                    width = height;
                    height = swap;
                }
            }
            return width + "x" + height;
        } catch (RuntimeException e) {
            return null;
        }
    }

    private static void closeQuietly(@Nullable FileInputStream in) {
        if (in != null) {
            try {
                in.close();
            } catch (IOException ignored) {
            }
        }
    }

    @Nullable
    private static Bitmap decodeFirstUsableFrame(MediaMetadataRetriever retriever) {
        int[] options = new int[]{
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                MediaMetadataRetriever.OPTION_CLOSEST,
        };
        for (long timeUs : FRAME_TIME_US) {
            for (int option : options) {
                Bitmap b = retriever.getFrameAtTime(timeUs, option);
                if (b != null && b.getWidth() > 0 && b.getHeight() > 0) {
                    return b;
                }
                if (b != null) {
                    b.recycle();
                }
            }
        }
        return null;
    }

    private static Bitmap scaleDownIfNeeded(@NonNull Bitmap src) {
        int w = src.getWidth();
        int h = src.getHeight();
        int max = Math.max(w, h);
        if (max <= MAX_EDGE_PX) {
            return src;
        }
        float scale = (float) MAX_EDGE_PX / (float) max;
        int nw = Math.max(1, Math.round(w * scale));
        int nh = Math.max(1, Math.round(h * scale));
        return Bitmap.createScaledBitmap(src, nw, nh, true);
    }
}
