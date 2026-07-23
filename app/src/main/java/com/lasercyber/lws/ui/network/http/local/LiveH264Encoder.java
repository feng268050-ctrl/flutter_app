package com.lasercyber.lws.ui.network.http.local;

import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.IOException;
import java.nio.ByteBuffer;
/**
 * Bounded H.264 encoder for LAN live / AI composited streams.
 */
public final class LiveH264Encoder {

    public interface Callback {
        void onEncodedChunk(@NonNull byte[] annexB, boolean keyFrame, long ptsUs);
    }

    private static final String MIME = "video/avc";
    private static final int DRAIN_TIMEOUT_US = 10_000;
    private static final int BIT_RATE = 2_000_000;

    private final String logTag;
    private final int width;
    private final int height;
    private final int frameRate;
    private final Callback callback;

    @Nullable
    private MediaCodec codec;
    private long frameIndex;

    public LiveH264Encoder(@NonNull String logTag,
                           int width,
                           int height,
                           int frameRate,
                           @NonNull Callback callback) {
        this.logTag = logTag;
        this.width = width;
        this.height = height;
        this.frameRate = Math.max(1, frameRate);
        this.callback = callback;
    }

    public void start() throws IOException {
        if (codec != null) {
            return;
        }
        MediaFormat format = MediaFormat.createVideoFormat(MIME, width, height);
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar);
        format.setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE);
        format.setInteger(MediaFormat.KEY_FRAME_RATE, frameRate);
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1);
        codec = MediaCodec.createEncoderByType(MIME);
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
        codec.start();
        frameIndex = 0;
    }

    public void stop() {
        MediaCodec c = codec;
        codec = null;
        if (c != null) {
            try {
                c.stop();
            } catch (Throwable t) {
                Log.w(logTag, "encoder stop", t);
            }
            c.release();
        }
    }

    public void encodeNv12(@NonNull byte[] nv12, long ptsUs) throws IOException {
        MediaCodec c = codec;
        if (c == null) {
            throw new IOException("encoder not started");
        }
        int inputIndex = c.dequeueInputBuffer(DRAIN_TIMEOUT_US);
        if (inputIndex >= 0) {
            ByteBuffer input = c.getInputBuffer(inputIndex);
            if (input == null) {
                throw new IOException("encoder input buffer unavailable");
            }
            input.clear();
            input.put(nv12);
            c.queueInputBuffer(inputIndex, 0, nv12.length, ptsUs, 0);
        }
        drain(false);
        frameIndex++;
    }

    public void endOfStream() throws IOException {
        MediaCodec c = codec;
        if (c == null) {
            return;
        }
        int inputIndex = c.dequeueInputBuffer(DRAIN_TIMEOUT_US);
        if (inputIndex >= 0) {
            c.queueInputBuffer(inputIndex, 0, 0, frameIndex * 1_000_000L / frameRate,
                    MediaCodec.BUFFER_FLAG_END_OF_STREAM);
        }
        drain(true);
    }

    private void drain(boolean end) throws IOException {
        MediaCodec c = codec;
        if (c == null) {
            return;
        }
        MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
        while (true) {
            int outputIndex = c.dequeueOutputBuffer(info, DRAIN_TIMEOUT_US);
            if (outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                if (!end) {
                    return;
                }
                continue;
            }
            if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                continue;
            }
            if (outputIndex < 0) {
                continue;
            }
            ByteBuffer output = c.getOutputBuffer(outputIndex);
            if (output != null && info.size > 0) {
                byte[] chunk = new byte[info.size];
                output.position(info.offset);
                output.limit(info.offset + info.size);
                output.get(chunk);
                boolean key = (info.flags & MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0;
                callback.onEncodedChunk(chunk, key, info.presentationTimeUs);
            }
            c.releaseOutputBuffer(outputIndex, false);
            if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                return;
            }
        }
    }

    @NonNull
    public static byte[] bitmapToNv12(@NonNull android.graphics.Bitmap bitmap, int width, int height) {
        int[] argb = new int[width * height];
        bitmap.getPixels(argb, 0, width, 0, 0, width, height);
        int ySize = width * height;
        int uvSize = ySize / 2;
        byte[] nv12 = new byte[ySize + uvSize];
        int yIndex = 0;
        int uvIndex = ySize;
        for (int j = 0; j < height; j++) {
            for (int i = 0; i < width; i++) {
                int color = argb[j * width + i];
                int r = (color >> 16) & 0xFF;
                int g = (color >> 8) & 0xFF;
                int b = color & 0xFF;
                int y = ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16;
                nv12[yIndex++] = (byte) clamp(y);
                if ((j & 1) == 0 && (i & 1) == 0) {
                    int u = ((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128;
                    int v = ((112 * r - 94 * g - 18 * b + 128) >> 8) + 128;
                    nv12[uvIndex++] = (byte) clamp(u);
                    nv12[uvIndex++] = (byte) clamp(v);
                }
            }
        }
        return nv12;
    }

    private static int clamp(int v) {
        return Math.max(0, Math.min(255, v));
    }
}
