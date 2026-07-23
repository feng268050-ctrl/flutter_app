package com.lasercyber.lws.ui.network.http.api;

import com.lasercyber.lws.ui.bean.http.ProcessParamsVideo;
import com.lasercyber.lws.ui.bean.result.Result;

import retrofit2.Call;
import retrofit2.http.Body;
import retrofit2.http.POST;

public interface ProcessVideoRemoteApi {
    /**
     * 上传视频基础信息和工艺库信息
     *
     * @param processParamsVideo
     * @return
     */
    @POST("videoMange/video/uploadVideoAndProcessData")
    Call<Result<Long>> uploadVideoAndProcessData(@Body ProcessParamsVideo processParamsVideo);
}
