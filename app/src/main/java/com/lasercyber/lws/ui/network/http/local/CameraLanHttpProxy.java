package com.lasercyber.lws.ui.network.http.local;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;

import fi.iki.elonen.NanoHTTPD;
import okhttp3.HttpUrl;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okhttp3.ResponseBody;

/**
 * Non-production LAN HTTP reverse proxy: Wi‑Fi clients reach the IPC HTTP API ({@code :9000} on eth0)
 * via {@link #PORT} ({@code 9000}, same as IPC HTTP) on the tablet Wi‑Fi/LAN. Upstream uses eth0
 * {@link CameraConfig#getUpstreamCameraAppUrl()} on eth0.
 */
public final class CameraLanHttpProxy extends NanoHTTPD {

    public static final int PORT = CameraConfig.DEFAULT_CAMERA_HTTP_PORT;
    public static final String PROBE_PATH = "/_lws/camera-proxy/probe";
    private static final String TAG = LogTAGConstant.CameraLanHttpProxy;
    private static final String MIME_TEXT = "text/plain; charset=utf-8";
    private static final Set<String> SKIP_REQUEST_HEADERS = Set.of(
            "host", "connection", "content-length", "transfer-encoding", "accept-encoding",
            "authorization");

    private static volatile CameraLanHttpProxy instance;

    private final OkHttpClient upstreamClient = new OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build();

    @Nullable
    private Context appContext;

    @VisibleForTesting
    CameraLanHttpProxy(int port) {
        super("0.0.0.0", port);
    }

    private CameraLanHttpProxy() {
        this(PORT);
    }

    @NonNull
    public static CameraLanHttpProxy getInstance() {
        if (instance == null) {
            synchronized (CameraLanHttpProxy.class) {
                if (instance == null) {
                    instance = new CameraLanHttpProxy();
                }
            }
        }
        return instance;
    }

    public synchronized void start(@NonNull Context context) {
        ensureStarted(context);
    }

    public synchronized void ensureStarted(@NonNull Context context) {
        if (!CameraLanHttpProxyPolicy.shouldRun(context)) {
            return;
        }
        appContext = context.getApplicationContext();
        if (isAlive()) {
            return;
        }
        try {
            start(SOCKET_READ_TIMEOUT, false);
            Log.i(TAG, String.format(Locale.US,
                    "camera LAN HTTP proxy listening 0.0.0.0:%d -> %s",
                    getListeningPort(), CameraConfig.getUpstreamCameraAppUrl()));
        } catch (IOException e) {
            Log.e(TAG, "camera LAN HTTP proxy bind failed on port " + PORT, e);
        }
    }

    public synchronized void shutdown() {
        if (isAlive()) {
            super.stop();
            Log.i(TAG, "camera LAN HTTP proxy stopped");
        }
        appContext = null;
    }

    @Override
    public Response serve(IHTTPSession session) {
        Context ctx = appContext;
        if (ctx == null || !CameraLanHttpProxyPolicy.shouldRun(ctx)) {
            return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_TEXT, "disabled");
        }
        String path = session.getUri();
        if (Method.GET.equals(session.getMethod()) && PROBE_PATH.equals(path)) {
            return newFixedLengthResponse(Response.Status.OK, MIME_TEXT,
                    "ok upstream=" + CameraConfig.getUpstreamCameraAppUrl());
        }
        String upstreamUrl = buildUpstreamUrl(session);
        if (upstreamUrl == null) {
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, MIME_TEXT, "bad_upstream");
        }
        try {
            return forward(session, upstreamUrl);
        } catch (IOException | ResponseException e) {
            Log.w(TAG, "proxy failed " + session.getMethod() + " " + path + " -> " + upstreamUrl, e);
            return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_TEXT,
                    "upstream_error: " + e.getMessage());
        }
    }

    @Nullable
    @VisibleForTesting
    static String buildUpstreamUrl(@NonNull IHTTPSession session) {
        String uri = session.getUri();
        if (uri == null || uri.isEmpty()) {
            uri = "/";
        }
        String base = CameraConfig.getUpstreamCameraAppUrl();
        HttpUrl baseUrl = HttpUrl.parse(base);
        if (baseUrl == null) {
            return null;
        }
        String relative = uri.startsWith("/") ? uri.substring(1) : uri;
        if (relative.isEmpty()) {
            return baseUrl.toString();
        }
        HttpUrl resolved = baseUrl.resolve(relative);
        if (resolved == null) {
            String query = session.getQueryParameterString();
            if (query != null && !query.isEmpty()) {
                return base + (relative.startsWith("?") ? relative.substring(1) : relative) + "?" + query;
            }
            return null;
        }
        String queryOnly = session.getQueryParameterString();
        if (queryOnly != null && !queryOnly.isEmpty() && resolved.query() == null) {
            return resolved.newBuilder().encodedQuery(queryOnly).build().toString();
        }
        return resolved.toString();
    }

    @NonNull
    private Response forward(@NonNull IHTTPSession session, @NonNull String upstreamUrl)
            throws IOException, ResponseException {
        byte[] body = readBody(session);
        Request.Builder requestBuilder = new Request.Builder().url(upstreamUrl);
        Map<String, String> headers = session.getHeaders();
        if (headers != null) {
            for (Map.Entry<String, String> entry : headers.entrySet()) {
                String name = entry.getKey();
                if (name == null) {
                    continue;
                }
                if (SKIP_REQUEST_HEADERS.contains(name.toLowerCase(Locale.US))) {
                    continue;
                }
                String value = entry.getValue();
                if (value != null) {
                    requestBuilder.header(name, value);
                }
            }
        }
        String auth = headerIgnoreCase(headers, "authorization");
        if (auth == null || auth.isEmpty()) {
            auth = CameraConfig.basicAuthorization();
        }
        requestBuilder.header("Authorization", auth);
        Method method = session.getMethod();
        if (Method.POST.equals(method) || Method.PUT.equals(method) || Method.PATCH.equals(method)) {
            String contentType = headerIgnoreCase(headers, "content-type");
            MediaType mediaType = contentType != null
                    ? MediaType.parse(contentType)
                    : MediaType.parse("application/octet-stream");
            requestBuilder.method(method.name(), RequestBody.create(body, mediaType));
        } else if (Method.DELETE.equals(method)) {
            if (body.length == 0) {
                requestBuilder.delete();
            } else {
                MediaType mediaType = MediaType.parse(
                        headerIgnoreCase(headers, "content-type") != null
                                ? headerIgnoreCase(headers, "content-type")
                                : "application/octet-stream");
                requestBuilder.delete(RequestBody.create(body, mediaType));
            }
        } else {
            requestBuilder.get();
        }

        okhttp3.Response upstream = upstreamClient.newCall(requestBuilder.build()).execute();
        try {
            ResponseBody upstreamBody = upstream.body();
            String responseMime = upstream.header("Content-Type", "application/octet-stream");
            Response.Status status = Response.Status.lookup(upstream.code());
            if (status == null) {
                status = Response.Status.INTERNAL_ERROR;
            }
            if (upstreamBody == null) {
                upstream.close();
                return newFixedLengthResponse(status, responseMime,
                        new java.io.ByteArrayInputStream(new byte[0]), 0);
            }
            long contentLength = upstreamBody.contentLength();
            InputStream bodyStream = new FilterInputStream(upstreamBody.byteStream()) {
                @Override
                public void close() throws IOException {
                    try {
                        super.close();
                    } finally {
                        upstream.close();
                    }
                }
            };
            Log.d(TAG, "proxy " + method + " " + session.getUri() + " -> " + upstream.code()
                    + (contentLength >= 0 ? " (" + contentLength + " bytes)" : " (chunked)"));
            if (contentLength >= 0) {
                return newFixedLengthResponse(status, responseMime, bodyStream, contentLength);
            }
            return newChunkedResponse(status, responseMime, bodyStream);
        } catch (RuntimeException e) {
            upstream.close();
            throw e;
        }
    }

    @Nullable
    private static String headerIgnoreCase(@Nullable Map<String, String> headers, @NonNull String name) {
        if (headers == null) {
            return null;
        }
        for (Map.Entry<String, String> entry : headers.entrySet()) {
            if (entry.getKey() != null && name.equalsIgnoreCase(entry.getKey())) {
                return entry.getValue();
            }
        }
        return null;
    }

    @NonNull
    private static byte[] readBody(@NonNull IHTTPSession session)
            throws IOException, ResponseException {
        Method method = session.getMethod();
        if (Method.GET.equals(method) || Method.HEAD.equals(method)) {
            return new byte[0];
        }
        Map<String, String> files = new HashMap<>();
        session.parseBody(files);
        String postData = files.get("postData");
        if (postData == null || postData.isEmpty()) {
            return new byte[0];
        }
        return postData.getBytes(StandardCharsets.UTF_8);
    }
}
