package com.lasercyber.lws.ui.common.oss;

import com.lasercyber.lws.ui.common.enums.UploadFileType;

/** Upload success callback for process-video upload flows (R2 STS + S3). */
public interface OSSAsyncResumableUploadSuccess {
    void onSuccess(Object request, Object result, UploadFileType uploadFileType);
}
