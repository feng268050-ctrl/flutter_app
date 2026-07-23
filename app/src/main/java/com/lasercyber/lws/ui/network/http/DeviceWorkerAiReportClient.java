package com.lasercyber.lws.ui.network.http;

import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.http.AiReportApiResult;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.network.proxy.ClientPurpose;
import com.lasercyber.lws.ui.common.network.proxy.NetworkHttpClientProvider;
import com.lasercyber.lws.ui.common.network.proxy.NetworkRoutePolicy;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

import okhttp3.HttpUrl;
import okhttp3.MediaType;
import okhttp3.MultipartBody;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okhttp3.ResponseBody;

/**
 * Multipart POST to Worker {@code /v1/devices/:sn/ai-report} using the pinned API base
 * (same origin selection as {@link DeviceR2StsS3Client}).
 */
public final class DeviceWorkerAiReportClient {
    private static final String TAG = LogTAGConstant.DeviceWorkerAiReportClient;

    private DeviceWorkerAiReportClient() {
    }

    /**
     * Build multipart body for tests and for {@link #postAiReport}.
     */
    static MultipartBody buildMultipart(int type, String model, File imageFile, @Nullable String statJson) {
        if (imageFile == null || !imageFile.isFile()) {
            throw new IllegalArgumentException("image file required");
        }
        String mime = guessImageMime(imageFile);
        RequestBody imageBody = RequestBody.create(MediaType.parse(mime), imageFile);
        MultipartBody.Builder b = new MultipartBody.Builder()
                .setType(MultipartBody.FORM)
                .addFormDataPart("type", String.valueOf(type))
                .addFormDataPart("model", model == null ? "" : model)
                .addFormDataPart("image", imageFile.getName(), imageBody);
        if (statJson != null && !statJson.isEmpty()) {
            b.addFormDataPart("stat", statJson);
        }
        return b.build();
    }

    /**
     * POST ai-report; uses {@link DeviceApiOriginConfig#getPinnedBase()} for URL construction.
     */
    public static Outcome postAiReport(String sn, int type, String model, File imageFile, @Nullable String statJson) {
        HttpUrl pinned = DeviceApiOriginConfig.getPinnedBase();
        if (pinned == null) {
            return Outcome.failure("api origin not selected yet");
        }
        if (sn == null || sn.trim().isEmpty() || "unknown-sn".equals(sn.trim())) {
            return Outcome.failure("invalid device sn");
        }
        HttpUrl url = DeviceApiOriginConfig.joinUnderBase(pinned, "/v1/devices")
                .newBuilder()
                .addPathSegment(sn.trim())
                .addPathSegment("ai-report")
                .build();
        MultipartBody body = buildMultipart(type, model, imageFile, statJson);
        Request request = new Request.Builder()
                .url(url)
                .post(body)
                .build();
        try (Response response = uploadClient().newCall(request).execute()) {
            String raw = bodyString(response);
            int httpCode = response.code();
            if (raw == null || raw.isEmpty()) {
                return Outcome.failure("empty body (http " + httpCode + ")");
            }
            AiReportApiResult parsed;
            try {
                parsed = GsonInitUtils.getGson().fromJson(raw, AiReportApiResult.class);
            } catch (RuntimeException e) {
                Log.e(TAG, "ai-report json parse failed http=" + httpCode + " body=" + truncate(raw), e);
                return Outcome.failure("invalid json (http " + httpCode + ")");
            }
            if (parsed == null) {
                return Outcome.failure("parse null (http " + httpCode + ")");
            }
            if (!parsed.isSuccess()) {
                Log.w(TAG, "ai-report rejected http=" + httpCode
                        + " code=" + parsed.getCode()
                        + " message=" + parsed.getMessage()
                        + " body=" + truncate(raw));
                String msg = parsed.getMessage() != null
                        ? parsed.getMessage()
                        : "ai-report failed code=" + parsed.getCode() + " (http " + httpCode + ")";
                return Outcome.failure(msg);
            }
            return Outcome.success(parsed);
        } catch (IOException e) {
            Log.e(TAG, "ai-report network error", e);
            return Outcome.failure(e.getMessage() != null ? e.getMessage() : "network error");
        }
    }

    private static okhttp3.OkHttpClient uploadClient() {
        return NetworkHttpClientProvider.getInstance()
                .getClient(ClientPurpose.UPLOAD, NetworkRoutePolicy.INTERNET_PROXY_AWARE, null);
    }

    private static String guessImageMime(File imageFile) {
        String sniffed = sniffImageMime(imageFile);
        if (sniffed != null) {
            return sniffed;
        }
        String name = imageFile == null ? null : imageFile.getName();
        if (name == null) {
            return "image/jpeg";
        }
        String lower = name.toLowerCase();
        if (lower.endsWith(".png")) {
            return "image/png";
        }
        if (lower.endsWith(".webp")) {
            return "image/webp";
        }
        return "image/jpeg";
    }

    @Nullable
    private static String sniffImageMime(File imageFile) {
        if (imageFile == null || !imageFile.isFile()) {
            return null;
        }
        byte[] header = new byte[16];
        int n;
        try (FileInputStream in = new FileInputStream(imageFile)) {
            n = in.read(header);
        } catch (IOException ignored) {
            return null;
        }
        if (n >= 3
                && (header[0] & 0xff) == 0xff
                && (header[1] & 0xff) == 0xd8
                && (header[2] & 0xff) == 0xff) {
            return "image/jpeg";
        }
        if (n >= 8
                && (header[0] & 0xff) == 0x89
                && header[1] == 0x50
                && header[2] == 0x4e
                && header[3] == 0x47
                && header[4] == 0x0d
                && header[5] == 0x0a
                && header[6] == 0x1a
                && header[7] == 0x0a) {
            return "image/png";
        }
        if (n >= 12
                && header[0] == 0x52
                && header[1] == 0x49
                && header[2] == 0x46
                && header[3] == 0x46
                && header[8] == 0x57
                && header[9] == 0x45
                && header[10] == 0x42
                && header[11] == 0x50) {
            return "image/webp";
        }
        return null;
    }

    private static String bodyString(Response response) throws IOException {
        ResponseBody b = response.body();
        if (b == null) {
            return "";
        }
        return b.string();
    }

    private static String truncate(String s) {
        if (s == null) {
            return "";
        }
        return s.length() > 512 ? s.substring(0, 512) + "…" : s;
    }

    public static final class Outcome {
        private final boolean ok;
        private final AiReportApiResult data;
        private final String errorMessage;

        private Outcome(boolean ok, AiReportApiResult data, String errorMessage) {
            this.ok = ok;
            this.data = data;
            this.errorMessage = errorMessage;
        }

        static Outcome success(AiReportApiResult data) {
            return new Outcome(true, data, null);
        }

        static Outcome failure(String message) {
            return new Outcome(false, null, message);
        }

        public boolean isOk() {
            return ok;
        }

        public AiReportApiResult getData() {
            return data;
        }

        public String getErrorMessage() {
            return errorMessage;
        }
    }
}
