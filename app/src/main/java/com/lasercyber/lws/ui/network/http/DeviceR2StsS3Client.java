package com.lasercyber.lws.ui.network.http;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.http.R2StsApiResult;
import com.lasercyber.lws.ui.bean.http.R2StsCredentialsData;
import com.lasercyber.lws.ui.bean.http.R2StsPostRequest;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.network.proxy.ClientPurpose;
import com.lasercyber.lws.ui.common.network.proxy.NetworkHttpClientProvider;
import com.lasercyber.lws.ui.common.network.proxy.NetworkRoutePolicy;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import java.io.IOException;
import java.net.URI;

import okhttp3.HttpUrl;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okhttp3.ResponseBody;
import software.amazon.awssdk.auth.credentials.AwsSessionCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;

/**
 * Fetches R2 STS credentials via {@code POST /v1/storage/r2/sts} on the pinned Worker base, then builds an
 * {@link S3Client} for S3-compatible uploads. Instantiate with {@code new DeviceR2StsS3Client()} (or inject
 * {@link OkHttpClient} via {@link #DeviceR2StsS3Client(OkHttpClient)} for tests).
 * <p>
 * Callers MUST {@link S3Client#close()} the client from {@link OpenOutcome#getS3Client()} when finished.
 */
public final class DeviceR2StsS3Client {
    private static final String TAG = LogTAGConstant.DeviceR2StsS3Client;
    private static final MediaType JSON = MediaType.parse("application/json; charset=utf-8");

    private final OkHttpClient http;

    public DeviceR2StsS3Client() {
        this(NetworkHttpClientProvider.getInstance()
                .getClient(ClientPurpose.UPLOAD, NetworkRoutePolicy.INTERNET_PROXY_AWARE, null));
    }

    public DeviceR2StsS3Client(@NonNull OkHttpClient http) {
        this.http = http;
    }

    /**
     * POST STS then build {@link S3Client} on success.
     *
     * @param snTrimmed device serial (trimmed by caller preferred)
     * @param ttlSeconds credential lifetime, e.g. 900
     */
    @NonNull
    public OpenOutcome openSession(@NonNull String snTrimmed, int ttlSeconds) {
        HttpUrl pinned = DeviceApiOriginConfig.getPinnedBase();
        if (pinned == null) {
            Log.w(TAG, "r2 sts authorized=false reason=no_pinned_api_origin");
            return OpenOutcome.failure("api origin not selected yet");
        }
        String sn = snTrimmed.trim();
        if (sn.isEmpty() || "unknown-sn".equalsIgnoreCase(sn)) {
            Log.w(TAG, "r2 sts authorized=false reason=invalid_sn");
            return OpenOutcome.failure("invalid device sn");
        }
        if (ttlSeconds <= 0) {
            Log.w(TAG, "r2 sts authorized=false reason=invalid_ttl");
            return OpenOutcome.failure("ttl_seconds must be positive");
        }

        HttpUrl url = DeviceApiOriginConfig.joinUnderBase(pinned, "/v1/storage/r2/sts");
        R2StsPostRequest reqBody = new R2StsPostRequest().setSn(sn).setTtlSeconds(ttlSeconds);
        String json = GsonInitUtils.getGson().toJson(reqBody);
        Request request = new Request.Builder()
                .url(url)
                .post(RequestBody.create(JSON, json))
                .build();

        final R2StsApiResult parsed;
        final int httpCode;
        try (Response response = http.newCall(request).execute()) {
            httpCode = response.code();
            String rawBody = bodyString(response);
            if (rawBody == null || rawBody.isEmpty()) {
                Log.w(TAG, "r2 sts authorized=false http=" + httpCode + " reason=empty_body");
                return OpenOutcome.failure("empty sts body (http " + httpCode + ")");
            }
            try {
                parsed = GsonInitUtils.getGson().fromJson(rawBody, R2StsApiResult.class);
            } catch (RuntimeException e) {
                Log.e(TAG, "r2 sts authorized=false http=" + httpCode + " reason=json_parse", e);
                return OpenOutcome.failure("invalid sts json (http " + httpCode + ")");
            }
        } catch (IOException e) {
            Log.e(TAG, "r2 sts authorized=false reason=network", e);
            String msg = e.getMessage() != null ? e.getMessage() : "sts network error";
            return OpenOutcome.failure(msg);
        }

        if (parsed == null) {
            Log.w(TAG, "r2 sts authorized=false http=" + httpCode + " reason=null_envelope");
            return OpenOutcome.failure("sts parse null (http " + httpCode + ")");
        }
        if (!parsed.isSuccess() || parsed.getData() == null) {
            String msg = parsed.getMessage() != null ? parsed.getMessage() : "sts failed (http " + httpCode + ")";
            Log.w(TAG, "r2 sts authorized=false http=" + httpCode + " message=" + msg);
            return OpenOutcome.failure(msg);
        }

        R2StsCredentialsData data = parsed.getData();
        Long expiresAt = data.getExpiresAt();
        Log.i(TAG, "r2 sts authorized=true http=" + httpCode
                + " expires_at_ms=" + (expiresAt != null ? expiresAt : "null")
                + " bucket=" + (data.getBucket() != null ? data.getBucket() : "null"));

        S3Client s3;
        try {
            s3 = R2StsS3ClientFactory.build(data);
        } catch (RuntimeException e) {
            Log.e(TAG, "r2 s3 client created=false reason=" + e.getClass().getSimpleName(), e);
            return OpenOutcome.failure("s3 client build failed: " + e.getClass().getSimpleName());
        }
        Log.i(TAG, "r2 s3 client created=true");
        return OpenOutcome.success(s3, data.getBucket(), expiresAt != null ? expiresAt : 0L, data.getPublicBaseUrl());
    }

    private static String bodyString(Response response) throws IOException {
        ResponseBody b = response.body();
        if (b == null) {
            return "";
        }
        return b.string();
    }

    /** Builds {@link S3Client} from STS payload; throws if fields are unusable. */
    static final class R2StsS3ClientFactory {
        private R2StsS3ClientFactory() {
        }

        static S3Client build(R2StsCredentialsData d) {
            String accessKey = d.getAccessKeyId();
            String secret = d.getSecretAccessKey();
            String token = d.getSessionToken();
            String endpoint = d.getEndpointUrl();
            String regionStr = d.getRegion();
            if (accessKey == null || accessKey.isEmpty()
                    || secret == null || secret.isEmpty()
                    || token == null || token.isEmpty()
                    || endpoint == null || endpoint.isEmpty()) {
                throw new IllegalArgumentException("sts data missing required credential or endpoint fields");
            }
            String regionId = (regionStr != null && !regionStr.isEmpty()) ? regionStr.trim() : "auto";
            AwsSessionCredentials creds = AwsSessionCredentials.create(accessKey, secret, token);
            URI endpointUri = URI.create(endpoint.trim());
            return S3Client.builder()
                    .httpClient(UrlConnectionHttpClient.builder().build())
                    .credentialsProvider(StaticCredentialsProvider.create(creds))
                    .endpointOverride(endpointUri)
                    .region(Region.of(regionId))
                    .serviceConfiguration(S3Configuration.builder()
                            .pathStyleAccessEnabled(true)
                            .chunkedEncodingEnabled(false)
                            .build())
                    .build();
        }
    }

    public static final class OpenOutcome {
        private final boolean ok;
        @Nullable
        private final S3Client s3Client;
        @Nullable
        private final String bucket;
        private final long expiresAtMs;
        @Nullable
        private final String publicBaseUrl;
        @Nullable
        private final String errorMessage;

        private OpenOutcome(boolean ok, @Nullable S3Client s3Client, @Nullable String bucket, long expiresAtMs,
                @Nullable String publicBaseUrl, @Nullable String errorMessage) {
            this.ok = ok;
            this.s3Client = s3Client;
            this.bucket = bucket;
            this.expiresAtMs = expiresAtMs;
            this.publicBaseUrl = publicBaseUrl;
            this.errorMessage = errorMessage;
        }

        static OpenOutcome success(@NonNull S3Client client, @Nullable String bucket, long expiresAtMs,
                @Nullable String publicBaseUrl) {
            return new OpenOutcome(true, client, bucket, expiresAtMs, publicBaseUrl, null);
        }

        static OpenOutcome failure(String message) {
            return new OpenOutcome(false, null, null, 0L, null, message);
        }

        public boolean isOk() {
            return ok;
        }

        @Nullable
        public S3Client getS3Client() {
            return s3Client;
        }

        @Nullable
        public String getBucket() {
            return bucket;
        }

        /** Unix milliseconds from STS {@code expires_at}; {@code 0} when unknown. */
        public long getExpiresAtMs() {
            return expiresAtMs;
        }

        @Nullable
        public String getErrorMessage() {
            return errorMessage;
        }

        /**
         * R2 STS {@code public_base_url}；与 object key 拼接读 URL。失败态或未下发时可能为 null/空。
         */
        @Nullable
        public String getPublicBaseUrl() {
            return publicBaseUrl;
        }
    }
}
