package com.lasercyber.lws.ui.common.handler;

import android.content.Context;
import android.os.Handler;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.VideoUploadStatus;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.worker.ProcessVideoCoverWorker;
import com.lasercyber.lws.ui.network.ws.DeviceWebSocketConnectionManager;
import com.lasercyber.lws.ui.repository.ProcessProcessVideoDao;

import java.io.File;
import java.io.IOException;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Monitor → Videos 列表前台上传：必要时先封面 R2 STS + {@code video.metadata}，再视频 R2 STS（与
 * {@linkplain VideoAndProcessParamsHandler 录制完成后的首次上传} 共用 {@link ProcessVideoR2StsVideoPut}）。
 */
public final class MonitorProcessVideoListUploadRunner {
    private static final String TAG = LogTAGConstant.MonitorListVideoUpload;
    private static final ConcurrentHashMap<Long, Object> ROW_LOCKS = new ConcurrentHashMap<>();

    private final AtomicBoolean cancelled = new AtomicBoolean(false);

    public interface Listener {
        void onMetadataPhaseStarted();

        void onVideoProgress(int percent0to100, @Nullable String detail);

        /** @param videoPublicUrl HTTPS URL for the uploaded object when derivable from {@code coverUrl}; else empty. */
        void onFinishedSuccess(@Nullable String videoPublicUrl);

        void onFinishedError(@Nullable String message);
    }

    public void cancel() {
        cancelled.set(true);
    }

    public boolean isCancelled() {
        return cancelled.get();
    }

    private static Object rowLock(long rowId) {
        return ROW_LOCKS.computeIfAbsent(rowId, k -> new Object());
    }

    public void runForeground(Context app, long rowId, Handler main, Listener listener) {
        Context ctx = app.getApplicationContext();
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                runBody(ctx, rowId, main, listener);
            } catch (Throwable t) {
                Log.e(TAG, "upload failed rowId=" + rowId, t);
                String msg = t.getMessage() != null ? t.getMessage() : t.getClass().getSimpleName();
                post(main, () -> listener.onFinishedError(msg));
            }
        });
    }

    private void runBody(Context ctx, long rowId, Handler main, Listener listener) {
        if (rowId <= 0) {
            post(main, () -> listener.onFinishedError("invalid row"));
            return;
        }
        ProcessProcessVideoDao dao = AppDatabase.getInstance(ctx).processProcessVideoDao();
        ProcessParamsVideo row = dao.selectById(rowId);
        if (row == null) {
            post(main, () -> listener.onFinishedError("row missing"));
            return;
        }
        if (row.getVideoId() == null || row.getVideoId().trim().isEmpty()) {
            post(main, () -> listener.onFinishedError("missing videoId"));
            return;
        }
        String path = row.getVideoPath();
        if (path == null || path.isEmpty()) {
            post(main, () -> listener.onFinishedError("missing video path"));
            return;
        }
        File videoFile = new File(path);
        if (!videoFile.isFile()) {
            post(main, () -> listener.onFinishedError("video file missing"));
            return;
        }
        if (row.getUploadStatus() == VideoUploadStatus.VIDEO_UPLOADED) {
            post(main, () -> listener.onFinishedError("already uploaded"));
            return;
        }
        String sn = DeviceIdentity.getDeviceSnSafely();
        if (sn == null || sn.trim().isEmpty() || DeviceIdentity.UNKNOWN_SN.equals(sn)) {
            post(main, () -> listener.onFinishedError("invalid device sn"));
            return;
        }
        if (DeviceApiOriginConfig.getPinnedBase() == null) {
            post(main, () -> listener.onFinishedError("api origin not selected"));
            return;
        }

        synchronized (rowLock(rowId)) {
            ProcessVideoCoverWorker.cancelUniqueWorkForRow(ctx, rowId);
            row = dao.selectById(rowId);
            if (row == null) {
                post(main, () -> listener.onFinishedError("row missing"));
                return;
            }
            if (row.getUploadStatus() == VideoUploadStatus.VIDEO_UPLOADING) {
                dao.updateUploadStatusAndProgressById(rowId, VideoUploadStatus.COVER_UPLOADED, 0);
                row = dao.selectById(rowId);
            }
            if (row == null) {
                post(main, () -> listener.onFinishedError("row missing"));
                return;
            }

            if (row.getUploadStatus() == VideoUploadStatus.NOT_INITIATED) {
                post(main, listener::onMetadataPhaseStarted);
                for (int attempt = 1; attempt <= 3; attempt++) {
                    if (cancelled.get()) {
                        post(main, () -> listener.onFinishedError(null));
                        return;
                    }
                    try {
                        ProcessVideoCoverR2Upload.uploadCoverForRowIfPending(ctx, rowId);
                        break;
                    } catch (Exception e) {
                        Log.w(TAG, "cover upload attempt " + attempt + "/3 rowId=" + rowId, e);
                        if (attempt >= 3) {
                            post(main, () -> listener.onFinishedError(
                                    e.getMessage() != null ? e.getMessage() : "cover upload failed"));
                            return;
                        }
                        try {
                            Thread.sleep(800L * attempt);
                        } catch (InterruptedException ie) {
                            Thread.currentThread().interrupt();
                            post(main, () -> listener.onFinishedError(null));
                            return;
                        }
                    }
                }
                row = dao.selectById(rowId);
            }

            if (cancelled.get()) {
                post(main, () -> listener.onFinishedError(null));
                return;
            }
            if (row == null || row.getUploadStatus() != VideoUploadStatus.COVER_UPLOADED) {
                post(main, () -> listener.onFinishedError("cover not ready"));
                return;
            }
        }

        row = dao.selectById(rowId);
        if (row == null || cancelled.get()) {
            post(main, () -> listener.onFinishedError(cancelled.get() ? null : "row missing"));
            return;
        }

        String dateStr = ProcessVideoUploadR2Keys.yyyyMmDdFromCreateTimeMillis(row.getCreateTime());
        String ext = ProcessVideoUploadR2Keys.videoExtFromPath(path);
        String contentType = guessVideoContentType(ext);
        String objectKey = ProcessVideoUploadR2Keys.videoObjectKey(sn, dateStr, row.getVideoId(), ext);
        String videoUuid = row.getVideoId().trim();

        dao.updateUploadStatusAndProgressById(rowId, VideoUploadStatus.VIDEO_UPLOADING, 0);
        WsThrottle wsThrottle = new WsThrottle();
        emitWs(ctx, videoUuid, VideoUploadStatus.VIDEO_UPLOADING, 0, "", wsThrottle, true);

        AtomicInteger lastProgressBucket = new AtomicInteger(-1);
        try {
            ProcessVideoR2StsVideoPut.putLocalFile(sn.trim(), videoFile, objectKey, contentType, (read, total) -> {
                if (cancelled.get()) {
                    throw new IOException("cancelled");
                }
                int pct = (int) Math.min(100L, read * 100L / Math.max(1L, total));
                int bucket = pct / 2;
                if (bucket != lastProgressBucket.get()) {
                    lastProgressBucket.set(bucket);
                    dao.updateUploadStatusAndProgressById(rowId, VideoUploadStatus.VIDEO_UPLOADING, pct);
                    post(main, () -> listener.onVideoProgress(pct, null));
                }
                emitWs(ctx, videoUuid, VideoUploadStatus.VIDEO_UPLOADING, pct, "", wsThrottle, false);
            });
        } catch (Exception e) {
            Log.e(TAG, "sts putObject failed rowId=" + rowId, e);
            dao.updateUploadStatusAndProgressById(rowId, VideoUploadStatus.COVER_UPLOADED, 0);
            if (cancelled.get()) {
                post(main, () -> listener.onFinishedError(null));
            } else {
                post(main, () -> listener.onFinishedError(
                        e.getMessage() != null ? e.getMessage() : "video upload failed"));
            }
            return;
        }

        if (cancelled.get()) {
            dao.updateUploadStatusAndProgressById(rowId, VideoUploadStatus.COVER_UPLOADED, 0);
            post(main, () -> listener.onFinishedError(null));
            return;
        }

        row = dao.selectById(rowId);
        String videoPublicUrl = ProcessVideoR2PublicUrls.publicAssetUrlFromCoverPublicUrl(
                row != null ? row.getCoverUrl() : null, objectKey);
        dao.updateVideoCloudStateById(rowId, VideoUploadStatus.VIDEO_UPLOADED, 100, videoPublicUrl);
        emitWs(ctx, videoUuid, VideoUploadStatus.VIDEO_UPLOADED, 100, videoPublicUrl, wsThrottle, true);
        post(main, () -> listener.onFinishedSuccess(videoPublicUrl));
    }

    private static void emitWs(Context ctx, String videoUuid, int uploadStatus, int progress, String videoUrl,
            WsThrottle throttle, boolean force) {
        if (!force && !throttle.shouldEmit(progress)) {
            return;
        }
        DeviceWebSocketConnectionManager.getInstance().sendVideoUploading(videoUuid, uploadStatus, progress, videoUrl);
    }

    private static String guessVideoContentType(String extLowerNoDot) {
        switch (extLowerNoDot) {
            case "mp4":
                return "video/mp4";
            case "webm":
                return "video/webm";
            case "3gp":
            case "3gpp":
                return "video/3gpp";
            case "mkv":
                return "video/x-matroska";
            default:
                return "application/octet-stream";
        }
    }

    private static void post(Handler main, Runnable r) {
        main.post(r);
    }

    private static final class WsThrottle {
        private long lastEmitMs;
        private int lastPercent = -1;

        boolean shouldEmit(int p) {
            long now = System.currentTimeMillis();
            if (lastPercent < 0) {
                lastPercent = p;
                lastEmitMs = now;
                return true;
            }
            if (p - lastPercent >= 5) {
                lastPercent = p;
                lastEmitMs = now;
                return true;
            }
            if (now - lastEmitMs >= 2000L) {
                lastPercent = p;
                lastEmitMs = now;
                return true;
            }
            return false;
        }
    }
}
