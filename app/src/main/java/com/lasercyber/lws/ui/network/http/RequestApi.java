package com.lasercyber.lws.ui.network.http;

import com.lasercyber.lws.ui.common.config.RetrofitClient;
import com.lasercyber.lws.ui.network.http.api.CameraRemoteApi;
import com.lasercyber.lws.ui.network.http.api.ProcessVideoRemoteApi;
import com.lasercyber.lws.ui.network.http.api.UrlCheckApi;

public class RequestApi {
    private static volatile ProcessVideoRemoteApi processVideoRemote;
    private static volatile UrlCheckApi urlCheckApi;
    private static volatile CameraRemoteApi cameraRemoteApi;

    public static ProcessVideoRemoteApi getProcessVideoRemote() {
        if (processVideoRemote == null) {
            synchronized (RequestApi.class) {
                if (processVideoRemote == null) {
                    processVideoRemote = RetrofitClient.getRetrofit().create(ProcessVideoRemoteApi.class);
                }
            }
        }
        return processVideoRemote;
    }

    public static UrlCheckApi getUrlCheckApi() {
        if (urlCheckApi == null) {
            synchronized (RequestApi.class) {
                if (urlCheckApi == null) {
                    urlCheckApi = RetrofitClient.getRetrofit().create(UrlCheckApi.class);
                }
            }
        }
        return urlCheckApi;
    }

    public static CameraRemoteApi getCameraRemoteApi() {
        if (cameraRemoteApi == null) {
            synchronized (RequestApi.class) {
                if (cameraRemoteApi == null) {
                    cameraRemoteApi = RetrofitClient.getRetrofit().create(CameraRemoteApi.class);
                }
            }
        }
        return cameraRemoteApi;
    }

    /** Call after {@link com.lasercyber.lws.ui.common.config.RetrofitClient#invalidate()} when HTTP base URL changes. */
    public static void invalidateCachedClients() {
        synchronized (RequestApi.class) {
            processVideoRemote = null;
            urlCheckApi = null;
            cameraRemoteApi = null;
        }
    }
}
