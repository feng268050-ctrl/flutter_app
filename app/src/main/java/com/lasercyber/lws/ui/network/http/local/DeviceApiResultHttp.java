package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.Nullable;

import com.blankj.utilcode.util.GsonUtils;
import com.lasercyber.lws.ui.common.constant.GsonConstants;

import java.util.LinkedHashMap;
import java.util.Map;

/** JSON {@code ApiResult} bodies for the device-local HTTP server. */
public final class DeviceApiResultHttp {
    private DeviceApiResultHttp() {
    }

    public static String toJson(boolean success, int code, @Nullable String message, @Nullable Object data) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("success", success);
        body.put("code", code);
        body.put("message", message);
        body.put("data", data);
        return GsonUtils.getGson(GsonConstants.LASER_GSON).toJson(body);
    }

    public static String success(@Nullable Object data) {
        return toJson(true, 200, null, data);
    }

    public static String failure(int code, String message) {
        return toJson(false, code, message, null);
    }
}
