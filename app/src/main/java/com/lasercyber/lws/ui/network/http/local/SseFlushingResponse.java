package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;

import java.io.ByteArrayInputStream;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

import fi.iki.elonen.NanoHTTPD;

/**
 * SSE response that never uses gzip (NanoHTTPD gzips {@code text/*} by default, which buffers
 * until the connection ends) and writes one HTTP chunk + socket flush per SSE frame.
 */
public final class SseFlushingResponse extends NanoHTTPD.Response {

    private static final long FRAME_POLL_MS = 50L;

    @NonNull
    private final SseFrameSubscriber subscriber;
    @NonNull
    private final Runnable onClose;

    private SseFlushingResponse(@NonNull SseFrameSubscriber subscriber,
                                @NonNull Runnable onClose) {
        super(NanoHTTPD.Response.Status.OK, AiInferenceSseHub.MIME_SSE,
                new ByteArrayInputStream(new byte[0]), -1);
        this.subscriber = subscriber;
        this.onClose = onClose;
        setGzipEncoding(false);
        addHeader("Cache-Control", "no-cache");
        addHeader("Connection", "close");
        addHeader("X-Accel-Buffering", "no");
    }

    @NonNull
    public static SseFlushingResponse create(@NonNull SseFrameSubscriber subscriber,
                                           @NonNull Runnable onClose) {
        return new SseFlushingResponse(subscriber, onClose);
    }

    @Override
    protected void send(@NonNull OutputStream outputStream) {
        // HTTPSession may have enabled gzip for text/event-stream before send(); force off.
        setGzipEncoding(false);
        setChunkedTransfer(true);

        SimpleDateFormat gmt = new SimpleDateFormat("E, d MMM yyyy HH:mm:ss 'GMT'", Locale.US);
        gmt.setTimeZone(TimeZone.getTimeZone("GMT"));

        try {
            PrintWriter headers = new PrintWriter(
                    new BufferedWriter(new OutputStreamWriter(outputStream, StandardCharsets.UTF_8)),
                    false);
            headers.append("HTTP/1.1 ").append(getStatus().getDescription()).append(" \r\n");
            if (getMimeType() != null) {
                printHeader(headers, "Content-Type", getMimeType());
            }
            printHeader(headers, "Date", gmt.format(new Date()));
            printHeader(headers, "Cache-Control", "no-cache");
            printHeader(headers, "Connection", "close");
            printHeader(headers, "X-Accel-Buffering", "no");
            printHeader(headers, "Transfer-Encoding", "chunked");
            headers.append("\r\n");
            headers.flush();

            pumpSseFrames(outputStream);
            outputStream.write("0\r\n\r\n".getBytes(StandardCharsets.US_ASCII));
            outputStream.flush();
        } catch (IOException e) {
            // Match NanoHTTPD: log and end connection.
        } finally {
            subscriber.closeFromClient();
            onClose.run();
        }
    }

    private void pumpSseFrames(@NonNull OutputStream outputStream) throws IOException {
        while (true) {
            byte[] frame;
            try {
                frame = subscriber.pollChunk(FRAME_POLL_MS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            }
            if (frame == null) {
                if (subscriber.isClosed()) {
                    return;
                }
                continue;
            }
            if (frame.length == 0 && subscriber.isClosed()) {
                return;
            }
            writeChunk(outputStream, frame);
        }
    }

    private static void writeChunk(@NonNull OutputStream outputStream, @NonNull byte[] frame)
            throws IOException {
        String header = Integer.toHexString(frame.length) + "\r\n";
        outputStream.write(header.getBytes(StandardCharsets.US_ASCII));
        outputStream.write(frame);
        outputStream.write("\r\n".getBytes(StandardCharsets.US_ASCII));
        outputStream.flush();
    }
}
