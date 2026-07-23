package com.lasercyber.lws.ui.common.handler;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.oss.ObjectStorageUrls;
import com.lasercyber.lws.ui.network.http.DeviceR2StsS3Client;

import java.io.IOException;

import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

/**
 * Process-video cover: R2 STS ({@code POST /v1/storage/r2/sts}) + S3 {@code PutObject} on the Worker-pinned API origin.
 * Read URL = R2 STS {@code public_base_url} + object key (see {@link ObjectStorageUrls#joinPublicBaseUrl}).
 */
public final class ProcessVideoR2CoverUpload {
    private ProcessVideoR2CoverUpload() {
    }

    /**
     * @param snTrimmed   device SN (trimmed)
     * @param objectKey   full R2 object key
     * @param jpegBytes   cover payload
     * @return HTTPS read URL for the uploaded object
     * @throws IOException missing pinned origin, STS failure, missing {@code public_base_url}, or putObject error
     */
    @NonNull
    public static String putCoverJpegAndPublicUrl(@NonNull String snTrimmed, @NonNull String objectKey,
            @NonNull byte[] jpegBytes) throws IOException {
        if (DeviceApiOriginConfig.getPinnedBase() == null) {
            throw new IOException("api origin not selected");
        }
        if (jpegBytes.length == 0) {
            throw new IOException("cover jpeg empty");
        }
        DeviceR2StsS3Client sts = new DeviceR2StsS3Client();
        DeviceR2StsS3Client.OpenOutcome open = sts.openSession(snTrimmed, 900);
        if (!open.isOk()) {
            throw new IOException(open.getErrorMessage() != null ? open.getErrorMessage() : "R2 STS failed");
        }
        String publicBase = open.getPublicBaseUrl();
        if (publicBase == null || publicBase.trim().isEmpty()) {
            S3Client c = open.getS3Client();
            if (c != null) {
                c.close();
            }
            throw new IOException("R2 STS 响应缺少 public_base_url");
        }
        S3Client s3 = open.getS3Client();
        if (s3 == null || open.getBucket() == null) {
            if (s3 != null) {
                s3.close();
            }
            throw new IOException("R2 STS missing S3 client or bucket");
        }
        try {
            PutObjectRequest put = PutObjectRequest.builder()
                    .bucket(open.getBucket())
                    .key(objectKey)
                    .contentType("image/jpeg")
                    .build();
            s3.putObject(put, RequestBody.fromBytes(jpegBytes));
        } finally {
            s3.close();
        }
        String url = ObjectStorageUrls.joinPublicBaseUrl(publicBase, objectKey);
        if (url == null) {
            throw new IOException("无法拼接封面读 URL");
        }
        return url;
    }
}
