package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;

import java.io.FilterOutputStream;
import java.io.IOException;
import java.io.OutputStream;

/**
 * Forces the underlying stream to {@link OutputStream#flush()} after every write so chunked
 * SSE bodies reach the TCP socket immediately instead of sitting in socket buffers until the
 * connection closes.
 */
final class FlushOnWriteOutputStream extends FilterOutputStream {

    FlushOnWriteOutputStream(@NonNull OutputStream out) {
        super(out);
    }

    @Override
    public void write(int b) throws IOException {
        out.write(b);
        out.flush();
    }

    @Override
    public void write(@NonNull byte[] buffer, int offset, int length) throws IOException {
        out.write(buffer, offset, length);
        out.flush();
    }

    @Override
    public void write(@NonNull byte[] buffer) throws IOException {
        out.write(buffer);
        out.flush();
    }
}
