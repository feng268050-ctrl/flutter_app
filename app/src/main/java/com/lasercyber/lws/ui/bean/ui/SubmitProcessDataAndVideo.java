package com.lasercyber.lws.ui.bean.ui;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.oss.OSSAsyncProgressCallback;
import com.lasercyber.lws.ui.common.oss.OSSAsyncResumableUploadFail;
import com.lasercyber.lws.ui.common.oss.OSSAsyncResumableUploadSuccess;

import lombok.Data;
import lombok.experimental.Accessors;

/**
 * 封装提交工艺库和视频
 */
@Data
@Accessors(chain = true)
public class SubmitProcessDataAndVideo {
    /**
     * 视频路径
     */
    private String videoPath;
    /**
     * 工艺参数
     */
    private ProcessParametersData processParametersData;
    /**
     * 视频标题
     */
    private String videoTitle;
    /**
     * 异步上传成功回调
     */
    private OSSAsyncResumableUploadSuccess ossAsyncResumableUploadSuccess;
    /**
     * 异步上传失败回调
     */
    private OSSAsyncResumableUploadFail ossAsyncResumableUploadFail;
    /**
     * 异步上传时可以设置进度回调。
     */
    private OSSAsyncProgressCallback ossProgressCallback;

}
