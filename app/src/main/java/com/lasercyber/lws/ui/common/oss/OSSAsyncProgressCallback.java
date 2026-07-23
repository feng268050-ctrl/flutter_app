package com.lasercyber.lws.ui.common.oss;

import com.lasercyber.lws.ui.common.enums.UploadFileType;

/**
 * 上传进度
 */
public interface OSSAsyncProgressCallback {
    /**
     * 进度回调
     *
     * @param request
     * @param currentSize
     * @param totalSize
     */
    void onProgress(Object request, long currentSize, long totalSize, UploadFileType uploadFileType);
}
