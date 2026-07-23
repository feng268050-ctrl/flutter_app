package com.lasercyber.lws.ui.network.http;

import android.util.Log;

import com.lasercyber.lws.ui.bean.http.DeviceBindingUserItem;
import com.lasercyber.lws.ui.bean.http.DeviceUsersApiResult;
import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;
import com.lasercyber.lws.ui.common.network.proxy.ClientPurpose;
import com.lasercyber.lws.ui.common.network.proxy.NetworkHttpClientProvider;
import com.lasercyber.lws.ui.common.network.proxy.NetworkRoutePolicy;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import java.io.IOException;
import java.util.Collections;
import java.util.List;

import okhttp3.HttpUrl;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;

/**
 * GET {@code /v1/devices/:sn/users} using the pinned API base
 * (same origin selection as {@link DeviceWorkerAiReportClient}).
 */
public final class DeviceWorkerUsersClient {
    private static final String TAG = LogTAGConstant.DeviceWorkerUsersClient;

    private static final Gson USERS_GSON = new GsonBuilder().serializeNulls().create();

    private DeviceWorkerUsersClient() {
    }

    /**
     * Fetches bound users for the device. On transport/parse failure or non-success API envelope,
     * returns {@link Outcome#isOk()} false (caller must not treat as unbound).
     */
    public static Outcome fetchDeviceUsers(String sn) {
        HttpUrl pinned = DeviceApiOriginConfig.getPinnedBase();
        if (pinned == null) {
            return Outcome.failure("api origin not selected yet");
        }
        if (sn == null || sn.trim().isEmpty() || DeviceIdentity.UNKNOWN_SN.equals(sn.trim())) {
            return Outcome.failure("invalid device sn");
        }
        HttpUrl url = DeviceApiOriginConfig.joinUnderBase(pinned, "/v1/devices")
                .newBuilder()
                .addPathSegment(sn.trim())
                .addPathSegment("users")
                .build();
        Request request = new Request.Builder()
                .url(url)
                .get()
                .build();
        try (Response response = apiClient().newCall(request).execute()) {
            String raw = bodyString(response);
            int httpCode = response.code();
            if (raw == null || raw.isEmpty()) {
                return Outcome.failure("empty body (http " + httpCode + ")");
            }
            DeviceUsersApiResult parsed;
            try {
                parsed = USERS_GSON.fromJson(raw, DeviceUsersApiResult.class);
            } catch (RuntimeException e) {
                Log.e(TAG, "device users json parse failed http=" + httpCode + " body=" + truncate(raw), e);
                return Outcome.failure("invalid json (http " + httpCode + ")");
            }
            if (parsed == null) {
                return Outcome.failure("parse null (http " + httpCode + ")");
            }
            if (!parsed.isSuccess()) {
                Log.w(TAG, "device users rejected http=" + httpCode
                        + " code=" + parsed.getCode()
                        + " message=" + parsed.getMessage()
                        + " body=" + truncate(raw));
                String msg = parsed.getMessage() != null
                        ? parsed.getMessage()
                        : "device users failed code=" + parsed.getCode() + " (http " + httpCode + ")";
                return Outcome.failure(msg);
            }
            List<DeviceBindingUserItem> list = parsed.getData();
            if (list == null) {
                list = Collections.emptyList();
            }
            return Outcome.success(list);
        } catch (IOException e) {
            Log.e(TAG, "device users network error", e);
            return Outcome.failure(e.getMessage() != null ? e.getMessage() : "network error");
        }
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

    private static okhttp3.OkHttpClient apiClient() {
        return NetworkHttpClientProvider.getInstance()
                .getClient(ClientPurpose.API, NetworkRoutePolicy.INTERNET_PROXY_AWARE, null);
    }

    public static final class Outcome {
        private final boolean ok;
        private final List<DeviceBindingUserItem> users;
        private final String errorMessage;

        private Outcome(boolean ok, List<DeviceBindingUserItem> users, String errorMessage) {
            this.ok = ok;
            this.users = users;
            this.errorMessage = errorMessage;
        }

        static Outcome success(List<DeviceBindingUserItem> users) {
            return new Outcome(true, users, null);
        }

        static Outcome failure(String message) {
            return new Outcome(false, null, message);
        }

        public boolean isOk() {
            return ok;
        }

        public List<DeviceBindingUserItem> getUsers() {
            return users;
        }

        public String getErrorMessage() {
            return errorMessage;
        }
    }
}
