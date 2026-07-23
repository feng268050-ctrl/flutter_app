package com.lasercyber.lws.ui.common.handler;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.network.http.DeviceR2StsS3Client;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

/**
 * R2 STS + S3 {@code PutObject} for a local process-video file (shared by Monitor list upload and
 * 录制完成后的首次上传 {@link VideoAndProcessParamsHandler}).
 */
public final class ProcessVideoR2StsVideoPut {
    private ProcessVideoR2StsVideoPut() {
    }

    @FunctionalInterface
    public interface ByteProgress {
        void onProgress(long readSoFar, long totalBytes) throws IOException;
    }

    /**
     * @param snTrimmed device SN (trimmed)
     * @throws IOException missing file, STS failure, or {@code putObject} error
     */
    @NonNull
    public static String putLocalFile(
            @NonNull String snTrimmed,
            @NonNull File videoFile,
            @NonNull String objectKey,
            @NonNull String contentType,
            @Nullable ByteProgress byteProgress) throws IOException {
        if (!videoFile.isFile()) {
            throw new IOException("not a file: " + videoFile.getAbsolutePath());
        }
        long totalBytes = videoFile.length();
        DeviceR2StsS3Client sts = new DeviceR2StsS3Client();
        DeviceR2StsS3Client.OpenOutcome open = sts.openSession(snTrimmed.trim(), 900);
        if (!open.isOk()) {
            throw new IOException(open.getErrorMessage() != null ? open.getErrorMessage() : "R2 STS failed");
        }
        S3Client s3 = open.getS3Client();
        if (s3 == null || open.getBucket() == null) {
            if (s3 != null) {
                s3.close();
            }
            throw new IOException("R2 STS missing S3 client or bucket");
        }
        InputStream inStream = byteProgress == null
                ? new FileInputStream(videoFile)
                : new ProgressInputStream(new FileInputStream(videoFile), totalBytes, byteProgress);
        try (InputStream in = inStream) {
            RequestBody body = RequestBody.fromInputStream(in, totalBytes);
            PutObjectRequest put = PutObjectRequest.builder()
                    .bucket(open.getBucket())
                    .key(objectKey)
                    .contentType(contentType)
                    .build();
            s3.putObject(put, body);
            return ProcessVideoR2PublicUrls.publicAssetUrlFromPublicBaseUrl(open.getPublicBaseUrl(), objectKey);
        } finally {
            s3.close();
        }
    }

    private static final class ProgressInputStream extends InputStream {
        private final FileInputStream delegate;
        private final long total;
        private final ByteProgress listener;
        private long read;

        ProgressInputStream(FileInputStream delegate, long total, ByteProgress listener) {
            this.delegate = delegate;
            this.total = total;
            this.listener = listener;
        }

        @Override
        public int read() throws IOException {
            int b = delegate.read();
            if (b >= 0) {
                read++;
                listener.onProgress(read, total);
            }
            return b;
        }

        @Override
        public int read(byte[] b, int off, int len) throws IOException {
            int n = delegate.read(b, off, len);
            if (n > 0) {
                read += n;
                listener.onProgress(read, total);
            }
            return n;
        }

        @Override
        public void close() throws IOException {
            delegate.close();
        }
    }
}
