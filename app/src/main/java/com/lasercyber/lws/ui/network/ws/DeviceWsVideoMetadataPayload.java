package com.lasercyber.lws.ui.network.ws;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Builds {@code video.metadata} WebSocket payload: camelCase keys aligned with {@link ProcessParamsVideo},
 * all row catalog fields except local {@code id} and {@code videoPath}.
 */
public final class DeviceWsVideoMetadataPayload {
    private DeviceWsVideoMetadataPayload() {
    }

    @NonNull
    public static Map<String, Object> fromRow(@NonNull ProcessParamsVideo row) {
        Map<String, Object> m = new LinkedHashMap<>();
        if (row.getVideoId() != null) {
            m.put("videoId", row.getVideoId());
        }
        if (row.getProcessParametersJson() != null) {
            m.put("processParametersJson", row.getProcessParametersJson());
        }
        if (row.getProcessType() != null) {
            m.put("processType", row.getProcessType());
        }
        if (row.getMaterialType() != null) {
            m.put("materialType", row.getMaterialType());
        }
        m.put("fileSize", row.getFileSize());
        m.put("duration", row.getDuration());
        if (row.getCreateTime() != null) {
            m.put("createTime", row.getCreateTime());
        }
        if (row.getResolution() != null) {
            m.put("resolution", row.getResolution());
        }
        m.put("uploadStatus", row.getUploadStatus());
        m.put("uploadProgress", row.getUploadProgress());
        if (row.getCoverUrl() != null) {
            m.put("coverUrl", row.getCoverUrl());
        }
        if (row.getVideoUrl() != null) {
            m.put("videoUrl", row.getVideoUrl());
        }
        return m;
    }
}
