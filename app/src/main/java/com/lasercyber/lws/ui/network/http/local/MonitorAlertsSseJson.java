package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import java.util.List;

/**
 * JSON payloads for monitor alerts SSE events.
 */
public final class MonitorAlertsSseJson {

    private MonitorAlertsSseJson() {
    }

    @NonNull
    public static String listData(@Nullable List<WarnTable> warns) {
        if (warns == null || warns.isEmpty()) {
            return "[]";
        }
        return GsonInitUtils.getGson().toJson(warns);
    }

    @NonNull
    public static String newData(@NonNull WarnTable warn) {
        return GsonInitUtils.getGson().toJson(warn);
    }

    @NonNull
    public static String clearData() {
        return "{}";
    }

    @NonNull
    public static String heartbeatData() {
        return "{\"ok\":true}";
    }
}
