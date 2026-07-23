package com.lasercyber.lws.ui.network.http.local;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.VideoUploadStatus;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.handler.ProcessVideoCoverR2Upload;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.VideoCoverExtractor;
import com.lasercyber.lws.ui.common.worker.ProcessVideoCoverWorker;
import com.lasercyber.lws.ui.network.ws.DeviceWsVideoListPayload;
import com.lasercyber.lws.ui.repository.ProcessProcessVideoDao;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

import fi.iki.elonen.NanoHTTPD;

/**
 * Handles {@code POST /v1/videos} multipart ingest and schedules cover upload.
 */
public final class ProcessVideoLocalUpload {
    private static final String TAG = LogTAGConstant.DeviceLocalHttpServer;

    public static final class UploadResult {
        public final boolean ok;
        public final int httpStatus;
        @Nullable
        public final String jsonBody;

        private UploadResult(boolean ok, int httpStatus, @Nullable String jsonBody) {
            this.ok = ok;
            this.httpStatus = httpStatus;
            this.jsonBody = jsonBody;
        }

        static UploadResult success(@NonNull String json) {
            return new UploadResult(true, NanoHTTPD.Response.Status.OK.getRequestStatus(), json);
        }

        static UploadResult failure(int status, @NonNull String json) {
            return new UploadResult(false, status, json);
        }
    }

    private ProcessVideoLocalUpload() {
    }

    /**
     * NanoHTTPD decodes multipart text parts with {@code US-ASCII} unless the request
     * {@code Content-Type} includes {@code charset=UTF-8}. Clients often omit it; default to UTF-8.
     */
    static void ensureMultipartUtf8Charset(@NonNull Map<String, String> headers) {
        String contentType = headers.get("content-type");
        if (contentType == null) {
            return;
        }
        String lower = contentType.toLowerCase(Locale.US);
        if (lower.contains("multipart/form-data") && !lower.contains("charset=")) {
            headers.put("content-type", contentType + "; charset=UTF-8");
        }
    }

    @NonNull
    public static UploadResult handlePost(@NonNull Context ctx, @NonNull NanoHTTPD.IHTTPSession session) {
        Map<String, String> tempFiles = new LinkedHashMap<>();
        try {
            ensureMultipartUtf8Charset(session.getHeaders());
            session.parseBody(tempFiles);
        } catch (IOException | NanoHTTPD.ResponseException e) {
            Log.w(TAG, "POST /v1/videos parseBody failed", e);
            return UploadResult.failure(400, DeviceApiResultHttp.failure(400, "invalid_multipart"));
        }

        Map<String, String> parms = session.getParms();
        String tempPath = tempFiles.get("file");
        if (tempPath == null || tempPath.isEmpty()) {
            return UploadResult.failure(400, DeviceApiResultHttp.failure(400, "missing_file"));
        }

        Integer processType = parseRequiredInt(parms.get("processType"), "processType");
        if (processType == null) {
            return UploadResult.failure(400, DeviceApiResultHttp.failure(400, "invalid_processType"));
        }
        Integer materialType = parseRequiredInt(parms.get("materialType"), "materialType");
        if (materialType == null) {
            return UploadResult.failure(400, DeviceApiResultHttp.failure(400, "invalid_materialType"));
        }
        String processParameters = parms.get("processParameters");
        if (processParameters == null) {
            processParameters = "";
        }

        File source = new File(tempPath);
        if (!source.isFile() || source.length() <= 0) {
            return UploadResult.failure(400, DeviceApiResultHttp.failure(400, "empty_file"));
        }

        String videoId = UUID.randomUUID().toString();
        File dest = destinationFile(ctx, videoId);
        File parent = dest.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            return UploadResult.failure(500, DeviceApiResultHttp.failure(500, "storage_unavailable"));
        }
        try {
            Files.copy(source.toPath(), dest.toPath(), StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            Log.e(TAG, "POST /v1/videos copy failed", e);
            return UploadResult.failure(500, DeviceApiResultHttp.failure(500, "save_failed"));
        } finally {
            //noinspection ResultOfMethodCallIgnored
            source.delete();
        }

        VideoCoverExtractor.Probe probe = VideoCoverExtractor.probeVideoFile(dest);
        if (probe.durationMs <= 0) {
            //noinspection ResultOfMethodCallIgnored
            dest.delete();
            return UploadResult.failure(400, DeviceApiResultHttp.failure(400, "invalid_video_duration"));
        }
        if (probe.resolution == null || probe.resolution.isEmpty()) {
            //noinspection ResultOfMethodCallIgnored
            dest.delete();
            return UploadResult.failure(400, DeviceApiResultHttp.failure(400, "invalid_video_resolution"));
        }
        if (probe.coverBitmap != null) {
            probe.coverBitmap.recycle();
        }

        long now = System.currentTimeMillis();
        ProcessParamsVideo row = new ProcessParamsVideo();
        row.setVideoPath(dest.getAbsolutePath());
        row.setProcessType(processType);
        row.setMaterialType(materialType);
        row.setProcessParametersJson(processParameters.trim().isEmpty() ? null : processParameters.trim());
        row.setFileSize(dest.length());
        row.setDuration(probe.durationMs);
        row.setCreateTime(now);
        row.setVideoId(videoId);
        row.setResolution(probe.resolution);
        row.setUploadStatus(VideoUploadStatus.NOT_INITIATED);
        row.setUploadProgress(0);

        ProcessProcessVideoDao dao = AppDatabase.getInstance(ctx).processProcessVideoDao();
        long rowId = dao.insert(row);
        row.setId(rowId);

        scheduleCoverUpload(ctx, rowId);

        Map<String, Object> data = DeviceWsVideoListPayload.voToRow(ProcessVideoQueryService.toVo(row));
        return UploadResult.success(DeviceApiResultHttp.success(data));
    }

    @NonNull
    static File destinationFile(@NonNull Context ctx, @NonNull String videoId) {
        File base = ctx.getExternalFilesDir(null);
        if (base == null) {
            base = new File(CameraConfig.DEFAULT_VIDEO_SAVE_PATH);
        } else {
            base = new File(base, "process_videos");
        }
        if (!base.exists()) {
            //noinspection ResultOfMethodCallIgnored
            base.mkdirs();
        }
        return new File(base, videoId + ".mp4");
    }

    static void scheduleCoverUpload(@NonNull Context ctx, long rowId) {
        ProcessVideoCoverWorker.enqueueForRow(ctx, rowId);
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                ProcessVideoCoverR2Upload.uploadCoverForRowIfPending(ctx, rowId);
            } catch (Exception e) {
                Log.w(TAG, "POST /v1/videos background cover upload rowId=" + rowId, e);
            }
        });
    }

    @Nullable
    private static Integer parseRequiredInt(@Nullable String raw, @NonNull String field) {
        if (raw == null || raw.isEmpty()) {
            Log.w(TAG, "missing " + field);
            return null;
        }
        try {
            return Integer.parseInt(raw.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

}
