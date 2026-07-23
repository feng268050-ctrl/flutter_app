package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.IOException;
import java.io.InputStream;

/**
 * Blocking SSE frame source consumed by {@link SseFlushingResponse}.
 */
public interface SseFrameSubscriber {

    boolean isClosed();

    @Nullable
    byte[] pollChunk(long timeoutMs) throws InterruptedException;

    void closeFromClient();

    @NonNull
    default InputStream getInputStream() {
        return new SseFrameInputStream(this);
    }

    final class SseFrameInputStream extends InputStream {
        private final SseFrameSubscriber subscriber;
        @Nullable
        private byte[] current;
        private int position;
        private volatile boolean released;

        SseFrameInputStream(@NonNull SseFrameSubscriber subscriber) {
            this.subscriber = subscriber;
        }

        @Override
        public void close() throws IOException {
            if (!released) {
                released = true;
                subscriber.closeFromClient();
            }
            super.close();
        }

        @Override
        public int read(@NonNull byte[] buffer, int offset, int len) throws IOException {
            if (subscriber.isClosed()
                    && (current == null || position >= current.length)) {
                return -1;
            }
            while (true) {
                if (current != null && position < current.length) {
                    int toCopy = Math.min(len, current.length - position);
                    System.arraycopy(current, position, buffer, offset, toCopy);
                    position += toCopy;
                    return toCopy;
                }
                try {
                    current = subscriber.pollChunk(AiInferenceSseHub.READ_POLL_MS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return -1;
                }
                if (current == null) {
                    if (subscriber.isClosed()) {
                        return -1;
                    }
                    return 0;
                }
                if (current.length == 0 && subscriber.isClosed()) {
                    return -1;
                }
                position = 0;
            }
        }

        @Override
        public int read() throws IOException {
            byte[] one = new byte[1];
            int n = read(one, 0, 1);
            return n < 0 ? -1 : (one[0] & 0xFF);
        }
    }
}
