package com.lasercyber.lws.ai.daemon;

import android.net.LocalSocket;
import android.net.LocalSocketAddress;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.Closeable;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Consumer;

/**
 * JSON Lines client for {@code cmd.sock} (req/resp) and {@code evt.sock} (subscribe).
 */
public final class AiDaemonSocketClient implements Closeable {

    private static final String TAG = LogTAGConstant.AI_DAEMON;
    private static final AtomicLong NEXT_ID = new AtomicLong(1);
    private static final int DEFAULT_SO_TIMEOUT_MS = 15_000;

    @Nullable
    private LocalSocket cmdSocket;
    @Nullable
    private BufferedWriter cmdWriter;
    @Nullable
    private BufferedReader cmdReader;
    @Nullable
    private LocalSocket evtSocket;
    @Nullable
    private BufferedReader evtReader;
    @Nullable
    private Thread evtThread;
    private volatile boolean closed;

    public synchronized void connect(@NonNull String cmdName, @NonNull String evtName) throws IOException {
        closeQuietly();
        closed = false;
        cmdSocket = openAbstract(cmdName);
        cmdSocket.setSoTimeout(DEFAULT_SO_TIMEOUT_MS);
        cmdWriter = new BufferedWriter(new OutputStreamWriter(cmdSocket.getOutputStream(), StandardCharsets.UTF_8));
        cmdReader = new BufferedReader(new InputStreamReader(cmdSocket.getInputStream(), StandardCharsets.UTF_8));
        evtSocket = openAbstract(evtName);
        evtSocket.setSoTimeout(DEFAULT_SO_TIMEOUT_MS);
        evtReader = new BufferedReader(new InputStreamReader(evtSocket.getInputStream(), StandardCharsets.UTF_8));
        Log.i(TAG, "socket connected abstract cmd=" + cmdName + " evt=" + evtName);
    }

    public void startEventLoop(@NonNull Consumer<JSONObject> onEvent) {
        BufferedReader reader = evtReader;
        if (reader == null) {
            return;
        }
        Thread t = new Thread(() -> {
            try {
                String line;
                while (!closed && (line = reader.readLine()) != null) {
                    if (line.isEmpty()) {
                        continue;
                    }
                    try {
                        onEvent.accept(new JSONObject(line));
                    } catch (JSONException e) {
                        Log.w(TAG, "bad evt JSON: " + line, e);
                    }
                }
            } catch (IOException e) {
                if (!closed) {
                    Log.w(TAG, "evt reader ended", e);
                }
            }
        }, "ai-daemon-evt");
        t.setDaemon(true);
        t.start();
        evtThread = t;
    }

    @NonNull
    public synchronized JSONObject request(@NonNull String type, @Nullable JSONObject fields)
            throws IOException, JSONException {
        return request(type, fields, DEFAULT_SO_TIMEOUT_MS);
    }

    @NonNull
    public synchronized JSONObject request(@NonNull String type, @Nullable JSONObject fields, int timeoutMs)
            throws IOException, JSONException {
        if (cmdWriter == null || cmdReader == null || cmdSocket == null) {
            throw new IOException("cmd socket not connected");
        }
        int previousTimeout = cmdSocket.getSoTimeout();
        try {
            cmdSocket.setSoTimeout(timeoutMs);
            String id = Long.toString(NEXT_ID.getAndIncrement());
            JSONObject req = fields != null ? fields : new JSONObject();
            req.put("v", 1);
            req.put("type", type);
            req.put("id", id);
            req.put("ts_ms", System.currentTimeMillis());
            cmdWriter.write(req.toString());
            cmdWriter.write('\n');
            cmdWriter.flush();
            String line;
            try {
                line = cmdReader.readLine();
            } catch (SocketTimeoutException e) {
                throw new IOException("cmd socket timeout waiting for " + type, e);
            }
            if (line == null) {
                throw new IOException("cmd socket closed while waiting for " + type);
            }
            JSONObject resp = new JSONObject(line);
            if (!id.equals(resp.optString("id"))) {
                Log.w(TAG, "cmd response id mismatch req=" + id + " resp=" + resp.optString("id"));
            }
            return resp;
        } finally {
            try {
                cmdSocket.setSoTimeout(previousTimeout);
            } catch (IOException ignored) {
            }
        }
    }

    @Override
    public synchronized void close() {
        closed = true;
        closeQuietly();
    }

    private void closeQuietly() {
        try {
            if (cmdWriter != null) {
                cmdWriter.close();
            }
        } catch (IOException ignored) {
        }
        try {
            if (cmdReader != null) {
                cmdReader.close();
            }
        } catch (IOException ignored) {
        }
        try {
            if (evtReader != null) {
                evtReader.close();
            }
        } catch (IOException ignored) {
        }
        try {
            if (cmdSocket != null) {
                cmdSocket.close();
            }
        } catch (IOException ignored) {
        }
        try {
            if (evtSocket != null) {
                evtSocket.close();
            }
        } catch (IOException ignored) {
        }
        cmdWriter = null;
        cmdReader = null;
        evtReader = null;
        cmdSocket = null;
        evtSocket = null;
        evtThread = null;
    }

    @NonNull
    private static LocalSocket openAbstract(@NonNull String name) throws IOException {
        LocalSocket socket = new LocalSocket();
        socket.connect(new LocalSocketAddress(name, LocalSocketAddress.Namespace.ABSTRACT));
        return socket;
    }
}
