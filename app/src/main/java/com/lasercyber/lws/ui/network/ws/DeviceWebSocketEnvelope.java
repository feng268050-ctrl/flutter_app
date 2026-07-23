package com.lasercyber.lws.ui.network.ws;

import androidx.annotation.Nullable;

import com.blankj.utilcode.util.GsonUtils;
import com.google.gson.Gson;
import com.google.gson.JsonElement;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Unified WebSocket JSON envelope: v, type, id, ts, payload.
 * Outbound {@code id} MUST be globally unique; use {@link #newUniqueMessageId()}.
 */
public final class DeviceWebSocketEnvelope {
    public static final int PROTOCOL_VERSION = 1;

    private DeviceWebSocketEnvelope() {
    }

    /**
     * Globally unique message id for outbound frames (RFC 4122 UUID string).
     */
    public static String newUniqueMessageId() {
        return UUID.randomUUID().toString();
    }

    public static String toJson(String type, Map<String, ?> payload, String id, long tsMillis) {
        Map<String, Object> root = new LinkedHashMap<>();
        root.put("v", PROTOCOL_VERSION);
        root.put("type", type);
        root.put("id", id);
        root.put("ts", tsMillis);
        root.put("payload", payload == null ? Map.of() : payload);
        Gson gson = GsonInitUtils.getGson();
        return gson != null ? gson.toJson(root) : GsonUtils.toJson(root);
    }

    @Nullable
    public static Parsed parse(String text) {
        if (text == null || text.trim().isEmpty()) {
            return null;
        }
        JsonObject root;
        try {
            root = GsonUtils.fromJson(text, JsonObject.class);
        } catch (JsonParseException ex) {
            return null;
        }
        if (root == null) {
            return null;
        }
        if (!root.has("v") || !root.has("type") || !root.has("id") || !root.has("ts") || !root.has("payload")) {
            return null;
        }
        JsonElement vEl = root.get("v");
        JsonElement typeEl = root.get("type");
        JsonElement idEl = root.get("id");
        JsonElement tsEl = root.get("ts");
        JsonElement payloadEl = root.get("payload");
        if (!vEl.isJsonPrimitive() || !vEl.getAsJsonPrimitive().isNumber()
                || !typeEl.isJsonPrimitive() || !typeEl.getAsJsonPrimitive().isString()
                || !idEl.isJsonPrimitive() || !idEl.getAsJsonPrimitive().isString()
                || !tsEl.isJsonPrimitive() || !tsEl.getAsJsonPrimitive().isNumber()
                || !payloadEl.isJsonObject()) {
            return null;
        }
        String id = idEl.getAsString();
        String type = typeEl.getAsString();
        if (id.trim().isEmpty() || type.trim().isEmpty()) {
            return null;
        }
        int v = vEl.getAsInt();
        if (v != PROTOCOL_VERSION) {
            return null;
        }
        long ts = tsEl.getAsLong();
        JsonObject payload = payloadEl.getAsJsonObject();
        return new Parsed(v, type, id, ts, payload);
    }

    public static boolean isValidConnectedPayload(JsonObject payload) {
        if (payload == null) {
            return false;
        }
        return nonEmptyString(payload, "sn") && nonEmptyString(payload, "connection_id");
    }

    private static boolean nonEmptyString(JsonObject o, String key) {
        if (!o.has(key) || o.get(key).isJsonNull()) {
            return false;
        }
        JsonElement e = o.get(key);
        return e.isJsonPrimitive() && e.getAsJsonPrimitive().isString() && !e.getAsString().trim().isEmpty();
    }

    @Nullable
    public static String payloadString(JsonObject payload, String key) {
        if (payload == null || !payload.has(key) || payload.get(key).isJsonNull()) {
            return null;
        }
        JsonElement e = payload.get(key);
        if (!e.isJsonPrimitive() || !e.getAsJsonPrimitive().isString()) {
            return null;
        }
        String s = e.getAsString();
        return s == null ? null : s;
    }

    public static final class Parsed {
        public final int v;
        public final String type;
        public final String id;
        public final long ts;
        public final JsonObject payload;

        Parsed(int v, String type, String id, long ts, JsonObject payload) {
            this.v = v;
            this.type = type;
            this.id = id;
            this.ts = ts;
            this.payload = payload;
        }
    }
}
