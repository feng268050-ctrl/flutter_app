package com.lasercyber.lws.ui.network.http.local;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiInferencePaths;
import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiSession;
import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiSessionRegistry;
import com.lasercyber.lws.ui.common.ai.video.ProcessVideoAiTimelinePersistence;
import com.lasercyber.lws.ui.common.camera.CameraRecordCoordinator;
import com.lasercyber.lws.ui.common.camera.CameraShowOverlayCoordinator;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.handler.ProcessVideoDeleteHelper;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.AdbRemoteDebugHelper;
import com.lasercyber.lws.ui.common.utils.CameraUtils;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.network.ws.DeviceWsVideoListPayload;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.network.ws.DeviceWsProcessParametersPayload;
import com.lasercyber.lws.ui.network.ws.DeviceWsRowId;
import com.lasercyber.lws.ui.repository.ProcessParametersDataDao;
import com.lasercyber.lws.ui.repository.ProcessProcessVideoDao;

import com.google.gson.JsonObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.RandomAccessFile;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import fi.iki.elonen.NanoHTTPD;

/**
 * Embedded LAN HTTP API on {@code 0.0.0.0:5580} for mobile / direct device access.
 */
public final class DeviceLocalHttpServer extends NanoHTTPD {
    private static final String TAG = LogTAGConstant.DeviceLocalHttpServer;
    public static final int PORT = 5580;
    /** @deprecated Use {@link #PORT} (5580). Port 8080 was the original LAN HTTP bind. */
    @Deprecated
    public static final int DEPRECATED_PORT = 8080;
    public static final String LASERCYBER_PROBE_BODY = "Hello LaserCyber";
    private static final String MIME_JSON = "application/json; charset=utf-8";
    private static final String MIME_TEXT = "text/plain; charset=utf-8";
    private static final String MIME_MP4 = "video/mp4";
    private static final int ADB_ENABLE_TIMEOUT_SEC = 30;

    private static volatile DeviceLocalHttpServer instance;

    @Nullable
    private Context appContext;

    @VisibleForTesting
    DeviceLocalHttpServer(int port) {
        super("0.0.0.0", port);
    }

    private DeviceLocalHttpServer() {
        this(PORT);
    }

    @NonNull
    public static DeviceLocalHttpServer getInstance() {
        if (instance == null) {
            synchronized (DeviceLocalHttpServer.class) {
                if (instance == null) {
                    instance = new DeviceLocalHttpServer();
                }
            }
        }
        return instance;
    }

    public synchronized void start(@NonNull Context context) {
        appContext = context.getApplicationContext();
        if (isAlive()) {
            return;
        }
        try {
            start(NanoHTTPD.SOCKET_READ_TIMEOUT, false);
            Log.i(TAG, "local http started on 0.0.0.0:" + getListeningPort());
        } catch (IOException e) {
            Log.e(TAG, "local http bind failed on port " + PORT, e);
        }
    }

    public synchronized void shutdown() {
        if (isAlive()) {
            super.stop();
            Log.i(TAG, "local http stopped");
        }
        appContext = null;
    }

    @Override
    public Response serve(IHTTPSession session) {
        Context ctx = appContext;
        if (ctx == null) {
            return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_TEXT, "server_not_ready");
        }
        String path = normalizePath(session.getUri());
        Method method = session.getMethod();
        try {
            if (method == Method.GET && "/lasercyber".equals(path)) {
                return newFixedLengthResponse(Response.Status.OK, MIME_TEXT, LASERCYBER_PROBE_BODY);
            }
            if ("/v1/videos".equals(path)) {
                if (method == Method.GET) {
                    return serveVideoList(ctx, session);
                }
                if (method == Method.POST) {
                    return serveVideoUpload(ctx, session);
                }
            }
            if (path.startsWith("/v1/videos/")) {
                String remainder = path.substring("/v1/videos/".length());
                if (remainder.isEmpty()) {
                    return notFoundJson();
                }
                if (remainder.endsWith("/stream")) {
                    String videoId = remainder.substring(0, remainder.length() - "/stream".length());
                    if (method == Method.GET) {
                        return serveVideoStream(ctx, videoId, session);
                    }
                } else if (remainder.endsWith("/ai/replay")) {
                    String videoId = remainder.substring(0, remainder.length() - "/ai/replay".length());
                    if (method == Method.GET) {
                        return serveVideoAiReplay(ctx, videoId);
                    }
                } else if (remainder.endsWith("/ai")) {
                    String videoId = remainder.substring(0, remainder.length() - "/ai".length());
                    if (method == Method.GET) {
                        return serveVideoAi(ctx, videoId, session);
                    }
                } else if (method == Method.GET) {
                    return serveVideoOne(ctx, remainder);
                } else if (method == Method.DELETE) {
                    return serveVideoDelete(ctx, remainder);
                }
            }
            if ("/v1/camera/ai".equals(path)) {
                if (method == Method.GET) {
                    return serveCameraAi(ctx, session);
                }
            }
            if ("/v1/monitor/stat".equals(path)) {
                if (method == Method.GET) {
                    return serveMonitorStat();
                }
            }
            if ("/v1/monitor/alerts".equals(path)) {
                if (method == Method.GET) {
                    return serveMonitorAlerts();
                }
            }
            if ("/v1/camera/record".equals(path)) {
                if (method == Method.POST) {
                    return serveCameraRecord(session);
                }
            }
            if ("/v1/camera/show-overlay".equals(path)) {
                if (method == Method.POST) {
                    return serveCameraShowOverlay(session);
                }
            }
            if ("/v1/adb".equals(path)) {
                if (method == Method.POST) {
                    return serveAdbEnable(ctx);
                }
            }
            if ("/v1/process-library".equals(path) && method == Method.GET) {
                return serveProcessLibraryList(ctx, session);
            }
            if ("/v1/process-parameters".equals(path) && method == Method.POST) {
                return serveProcessParametersCreate(ctx, session);
            }
            if (path.startsWith("/v1/process-parameters/")) {
                String remainder = path.substring("/v1/process-parameters/".length());
                if (remainder.isEmpty()) {
                    return notFoundJson();
                }
                if (remainder.endsWith("/set-default")) {
                    String idPart = remainder.substring(0, remainder.length() - "/set-default".length());
                    if (method == Method.POST) {
                        return serveProcessParametersSetDefault(ctx, idPart);
                    }
                } else if (method == Method.GET) {
                    return serveProcessParametersOne(ctx, remainder);
                } else if (method == Method.PUT) {
                    return serveProcessParametersUpdate(ctx, remainder, session);
                } else if (method == Method.DELETE) {
                    return serveProcessParametersDelete(ctx, remainder);
                }
            }
            return notFoundJson();
        } catch (Exception ex) {
            Log.e(TAG, "local http handler error " + method + " " + path, ex);
            return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_JSON,
                    DeviceApiResultHttp.failure(500, "internal_error"));
        }
    }

    private static Response serveAdbEnable(@NonNull Context ctx) {
        CountDownLatch latch = new CountDownLatch(1);
        AtomicBoolean ok = new AtomicBoolean(false);
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                ok.set(AdbRemoteDebugHelper.enableRemoteDebugging(ctx));
            } catch (Exception ex) {
                Log.e(TAG, "adb enable failed", ex);
            } finally {
                latch.countDown();
            }
        });
        try {
            if (!latch.await(ADB_ENABLE_TIMEOUT_SEC, TimeUnit.SECONDS)) {
                return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_JSON,
                        DeviceApiResultHttp.failure(503, "adb_enable_failed"));
            }
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_JSON,
                    DeviceApiResultHttp.failure(503, "adb_enable_failed"));
        }
        if (ok.get()) {
            return newFixedLengthResponse(Response.Status.OK, MIME_JSON,
                    DeviceApiResultHttp.success(null));
        }
        return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_JSON,
                DeviceApiResultHttp.failure(503, "adb_enable_failed"));
    }

    private static Response serveCameraShowOverlay(@NonNull IHTTPSession session) {
        CameraShowOverlayBody.Request request = CameraShowOverlayBody.parse(session);
        if (request == null || request.enable == null || request.positionX == null
                || request.positionY == null) {
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, MIME_JSON,
                    DeviceApiResultHttp.failure(400, "invalid_show_overlay_request"));
        }
        try {
            CameraShowOverlayCoordinator.Result result = CameraShowOverlayCoordinator.getInstance()
                    .applyBlocking(request.enable, request.positionX, request.positionY);
            if (result.success && result.data != null) {
                return newFixedLengthResponse(Response.Status.OK, MIME_JSON,
                        DeviceApiResultHttp.success(CameraShowOverlayBody.dataMapFor(result.data)));
            }
            Response.Status status = result.httpCode == 400
                    ? Response.Status.BAD_REQUEST
                    : Response.Status.SERVICE_UNAVAILABLE;
            return newFixedLengthResponse(status, MIME_JSON,
                    DeviceApiResultHttp.failure(result.httpCode,
                            result.errorMessage != null ? result.errorMessage : "camera_show_overlay_failed"));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_JSON,
                    DeviceApiResultHttp.failure(503, "camera_show_overlay_interrupted"));
        }
    }

    private static Response serveCameraRecord(@NonNull IHTTPSession session) {
        String switchValue = CameraRecordSwitchBody.parseSwitch(session);
        if (switchValue == null) {
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, MIME_JSON,
                    DeviceApiResultHttp.failure(400, "invalid_switch"));
        }
        try {
            CameraRecordCoordinator.Result result =
                    CameraRecordCoordinator.getInstance().applySwitchBlocking(switchValue);
            if (result.success) {
                return newFixedLengthResponse(Response.Status.OK, MIME_JSON,
                        DeviceApiResultHttp.success(CameraRecordSwitchBody.dataMapFor(result)));
            }
            Response.Status status;
            if (result.httpCode == 400) {
                status = Response.Status.BAD_REQUEST;
            } else if (result.httpCode == 409) {
                status = Response.Status.CONFLICT;
            } else {
                status = Response.Status.SERVICE_UNAVAILABLE;
            }
            return newFixedLengthResponse(status, MIME_JSON,
                    DeviceApiResultHttp.failure(result.httpCode, result.errorMessage));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_JSON,
                    DeviceApiResultHttp.failure(503, "record_apply_interrupted"));
        }
    }

    private static Response serveVideoAi(@NonNull Context ctx,
                                         @NonNull String videoId,
                                         @NonNull IHTTPSession session) {
        ProcessProcessVideoDao dao = AppDatabase.getInstance(ctx).processProcessVideoDao();
        com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo vo =
                ProcessVideoQueryService.videoVoByVideoId(dao, videoId);
        File source = ProcessVideoQueryService.videoFileForStream(dao, videoId);
        if (vo == null || source == null) {
            return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_JSON,
                    DeviceApiResultHttp.failure(404, "video_not_found"));
        }
        Map<String, String> params = session.getParms();
        boolean force = params != null && "1".equals(params.get("force"));
        ProcessVideoAiSession aiSession = ProcessVideoAiSessionRegistry.getInstance().acquire(
                ctx,
                vo,
                source,
                force,
                ProcessVideoAiSessionRegistry.Holder.HTTP);
        if (aiSession == null) {
            Response res = newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_TEXT,
                    "process_video_ai_unavailable");
            res.addHeader("X-Video-Ai-Status", "unavailable");
            return res;
        }
        if (!aiSession.isRunning()) {
            aiSession.start();
        }
        ProcessVideoAiSession.SseHttpSubscriber sub = aiSession.acquireSseSubscriber();
        if (sub == null) {
            ProcessVideoAiSessionRegistry.getInstance().release(
                    aiSession, ProcessVideoAiSessionRegistry.Holder.HTTP);
            return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_TEXT,
                    "process_video_ai_unavailable");
        }
        return SseFlushingResponse.create(
                sub.hubSubscriber(),
                () -> {
                    sub.close();
                    sub.releaseHttpHolder();
                });
    }

    private static Response serveVideoAiReplay(@NonNull Context ctx, @NonNull String videoId) {
        ProcessProcessVideoDao dao = AppDatabase.getInstance(ctx).processProcessVideoDao();
        com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo vo =
                ProcessVideoQueryService.videoVoByVideoId(dao, videoId);
        File source = ProcessVideoQueryService.videoFileForStream(dao, videoId);
        if (vo == null || source == null) {
            Log.i(TAG, "event=replay_video_not_found videoId=" + videoId);
            return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_JSON,
                    DeviceApiResultHttp.failure(404, "video_not_found"));
        }
        try {
            String cacheKey = ProcessVideoAiInferencePaths.cacheKey(vo, source);
            File timelineFile = ProcessVideoAiInferencePaths.inferenceTimelineJson(ctx, vo, cacheKey);
            ProcessVideoAiTimelinePersistence.LoadedTimeline loaded =
                    ProcessVideoAiTimelinePersistence.load(timelineFile);
            if (loaded == null) {
                Log.i(TAG, "event=replay_miss videoId=" + videoId + " cacheKey=" + cacheKey);
                return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_JSON,
                        DeviceApiResultHttp.failure(404, "ai_replay_not_found"));
            }
            long generatedAtMs = timelineFile.lastModified() > 0
                    ? timelineFile.lastModified()
                    : System.currentTimeMillis();
            JsonObject data =
                    ProcessVideoAiReplayJson.replayDataObject(videoId, generatedAtMs, loaded.timeline);
            Log.i(TAG, "event=replay_hit videoId=" + videoId + " cacheKey=" + cacheKey
                    + " frames=" + loaded.timeline.snapshotFrames().size());
            return newFixedLengthResponse(Response.Status.OK, MIME_JSON, DeviceApiResultHttp.success(data));
        } catch (Exception e) {
            Log.w(TAG, "event=replay_read_error videoId=" + videoId, e);
            return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_JSON,
                    DeviceApiResultHttp.failure(500, "ai_replay_read_error"));
        }
    }

    private static Response serveCameraAi(@NonNull Context ctx, IHTTPSession session) {
        if (!isCameraCommunicationReady(ctx)) {
            return cameraCommunicationUnavailable();
        }
        CameraAiHttpPublisher.SseSubscriber sub = CameraAiHttpPublisher.getInstance().acquire();
        if (sub == null) {
            return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_TEXT,
                    "camera_ai_unavailable");
        }
        return SseFlushingResponse.create(sub.hubSubscriber(), sub::close);
    }

    private static Response serveMonitorStat() {
        MonitorStatSseHub.SseSubscriber sub = MonitorStatHttpPublisher.getInstance().acquire();
        return SseFlushingResponse.create(sub, () -> {});
    }

    private static Response serveMonitorAlerts() {
        MonitorAlertsSseHub.SseSubscriber sub = MonitorAlertsHttpPublisher.getInstance().acquire();
        return SseFlushingResponse.create(sub, () -> {});
    }

    @Override
    protected boolean useGzipWhenAccepted(@NonNull Response response) {
        String mime = response.getMimeType();
        if (mime != null && mime.toLowerCase(Locale.US).startsWith("text/event-stream")) {
            return false;
        }
        return super.useGzipWhenAccepted(response);
    }

    private static Response serveVideoUpload(@NonNull Context ctx, IHTTPSession session) {
        ProcessVideoLocalUpload.UploadResult result = ProcessVideoLocalUpload.handlePost(ctx, session);
        Response.Status status = Response.Status.lookup(result.httpStatus);
        if (status == null) {
            status = result.ok ? Response.Status.OK : Response.Status.BAD_REQUEST;
        }
        return newFixedLengthResponse(status, MIME_JSON, result.jsonBody != null ? result.jsonBody : "");
    }

    private static Response serveVideoList(@NonNull Context ctx, IHTTPSession session) {
        Map<String, String> params = session.getParms();
        int[] pageParams = parsePageParams(params);
        DeviceWsVideoListPayload.ListFilters filters = parseQueryFilters(params);
        ProcessProcessVideoDao dao = AppDatabase.getInstance(ctx).processProcessVideoDao();
        ProcessVideoQueryService.PagedVideos page = ProcessVideoQueryService.list(
                dao, pageParams[0], pageParams[1], filters);
        String json = DeviceApiResultHttp.success(ProcessVideoQueryService.listDataMap(page));
        return newFixedLengthResponse(Response.Status.OK, MIME_JSON, json);
    }

    private static Response serveVideoOne(@NonNull Context ctx, @NonNull String videoId) {
        ProcessProcessVideoDao dao = AppDatabase.getInstance(ctx).processProcessVideoDao();
        Map<String, Object> row = ProcessVideoQueryService.rowByVideoId(dao, videoId);
        if (row == null) {
            return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_JSON,
                    DeviceApiResultHttp.failure(404, "video_not_found"));
        }
        return newFixedLengthResponse(Response.Status.OK, MIME_JSON, DeviceApiResultHttp.success(row));
    }

    private static Response serveVideoStream(@NonNull Context ctx, @NonNull String videoId,
                                             @NonNull IHTTPSession session) {
        ProcessProcessVideoDao dao = AppDatabase.getInstance(ctx).processProcessVideoDao();
        File file = ProcessVideoQueryService.videoFileForStream(dao, videoId);
        if (file == null) {
            return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_JSON,
                    DeviceApiResultHttp.failure(404, "video_not_found"));
        }
        try {
            long fileLength = file.length();
            if (fileLength <= 0) {
                return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_JSON,
                        DeviceApiResultHttp.failure(404, "video_not_found"));
            }
            String rangeHeader = session.getHeaders() != null
                    ? session.getHeaders().get("range") : null;
            long[] byteRange = parseByteRange(rangeHeader, fileLength);
            if (byteRange != null && byteRange[0] < 0) {
                Response res = newFixedLengthResponse(Response.Status.RANGE_NOT_SATISFIABLE,
                        MIME_MP4, "");
                res.addHeader("Content-Range", "bytes */" + fileLength);
                return res;
            }
            if (byteRange == null) {
                Response res = newFixedLengthResponse(Response.Status.OK, MIME_MP4,
                        new FileInputStream(file), fileLength);
                res.addHeader("Accept-Ranges", "bytes");
                return res;
            }
            long start = byteRange[0];
            long end = byteRange[1];
            long contentLength = end - start + 1;
            Response res = newFixedLengthResponse(Response.Status.PARTIAL_CONTENT, MIME_MP4,
                    new PartialFileInputStream(file, start, contentLength), contentLength);
            res.addHeader("Accept-Ranges", "bytes");
            res.addHeader("Content-Range",
                    "bytes " + start + "-" + end + "/" + fileLength);
            return res;
        } catch (IOException e) {
            return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_JSON,
                    DeviceApiResultHttp.failure(500, "stream_error"));
        }
    }

    /**
     * Parses a single {@code Range: bytes=…} header.
     *
     * @return inclusive {@code [start, end]}, or {@code null} when the full file should be sent.
     */
    @VisibleForTesting
    @Nullable
    static long[] parseByteRange(@Nullable String rangeHeader, long fileLength) {
        if (rangeHeader == null || fileLength <= 0) {
            return null;
        }
        String trimmed = rangeHeader.trim();
        if (!trimmed.regionMatches(true, 0, "bytes=", 0, 6)) {
            return null;
        }
        String spec = trimmed.substring(6).trim();
        int comma = spec.indexOf(',');
        if (comma >= 0) {
            spec = spec.substring(0, comma).trim();
        }
        int dash = spec.indexOf('-');
        if (dash < 0) {
            return null;
        }
        String startPart = spec.substring(0, dash).trim();
        String endPart = spec.substring(dash + 1).trim();
        long start;
        long end;
        try {
            if (startPart.isEmpty()) {
                long suffix = Long.parseLong(endPart);
                if (suffix <= 0) {
                    return null;
                }
                start = Math.max(0, fileLength - suffix);
                end = fileLength - 1;
            } else if (endPart.isEmpty()) {
                start = Long.parseLong(startPart);
                end = fileLength - 1;
            } else {
                start = Long.parseLong(startPart);
                end = Long.parseLong(endPart);
            }
        } catch (NumberFormatException e) {
            return null;
        }
        if (start < 0 || end < start || start >= fileLength) {
            return new long[]{-1, -1};
        }
        end = Math.min(end, fileLength - 1);
        return new long[]{start, end};
    }

    private static final class PartialFileInputStream extends InputStream {
        private final RandomAccessFile raf;
        private long remaining;

        PartialFileInputStream(@NonNull File file, long start, long length) throws IOException {
            raf = new RandomAccessFile(file, "r");
            raf.seek(start);
            remaining = length;
        }

        @Override
        public int read() throws IOException {
            if (remaining <= 0) {
                return -1;
            }
            int b = raf.read();
            if (b < 0) {
                remaining = 0;
                return -1;
            }
            remaining--;
            return b;
        }

        @Override
        public int read(@NonNull byte[] buffer, int offset, int len) throws IOException {
            if (remaining <= 0) {
                return -1;
            }
            int toRead = (int) Math.min(len, remaining);
            int n = raf.read(buffer, offset, toRead);
            if (n > 0) {
                remaining -= n;
            } else if (n < 0) {
                remaining = 0;
            }
            return n;
        }

        @Override
        public void close() throws IOException {
            raf.close();
        }
    }

    private static Response serveVideoDelete(@NonNull Context ctx, @NonNull String videoId) {
        ProcessVideoDeleteHelper.Outcome outcome = ProcessVideoDeleteHelper.deleteByVideoId(ctx, videoId);
        return switch (outcome) {
            case SUCCESS -> newFixedLengthResponse(Response.Status.OK, MIME_JSON,
                    DeviceApiResultHttp.success(null));
            case FILE_DELETE_FAILED -> newFixedLengthResponse(Response.Status.OK, MIME_JSON,
                    DeviceApiResultHttp.failure(500, "file_delete_failed"));
            case NOT_FOUND -> newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_JSON,
                    DeviceApiResultHttp.failure(404, "video_not_found"));
        };
    }

    private static Response serveProcessLibraryList(@NonNull Context ctx, IHTTPSession session) {
        Map<String, String> params = session.getParms();
        Integer processType = parseOptionalInt(params.get("processType"));
        if (processType == null) {
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, MIME_JSON,
                    DeviceApiResultHttp.failure(400, "missing_process_type"));
        }
        ProcessParametersDataDao dao = AppDatabase.getInstance(ctx).processParametersDataDao();
        var list = ProcessParametersRemoteService.listLibrary(dao, processType, false);
        return newFixedLengthResponse(Response.Status.OK, MIME_JSON, DeviceApiResultHttp.success(list));
    }

    private static Response serveProcessParametersOne(@NonNull Context ctx, @NonNull String idPart) {
        Long id = DeviceWsRowId.parseDecimalString(idPart);
        if (id == null) {
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, MIME_JSON,
                    DeviceApiResultHttp.failure(400, "invalid_id"));
        }
        ProcessParametersDataDao dao = AppDatabase.getInstance(ctx).processParametersDataDao();
        ProcessParametersData row = ProcessParametersRemoteService.getById(dao, id);
        if (row == null) {
            return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_JSON,
                    DeviceApiResultHttp.failure(404, "not_found"));
        }
        return newFixedLengthResponse(Response.Status.OK, MIME_JSON,
                DeviceApiResultHttp.success(DeviceWsProcessParametersPayload.entityToMap(row, false)));
    }

    private static Response serveProcessParametersCreate(@NonNull Context ctx, IHTTPSession session) {
        JsonObject body = ProcessParametersHttpBody.readJsonObject(session);
        if (body == null) {
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, MIME_JSON,
                    DeviceApiResultHttp.failure(400, "invalid_json"));
        }
        ProcessParametersDataDao dao = AppDatabase.getInstance(ctx).processParametersDataDao();
        ProcessParametersRemoteService.MutationResult result =
                ProcessParametersRemoteService.createFromJson(dao, body, false);
        if (!result.success) {
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, MIME_JSON,
                    DeviceApiResultHttp.failure(400, result.message));
        }
        Map<String, Object> data = new java.util.LinkedHashMap<>();
        data.put("id", result.id);
        return newFixedLengthResponse(Response.Status.OK, MIME_JSON, DeviceApiResultHttp.success(data));
    }

    private static Response serveProcessParametersUpdate(
            @NonNull Context ctx,
            @NonNull String idPart,
            IHTTPSession session
    ) {
        Long id = DeviceWsRowId.parseDecimalString(idPart);
        if (id == null) {
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, MIME_JSON,
                    DeviceApiResultHttp.failure(400, "invalid_id"));
        }
        JsonObject body = ProcessParametersHttpBody.readJsonObject(session);
        if (body == null) {
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, MIME_JSON,
                    DeviceApiResultHttp.failure(400, "invalid_json"));
        }
        ProcessParametersDataDao dao = AppDatabase.getInstance(ctx).processParametersDataDao();
        ProcessParametersRemoteService.MutationResult result =
                ProcessParametersRemoteService.updateFromJson(dao, id, body, false);
        if (!result.success) {
            int code = "not_found".equals(result.message) ? 404 : 400;
            Response.Status status = code == 404 ? Response.Status.NOT_FOUND : Response.Status.BAD_REQUEST;
            return newFixedLengthResponse(status, MIME_JSON, DeviceApiResultHttp.failure(code, result.message));
        }
        return newFixedLengthResponse(Response.Status.OK, MIME_JSON, DeviceApiResultHttp.success(null));
    }

    private static Response serveProcessParametersDelete(@NonNull Context ctx, @NonNull String idPart) {
        Long id = DeviceWsRowId.parseDecimalString(idPart);
        if (id == null) {
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, MIME_JSON,
                    DeviceApiResultHttp.failure(400, "invalid_id"));
        }
        ProcessParametersDataDao dao = AppDatabase.getInstance(ctx).processParametersDataDao();
        ProcessParametersRemoteService.MutationResult result = ProcessParametersRemoteService.delete(dao, id);
        if (!result.success) {
            int code = "not_found".equals(result.message) ? 404 : 400;
            Response.Status status = code == 404 ? Response.Status.NOT_FOUND : Response.Status.BAD_REQUEST;
            return newFixedLengthResponse(status, MIME_JSON, DeviceApiResultHttp.failure(code, result.message));
        }
        return newFixedLengthResponse(Response.Status.OK, MIME_JSON, DeviceApiResultHttp.success(null));
    }

    private static Response serveProcessParametersSetDefault(@NonNull Context ctx, @NonNull String idPart) {
        Long id = DeviceWsRowId.parseDecimalString(idPart);
        if (id == null) {
            return newFixedLengthResponse(Response.Status.BAD_REQUEST, MIME_JSON,
                    DeviceApiResultHttp.failure(400, "invalid_id"));
        }
        ProcessParametersDataDao dao = AppDatabase.getInstance(ctx).processParametersDataDao();
        ProcessParametersRemoteService.MutationResult result = ProcessParametersRemoteService.setDefault(dao, id);
        if (!result.success) {
            int code = "not_found".equals(result.message) ? 404 : 400;
            Response.Status status = code == 404 ? Response.Status.NOT_FOUND : Response.Status.BAD_REQUEST;
            return newFixedLengthResponse(status, MIME_JSON, DeviceApiResultHttp.failure(code, result.message));
        }
        return newFixedLengthResponse(Response.Status.OK, MIME_JSON, DeviceApiResultHttp.success(null));
    }

    /**
     * Configures camera eth0 segment and probes camera HTTP API (same as {@link CameraUtils#checkCamera}).
     */
    private static boolean isCameraCommunicationReady(@NonNull Context ctx) {
        try {
            if (!SystemSettingUtils.setCameraNetworkSegment(ctx)) {
                return false;
            }
        } catch (Throwable t) {
            Log.w(TAG, "camera network segment failed", t);
            return false;
        }
        return CameraUtils.checkCameraBlocking();
    }

    @NonNull
    private static Response cameraCommunicationUnavailable() {
        return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_TEXT,
                "camera_unavailable");
    }

    private static Response notFoundJson() {
        return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_JSON,
                DeviceApiResultHttp.failure(404, "not_found"));
    }

    @NonNull
    private static String normalizePath(@Nullable String uri) {
        if (uri == null || uri.isEmpty()) {
            return "/";
        }
        int q = uri.indexOf('?');
        String path = q >= 0 ? uri.substring(0, q) : uri;
        if (!path.startsWith("/")) {
            path = "/" + path;
        }
        if (path.length() > 1 && path.endsWith("/")) {
            path = path.substring(0, path.length() - 1);
        }
        return path;
    }

    /** @return int[0]=page, int[1]=pageSize */
    @VisibleForTesting
    static int[] parsePageParams(@NonNull Map<String, String> parms) {
        int page = DeviceWsVideoListPayload.DEFAULT_PAGE;
        int pageSize = DeviceWsVideoListPayload.DEFAULT_PAGE_SIZE;
        String pageStr = parms.get("page");
        String pageSizeStr = parms.get("pageSize");
        if (pageStr != null) {
            try {
                int p = Integer.parseInt(pageStr);
                if (p >= 1) {
                    page = p;
                }
            } catch (NumberFormatException ignored) {
            }
        }
        if (pageSizeStr != null) {
            try {
                int ps = Integer.parseInt(pageSizeStr);
                if (ps >= 1) {
                    pageSize = Math.min(ps, DeviceWsVideoListPayload.MAX_PAGE_SIZE);
                }
            } catch (NumberFormatException ignored) {
            }
        }
        return new int[]{page, pageSize};
    }

    @VisibleForTesting
    @NonNull
    static DeviceWsVideoListPayload.ListFilters parseQueryFilters(@NonNull Map<String, String> parms) {
        return new DeviceWsVideoListPayload.ListFilters(
                parseOptionalInt(parms.get("processType")),
                parseOptionalInt(parms.get("materialType")),
                DeviceWsVideoListPayload.startOfDayMillisFromCalendarDate(parms.get("startDate")),
                DeviceWsVideoListPayload.endOfDayMillisFromCalendarDate(parms.get("endDate")),
                DeviceWsVideoListPayload.parseCreateTimeAscending(parms.get("order")),
                parseOptionalInt(parms.get("uploadStatus")));
    }

    @Nullable
    private static Integer parseOptionalInt(@Nullable String raw) {
        if (raw == null || raw.isEmpty()) {
            return null;
        }
        try {
            return Integer.parseInt(raw);
        } catch (NumberFormatException e) {
            return null;
        }
    }

}
