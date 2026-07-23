package com.lasercyber.lws.ai;

import android.graphics.Bitmap;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/**
 * Converts display buffers to NV12 (Y + interleaved UV) for native OpenCV/RKNN inference.
 *
 * <p>Format: Y plane + interleaved UV, size = width * height * 3 / 2. Width and height must be even.
 */
public final class Nv12FrameUtil {

    private Nv12FrameUtil() {
    }

    public static int evenDimension(int value) {
        return value & ~1;
    }

    /** Width/height aligned to the direct NV12 buffer byte capacity. */
    public static final class Dimensions {
        public final int width;
        public final int height;

        Dimensions(int width, int height) {
            this.width = width;
            this.height = height;
        }
    }

    /** Direct buffer view limited to the resolved NV12 payload size. */
    public static final class Payload {
        @NonNull
        public final ByteBuffer buffer;
        public final int width;
        public final int height;

        Payload(@NonNull ByteBuffer buffer, int width, int height) {
            this.buffer = buffer;
            this.width = width;
            this.height = height;
        }
    }

    public static final class Frame {
        @NonNull
        public final ByteBuffer nv12;
        public final int width;
        public final int height;

        Frame(@NonNull ByteBuffer nv12, int width, int height) {
            this.nv12 = nv12;
            this.width = width;
            this.height = height;
        }

        public int expectedByteLength() {
            return width * height * 3 / 2;
        }

        @NonNull
        public ByteBuffer toDirectBuffer() {
            ByteBuffer view = nv12.duplicate();
            view.clear();
            view.limit(expectedByteLength());
            return view;
        }
    }

    /**
     * Session-scoped direct {@link ByteBuffer} reuse for offline NV12 conversion (e.g. process video).
     */
    public static final class DirectBufferPool {
        @Nullable
        private ByteBuffer pooled;

        @NonNull
        public synchronized ByteBuffer acquire(int minCapacity) {
            if (pooled != null && pooled.capacity() >= minCapacity) {
                ByteBuffer buf = pooled;
                pooled = null;
                buf.clear();
                return buf;
            }
            return ByteBuffer.allocateDirect(minCapacity).order(ByteOrder.nativeOrder());
        }

        public synchronized void release(@Nullable ByteBuffer buffer) {
            if (buffer == null || !buffer.isDirect()) {
                return;
            }
            if (pooled == null || buffer.capacity() > pooled.capacity()) {
                pooled = buffer;
            }
        }

        public synchronized void clear() {
            pooled = null;
        }
    }

    @NonNull
    public static Dimensions resolvePayloadDimensions(@NonNull ByteBuffer nv12, int width, int height) {
        int w = width;
        int h = height;
        int capacity = nv12.capacity();
        int payloadPixels = (capacity * 2) / 3;
        if (w > 0 && h > 0 && payloadPixels > 0 && w * h != payloadPixels && payloadPixels % w == 0) {
            int inferredHeight = payloadPixels / w;
            if (inferredHeight > 0) {
                h = inferredHeight;
            }
        }
        return new Dimensions(w, h);
    }

    @NonNull
    public static Payload preparePayload(@NonNull ByteBuffer nv12, int width, int height) {
        Dimensions dims = resolvePayloadDimensions(nv12, width, height);
        int expectedBytes = dims.width * dims.height * 3 / 2;
        ByteBuffer view = nv12.duplicate();
        view.clear();
        view.limit(Math.min(expectedBytes, view.capacity()));
        return new Payload(view, dims.width, dims.height);
    }

    /**
     * Converts planar I420 (e.g. legacy decoder callback) to NV12 direct buffer.
     * Use only at ingress boundaries; App/native contracts use NV12 thereafter.
     */
    @Nullable
    public static ByteBuffer i420DirectToNv12Direct(@NonNull ByteBuffer i420, int width, int height) {
        if (width <= 0 || height <= 0 || (width & 1) != 0 || (height & 1) != 0) {
            return null;
        }
        int frameSize = width * height;
        int expected = frameSize * 3 / 2;
        if (i420.capacity() < expected) {
            return null;
        }
        ByteBuffer nv12 = ByteBuffer.allocateDirect(expected);
        nv12.order(ByteOrder.nativeOrder());
        ByteBuffer view = i420.duplicate();
        view.clear();
        view.limit(expected);
        view.position(0);
        view.limit(frameSize);
        nv12.put(view);
        int uvPlane = frameSize / 4;
        for (int i = 0; i < uvPlane; i++) {
            nv12.put(view.get(frameSize + i));
            nv12.put(view.get(frameSize + uvPlane + i));
        }
        nv12.clear();
        return nv12;
    }

    /**
     * Copies ARGB pixels from a {@link Bitmap} and converts to NV12. The bitmap is not recycled.
     */
    @Nullable
    public static Frame fromBitmap(@NonNull Bitmap bitmap) {
        return fromBitmap(bitmap, null);
    }

    /**
     * Like {@link #fromBitmap(Bitmap)} but reuses a session {@link DirectBufferPool} when provided.
     */
    @Nullable
    public static Frame fromBitmap(@NonNull Bitmap bitmap, @Nullable DirectBufferPool pool) {
        int width = evenDimension(bitmap.getWidth());
        int height = evenDimension(bitmap.getHeight());
        if (width <= 0 || height <= 0) {
            return null;
        }
        int[] argb = new int[width * height];
        bitmap.getPixels(argb, 0, width, 0, 0, width, height);
        int expectedBytes = width * height * 3 / 2;
        ByteBuffer nv12;
        if (pool != null) {
            nv12 = pool.acquire(expectedBytes);
            if (nv12.capacity() < expectedBytes) {
                nv12 = ByteBuffer.allocateDirect(expectedBytes).order(ByteOrder.nativeOrder());
            }
        } else {
            nv12 = ByteBuffer.allocateDirect(expectedBytes);
        }
        nv12.order(ByteOrder.nativeOrder());
        fillArgbToNv12(argb, width, height, nv12);
        nv12.clear();
        return new Frame(nv12, width, height);
    }

    @NonNull
    public static ByteBuffer argbToNv12(@NonNull int[] argb, int width, int height) {
        int expectedBytes = width * height * 3 / 2;
        ByteBuffer nv12 = ByteBuffer.allocateDirect(expectedBytes);
        nv12.order(ByteOrder.nativeOrder());
        fillArgbToNv12(argb, width, height, nv12);
        nv12.clear();
        return nv12;
    }

    private static void fillArgbToNv12(@NonNull int[] argb, int width, int height, @NonNull ByteBuffer nv12) {
        int frameSize = width * height;
        int yIndex = 0;
        for (int j = 0; j < height; j++) {
            int row = j * width;
            for (int i = 0; i < width; i++) {
                int pixel = argb[row + i];
                int r = (pixel >> 16) & 0xff;
                int g = (pixel >> 8) & 0xff;
                int b = pixel & 0xff;
                int y = ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16;
                nv12.put(yIndex++, (byte) clampToByte(y));
                if ((j & 1) == 0 && (i & 1) == 0) {
                    int u = ((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128;
                    int v = ((112 * r - 94 * g - 18 * b + 128) >> 8) + 128;
                    int uvIndex = frameSize + (j >> 1) * width + i;
                    nv12.put(uvIndex, (byte) clampToByte(u));
                    nv12.put(uvIndex + 1, (byte) clampToByte(v));
                }
            }
        }
    }

    private static int clampToByte(int value) {
        if (value < 0) {
            return 0;
        }
        if (value > 255) {
            return 255;
        }
        return value;
    }
}
