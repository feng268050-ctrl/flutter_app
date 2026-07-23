package com.lasercyber.lws.ui.network.ws;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;

/**
 * Parses Room row ids from WebSocket JSON ({@code number} or {@code string}) for JS-safe integers.
 */
public final class DeviceWsRowId {
    private DeviceWsRowId() {
    }

    @Nullable
    public static Long parse(@Nullable JsonObject payload, @NonNull String field) {
        if (payload == null || !payload.has(field) || payload.get(field).isJsonNull()) {
            return null;
        }
        return parseElement(payload.get(field));
    }

    @Nullable
    public static Long parseElement(@Nullable JsonElement element) {
        if (element == null || element.isJsonNull()) {
            return null;
        }
        if (element.isJsonPrimitive()) {
            JsonPrimitive p = element.getAsJsonPrimitive();
            if (p.isNumber()) {
                try {
                    return p.getAsLong();
                } catch (NumberFormatException | ArithmeticException e) {
                    return null;
                }
            }
            if (p.isString()) {
                return parseDecimalString(p.getAsString());
            }
        }
        return null;
    }

    @Nullable
    public static Long parseDecimalString(@Nullable String raw) {
        if (raw == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        try {
            return Long.parseLong(trimmed);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    @Nullable
    public static String toStringId(@Nullable Long id) {
        return id == null ? null : String.valueOf(id);
    }
}
