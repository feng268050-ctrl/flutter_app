package com.lasercyber.lws.ui.common.handler;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.VideoUploadStatus;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;
import com.lasercyber.lws.ui.common.utils.VideoCoverExtractor;
import com.lasercyber.lws.ui.network.ws.DeviceWebSocketConnectionManager;
import com.lasercyber.lws.ui.repository.ProcessProcessVideoDao;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

/**
 * R2 STS + S3 PutObject for process-video JPEG cover + DB {@link VideoUploadStatus#COVER_UPLOADED} + {@code video.metadata} WS.
 * Shared by {@link MonitorProcessVideoListUploadRunner} and {@link com.lasercyber.lws.ui.common.worker.ProcessVideoCoverWorker}.
 */
public final class ProcessVideoCoverR2Upload {
    private static final String TAG = LogTAGConstant.VideoCoverUpload;

    private ProcessVideoCoverR2Upload() {
    }

    /**
     * Upload cover for a row that is still {@link VideoUploadStatus#NOT_INITIATED}. No-op if row already past that state.
     *
     * @throws IOException STS/S3/network failures (caller may retry)
     */
    public static void uploadCoverForRowIfPending(@NonNull Context app, long rowId) throws IOException {
        if (rowId <= 0) {
            throw new IOException("invalid row id");
        }
        if (DeviceApiOriginConfig.getPinnedBase() == null) {
            throw new IOException("api origin not selected");
        }
        String sn = DeviceIdentity.getDeviceSnSafely();
        if (sn == null || sn.trim().isEmpty() || DeviceIdentity.UNKNOWN_SN.equals(sn)) {
            throw new IOException("invalid device sn");
        }
        String snTrimmed = sn.trim();
        ProcessProcessVideoDao dao = AppDatabase.getInstance(app).processProcessVideoDao();
        ProcessParamsVideo row = dao.selectById(rowId);
        if (row == null) {
            Log.i(TAG, "row gone, skip rowId=" + rowId);
            return;
        }
        if (row.getUploadStatus() != VideoUploadStatus.NOT_INITIATED) {
            Log.i(TAG, "skip already non-pending rowId=" + rowId + " uploadStatus=" + row.getUploadStatus());
            return;
        }
        if (row.getVideoId() == null || row.getVideoId().trim().isEmpty()) {
            Log.w(TAG, "skip missing videoId rowId=" + rowId);
            return;
        }
        String path = row.getVideoPath();
        if (path == null || path.isEmpty()) {
            Log.w(TAG, "skip empty videoPath rowId=" + rowId);
            return;
        }
        File videoFile = new File(path);
        if (!videoFile.isFile()) {
            Log.w(TAG, "video file missing, skip rowId=" + rowId);
            return;
        }

        File coverFile = VideoCoverExtractor.extractFirstFrameJpeg(app, path, row.getVideoId());
        byte[] jpeg;
        try {
            jpeg = Files.readAllBytes(coverFile.toPath());
        } finally {
            if (coverFile.isFile()) {
                //noinspection ResultOfMethodCallIgnored
                coverFile.delete();
            }
        }

        String dateStr = ProcessVideoUploadR2Keys.yyyyMmDdFromCreateTimeMillis(row.getCreateTime());
        String vid = row.getVideoId().trim();
        String objectKey = ProcessVideoUploadR2Keys.videoObjectKey(snTrimmed, dateStr, vid, "jpg");

        String publicUrl = ProcessVideoR2CoverUpload.putCoverJpegAndPublicUrl(snTrimmed, objectKey, jpeg);
        int n = dao.updateCoverUploaded(rowId, VideoUploadStatus.COVER_UPLOADED, publicUrl.trim());
        Log.i(TAG, "cover ok rowId=" + rowId + " dbRowsUpdated=" + n);
        ProcessParamsVideo fresh = dao.selectById(rowId);
        if (fresh != null) {
            DeviceWebSocketConnectionManager.getInstance().sendVideoMetadata(fresh);
        }
    }
}
