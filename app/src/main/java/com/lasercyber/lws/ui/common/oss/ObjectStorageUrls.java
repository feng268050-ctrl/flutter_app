package com.lasercyber.lws.ui.common.oss;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.config.CameraConfig;

/** R2 / S3-compatible object storage URL helpers ({@code joinPublicBaseUrl}, {@code checkVideoSize}). */
public final class ObjectStorageUrls {
    private ObjectStorageUrls() {
    }

    /**
     * Join HTTPS prefix (R2 {@code public_base_url}) with object key, normalizing slashes.
     */
    @Nullable
    public static String joinPublicBaseUrl(@Nullable String publicBaseUrl, String objectKey) {
        if (publicBaseUrl == null || publicBaseUrl.trim().isEmpty() || objectKey == null) {
            return null;
        }
        String base = publicBaseUrl.trim();
        while (base.endsWith("/")) {
            base = base.substring(0, base.length() - 1);
        }
        String key = objectKey.startsWith("/") ? objectKey.substring(1) : objectKey;
        return base + "/" + key;
    }

    /** Reject process videos larger than {@link CameraConfig#MAX_VIDEO_SIZE}. */
    public static boolean checkVideoSize(long size) {
        return size <= CameraConfig.MAX_VIDEO_SIZE;
    }
}
