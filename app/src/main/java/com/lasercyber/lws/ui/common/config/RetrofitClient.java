package com.lasercyber.lws.ui.common.config;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;
import com.lasercyber.lws.ui.common.network.proxy.NetworkHttpClientProvider;

import retrofit2.Retrofit;
import retrofit2.adapter.rxjava3.RxJava3CallAdapterFactory;
import retrofit2.converter.gson.GsonConverterFactory;

public class RetrofitClient {
    private static volatile Retrofit retrofit;
    @Nullable
    private static volatile String retrofitBaseForEquality;

    /**
     * Active Retrofit base (trailing {@code /}) — same Worker API origin as {@link DeviceApiOriginConfig#getRetrofitBaseUrl()}.
     */
    public static String getBaseUrl() {
        return DeviceApiOriginConfig.getRetrofitBaseUrl();
    }

    /**
     * 单例模式初始化 Retrofit
     * @return
     */
    public static Retrofit getRetrofit() {
        String base = getBaseUrl();
        if (retrofit == null || retrofitBaseForEquality == null || !base.equals(retrofitBaseForEquality)) {
            synchronized (RetrofitClient.class) {
                if (retrofit == null || retrofitBaseForEquality == null || !base.equals(retrofitBaseForEquality)) {
                    retrofit = new Retrofit.Builder()
                            .baseUrl(base)
                            .client(OkHttpConfig.createOkHttpClient()) // 关联 OkHttp
                            .addConverterFactory(GsonConverterFactory.create(GsonInitUtils.getGson())) // Gson 解析
                            .addCallAdapterFactory(RxJava3CallAdapterFactory.create()) // 支持 RxJava
                            .build();
                    retrofitBaseForEquality = base;
                }
            }
        }
        return retrofit;
    }

    /** Drop cached client after runtime environment change. */
    public static void invalidate() {
        synchronized (RetrofitClient.class) {
            retrofit = null;
            retrofitBaseForEquality = null;
        }
    }

    /** Drop cached clients after HTTP proxy settings change. */
    public static void invalidateOnProxyChange() {
        NetworkHttpClientProvider.getInstance().invalidate();
        invalidate();
    }
}
