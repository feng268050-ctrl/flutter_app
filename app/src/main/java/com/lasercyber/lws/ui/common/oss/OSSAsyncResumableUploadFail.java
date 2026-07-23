package com.lasercyber.lws.ui.common.oss;

import com.lasercyber.lws.ui.common.enums.UploadFileType;

/** Upload failure callback for process-video upload flows (R2 STS + S3). */
public interface OSSAsyncResumableUploadFail {
    void onFailure(
            Object request,
            Exception clientException,
            Exception serviceException,
            UploadFileType uploadFileType);
}
