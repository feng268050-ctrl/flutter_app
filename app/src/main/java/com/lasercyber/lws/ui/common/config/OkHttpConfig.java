package com.lasercyber.lws.ui.common.config;

import com.lasercyber.lws.ui.common.network.proxy.ClientPurpose;
import com.lasercyber.lws.ui.common.network.proxy.NetworkHttpClientProvider;
import com.lasercyber.lws.ui.common.network.proxy.NetworkRoutePolicy;

import okhttp3.OkHttpClient;

/**
 * okhttp配置
 */
public class OkHttpConfig {
    public static OkHttpClient createOkHttpClient() {
        return NetworkHttpClientProvider.getInstance()
                .getClient(ClientPurpose.API, NetworkRoutePolicy.INTERNET_PROXY_AWARE, null);
    }
}
