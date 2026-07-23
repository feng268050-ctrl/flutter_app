package com.lasercyber.lws.ui.common.network.proxy;

import android.content.Context;
import android.net.Network;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.BuildConfig;

import java.net.InetSocketAddress;
import java.net.Proxy;
import java.util.Collections;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

import okhttp3.Credentials;
import okhttp3.OkHttpClient;
import okhttp3.Protocol;
import okhttp3.logging.HttpLoggingInterceptor;

/**
 * Central factory for outbound {@link OkHttpClient} instances. INTERNET_PROXY_AWARE clients may use
 * {@link HttpProxySettingsStore}; DIRECT_LAN clients never use the proxy.
 */
public final class NetworkHttpClientProvider {

    private static volatile NetworkHttpClientProvider instance;

    private final HttpProxySettingsStore settingsStore;
    private final ConcurrentHashMap<ClientCacheKey, OkHttpClient> cache = new ConcurrentHashMap<>();
    private volatile long generation;

    private NetworkHttpClientProvider(@NonNull Context context) {
        this.settingsStore = new HttpProxySettingsStore(context.getApplicationContext());
    }

    public static NetworkHttpClientProvider getInstance() {
        if (instance == null) {
            synchronized (NetworkHttpClientProvider.class) {
                if (instance == null) {
                    Context app = Utils.getApp();
                    if (app == null) {
                        throw new IllegalStateException("application context unavailable");
                    }
                    instance = new NetworkHttpClientProvider(app);
                }
            }
        }
        return instance;
    }

    public long getGeneration() {
        return generation;
    }

    /** Bumps generation and drops cached clients (e.g. after proxy settings save). */
    public void invalidate() {
        generation++;
        cache.clear();
    }

    @NonNull
    public OkHttpClient getClient(
            @NonNull ClientPurpose purpose,
            @NonNull NetworkRoutePolicy routePolicy,
            @Nullable Network boundNetwork) {
        return getClientInternal(purpose, routePolicy, boundNetwork, settingsStore.load());
    }

    /**
     * Builds a short-lived probe client using draft proxy settings (Test Connection UI).
     */
    @NonNull
    public OkHttpClient getProbeClientWithSettings(
            @NonNull HttpProxySettings draftSettings,
            @Nullable Network boundNetwork) {
        return getClientInternal(ClientPurpose.PROBE, NetworkRoutePolicy.INTERNET_PROXY_AWARE,
                boundNetwork, draftSettings);
    }

    @NonNull
    private OkHttpClient getClientInternal(
            @NonNull ClientPurpose purpose,
            @NonNull NetworkRoutePolicy routePolicy,
            @Nullable Network boundNetwork,
            @NonNull HttpProxySettings proxySettings) {
        long gen = generation;
        ClientCacheKey key = new ClientCacheKey(gen, purpose, routePolicy, networkKey(boundNetwork), proxySettings);
        return cache.computeIfAbsent(key, ignored -> buildClient(purpose, routePolicy, boundNetwork, proxySettings));
    }

    @NonNull
    private OkHttpClient buildClient(
            @NonNull ClientPurpose purpose,
            @NonNull NetworkRoutePolicy routePolicy,
            @Nullable Network boundNetwork,
            @NonNull HttpProxySettings proxySettings) {
        OkHttpClient.Builder builder = new OkHttpClient.Builder();
        applyPurposeDefaults(builder, purpose);
        if (purpose == ClientPurpose.API) {
            applyApiInterceptors(builder);
        }
        if (routePolicy == NetworkRoutePolicy.INTERNET_PROXY_AWARE) {
            applyProxy(builder, proxySettings);
        } else {
            builder.proxy(Proxy.NO_PROXY);
        }
        if (boundNetwork != null) {
            builder.socketFactory(boundNetwork.getSocketFactory());
        }
        return builder.build();
    }

    private static void applyPurposeDefaults(@NonNull OkHttpClient.Builder builder, @NonNull ClientPurpose purpose) {
        switch (purpose) {
            case API -> builder
                    .connectTimeout(10, TimeUnit.SECONDS)
                    .readTimeout(10, TimeUnit.SECONDS)
                    .writeTimeout(10, TimeUnit.SECONDS)
                    .retryOnConnectionFailure(true);
            case WEBSOCKET -> builder
                    .retryOnConnectionFailure(true)
                    .pingInterval(30, TimeUnit.SECONDS);
            case PROBE -> builder
                    .connectTimeout(3, TimeUnit.SECONDS)
                    .readTimeout(4, TimeUnit.SECONDS)
                    .callTimeout(5, TimeUnit.SECONDS)
                    .retryOnConnectionFailure(false);
            case OTA_MANIFEST -> builder
                    .connectTimeout(20, TimeUnit.SECONDS)
                    .readTimeout(60, TimeUnit.SECONDS)
                    .writeTimeout(60, TimeUnit.SECONDS)
                    .retryOnConnectionFailure(true);
            case OTA_DOWNLOAD -> builder
                    .connectTimeout(30, TimeUnit.SECONDS)
                    .readTimeout(10, TimeUnit.MINUTES)
                    .writeTimeout(10, TimeUnit.MINUTES)
                    .retryOnConnectionFailure(true);
            case UPLOAD -> builder
                    .protocols(Collections.singletonList(Protocol.HTTP_1_1))
                    .connectTimeout(30, TimeUnit.SECONDS)
                    .readTimeout(5, TimeUnit.MINUTES)
                    .writeTimeout(5, TimeUnit.MINUTES)
                    .callTimeout(6, TimeUnit.MINUTES)
                    .retryOnConnectionFailure(true);
        }
    }

    private static void applyApiInterceptors(@NonNull OkHttpClient.Builder builder) {
        HttpLoggingInterceptor loggingInterceptor = new HttpLoggingInterceptor();
        if (Objects.equals(BuildConfig.DEBUG, Boolean.TRUE)) {
            loggingInterceptor.setLevel(HttpLoggingInterceptor.Level.BODY);
        } else {
            loggingInterceptor.setLevel(HttpLoggingInterceptor.Level.BASIC);
        }
        builder.addInterceptor(loggingInterceptor);
        builder.addInterceptor(chain -> {
            okhttp3.Request originalRequest = chain.request();
            okhttp3.Request newRequest = originalRequest.newBuilder()
                    .header("App-Version", BuildConfig.VERSION_NAME)
                    .header("Device-Type", "Android")
                    .build();
            return chain.proceed(newRequest);
        });
    }

    private static void applyProxy(@NonNull OkHttpClient.Builder builder, @NonNull HttpProxySettings settings) {
        if (!settings.shouldApplyProxy()) {
            return;
        }
        Proxy proxy = new Proxy(
                Proxy.Type.HTTP,
                InetSocketAddress.createUnresolved(settings.host.trim(), settings.port));
        builder.proxy(proxy);
        if (settings.authType == ProxyAuthType.BASIC) {
            String user = settings.username == null ? "" : settings.username;
            String pass = settings.password == null ? "" : settings.password;
            builder.proxyAuthenticator((route, response) -> {
                if (response.request().header("Proxy-Authorization") != null) {
                    return null;
                }
                String credential = Credentials.basic(user, pass);
                return response.request().newBuilder()
                        .header("Proxy-Authorization", credential)
                        .build();
            });
        }
    }

    @Nullable
    private static String networkKey(@Nullable Network network) {
        return network == null ? null : String.valueOf(network.getNetworkHandle());
    }

    @VisibleForTesting
    static void resetForTest() {
        synchronized (NetworkHttpClientProvider.class) {
            instance = null;
        }
    }

    private static final class ClientCacheKey {
        private final long generation;
        private final ClientPurpose purpose;
        private final NetworkRoutePolicy routePolicy;
        @Nullable
        private final String boundNetworkKey;
        private final boolean proxyEnabled;
        @NonNull
        private final String proxyHost;
        private final int proxyPort;
        @NonNull
        private final ProxyAuthType proxyAuthType;
        @NonNull
        private final String proxyUsername;
        @NonNull
        private final String proxyPassword;

        private ClientCacheKey(
                long generation,
                @NonNull ClientPurpose purpose,
                @NonNull NetworkRoutePolicy routePolicy,
                @Nullable String boundNetworkKey,
                @NonNull HttpProxySettings proxySettings) {
            this.generation = generation;
            this.purpose = purpose;
            this.routePolicy = routePolicy;
            this.boundNetworkKey = boundNetworkKey;
            this.proxyEnabled = proxySettings.enabled;
            this.proxyHost = proxySettings.host == null ? "" : proxySettings.host;
            this.proxyPort = proxySettings.port;
            this.proxyAuthType = proxySettings.authType;
            this.proxyUsername = proxySettings.username == null ? "" : proxySettings.username;
            this.proxyPassword = proxySettings.password == null ? "" : proxySettings.password;
        }

        @Override
        public boolean equals(@Nullable Object obj) {
            if (this == obj) {
                return true;
            }
            if (!(obj instanceof ClientCacheKey other)) {
                return false;
            }
            return generation == other.generation
                    && purpose == other.purpose
                    && routePolicy == other.routePolicy
                    && Objects.equals(boundNetworkKey, other.boundNetworkKey)
                    && proxyEnabled == other.proxyEnabled
                    && proxyPort == other.proxyPort
                    && proxyAuthType == other.proxyAuthType
                    && proxyHost.equals(other.proxyHost)
                    && proxyUsername.equals(other.proxyUsername)
                    && proxyPassword.equals(other.proxyPassword);
        }

        @Override
        public int hashCode() {
            return Objects.hash(
                    generation,
                    purpose,
                    routePolicy,
                    boundNetworkKey,
                    proxyEnabled,
                    proxyHost,
                    proxyPort,
                    proxyAuthType,
                    proxyUsername,
                    proxyPassword);
        }
    }
}
