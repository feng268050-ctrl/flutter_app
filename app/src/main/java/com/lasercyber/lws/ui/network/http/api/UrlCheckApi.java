package com.lasercyber.lws.ui.network.http.api;

import retrofit2.Call;
import retrofit2.http.GET;
import retrofit2.http.HEAD;
import retrofit2.http.Url;

/**
 * URL检测接口
 */
public interface UrlCheckApi {
    // HEAD 请求：仅获取响应头，不获取响应体，更轻量
    @HEAD
    Call<Void> headCheck(@Url String url);

    // 备用：GET 请求（若目标服务器不支持 HEAD 请求时使用）
    @GET
    Call<Void> getCheck(@Url String url);
}
