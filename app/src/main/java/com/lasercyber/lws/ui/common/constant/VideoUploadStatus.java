package com.lasercyber.lws.ui.common.constant;

/**
 * {@code t_params_process_video.uploadStatus} — independent from legacy {@code status} (OSS/UI).
 */
public final class VideoUploadStatus {
    private VideoUploadStatus() {
    }

    /** Initial; cover not yet successfully uploaded (R2 STS + S3 PutObject). */
    public static final int NOT_INITIATED = 0;
    /** Cover OSS upload succeeded and {@code coverUrl} persisted. */
    public static final int COVER_UPLOADED = 1;
    /** Video file upload in progress (R2 STS S3). */
    public static final int VIDEO_UPLOADING = 2;
    /** Video file uploaded. */
    public static final int VIDEO_UPLOADED = 3;
}
