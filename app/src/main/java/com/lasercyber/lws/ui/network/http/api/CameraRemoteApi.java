package com.lasercyber.lws.ui.network.http.api;

import com.lasercyber.lws.ui.bean.http.CameraDeviceInfo;
import com.lasercyber.lws.ui.bean.http.CameraShowTimeRequest;
import com.lasercyber.lws.ui.bean.http.CameraTime;
import com.lasercyber.lws.ui.bean.result.CameraResult;

import com.google.gson.JsonObject;
import retrofit2.Call;
import retrofit2.http.Body;
import retrofit2.http.GET;
import retrofit2.http.Header;
import retrofit2.http.PUT;
import retrofit2.http.Url;

/**
 * 摄像头API
 */
public interface CameraRemoteApi {
    /**
     * 更新摄像头时间
     *
     * @param authorization
     * @param cameraTime
     * @return
     */
    @PUT
    Call<CameraResult> updateCameraTime(@Header("Authorization") String authorization, @Body CameraTime cameraTime, @Url String url);

    /**
     * Camera system device info (includes {@code appVersion}).
     */
    @GET
    Call<CameraDeviceInfo> getDeviceInfo(
            @Header("Authorization") String authorization,
            @Url String url);

    /** On-screen clock overlay ({@code PUT /System/showtime}). */
    @PUT
    Call<CameraResult> updateShowTime(
            @Header("Authorization") String authorization,
            @Body CameraShowTimeRequest body,
            @Url String url);

    /** Persist last camera configuration change ({@code PUT /System/saveConf}, no body). */
    @PUT
    Call<CameraResult> saveConf(
            @Header("Authorization") String authorization,
            @Url String url);

    /** Video OSD overlays ({@code GET /Media/Video/overlays?channel=1}). */
    @GET
    Call<JsonObject> getVideoOverlays(
            @Header("Authorization") String authorization,
            @Url String url);

    /** Video OSD overlays ({@code PUT /Media/Video/overlays?channel=1}). */
    @PUT
    Call<CameraResult> putVideoOverlays(
            @Header("Authorization") String authorization,
            @Body JsonObject body,
            @Url String url);
}
