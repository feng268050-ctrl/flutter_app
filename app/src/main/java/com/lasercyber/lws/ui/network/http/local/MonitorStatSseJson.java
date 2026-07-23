package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.gson.JsonObject;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

/**
 * JSON payloads for monitor stat SSE events.
 */
public final class MonitorStatSseJson {

    private MonitorStatSseJson() {
    }

    @NonNull
    public static String statData(@NonNull MonitorStatSnapshot snapshot) {
        JsonObject root = new JsonObject();
        root.add("deviceStatus", toJsonElement(snapshot.getDeviceStatus()));
        root.add("deviceData", toJsonElement(snapshot.getDeviceData()));
        root.add("processParameters", toJsonElement(snapshot.getProcessParameters()));
        return GsonInitUtils.getGson().toJson(root);
    }

    @NonNull
    public static String heartbeatData() {
        return "{\"ok\":true}";
    }

    @NonNull
    private static com.google.gson.JsonElement toJsonElement(@Nullable Object value) {
        if (value == null) {
            return com.google.gson.JsonNull.INSTANCE;
        }
        return GsonInitUtils.getGson().toJsonTree(value);
    }
}
