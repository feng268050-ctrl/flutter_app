package com.lasercyber.lws.ui.network.ws;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersNameData;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Maps engineer-mode process parameters for WebSocket and local HTTP. */
public final class DeviceWsProcessParametersPayload {
    private DeviceWsProcessParametersPayload() {
    }

    @Nullable
    public static Integer parseProcessType(@Nullable JsonObject payload) {
        if (payload == null) {
            return null;
        }
        if (payload.has("process_type") && !payload.get("process_type").isJsonNull()) {
            JsonElement el = payload.get("process_type");
            if (el.isJsonPrimitive() && el.getAsJsonPrimitive().isNumber()) {
                return el.getAsInt();
            }
        }
        if (payload.has("processType") && !payload.get("processType").isJsonNull()) {
            JsonElement el = payload.get("processType");
            if (el.isJsonPrimitive() && el.getAsJsonPrimitive().isNumber()) {
                return el.getAsInt();
            }
        }
        return null;
    }

    @NonNull
    public static List<Map<String, Object>> nameListToMaps(
            @Nullable List<ProcessParametersNameData> rows,
            boolean stringIds
    ) {
        List<Map<String, Object>> out = new ArrayList<>();
        if (rows == null) {
            return out;
        }
        for (ProcessParametersNameData row : rows) {
            out.add(nameToMap(row, stringIds));
        }
        return out;
    }

    @NonNull
    public static Map<String, Object> nameToMap(@NonNull ProcessParametersNameData row, boolean stringIds) {
        Map<String, Object> m = new LinkedHashMap<>();
        putId(m, "id", row.getId(), stringIds);
        m.put("name", row.getName());
        m.put("dataType", row.getDataType());
        m.put("processType", row.getProcessType());
        m.put("materialType", row.getMaterialType());
        m.put("materialName", row.getMaterialName());
        return m;
    }

    @Nullable
    public static Map<String, Object> entityToMap(@Nullable ProcessParametersData row, boolean stringIds) {
        if (row == null) {
            return null;
        }
        JsonObject json = GsonInitUtils.getGson().toJsonTree(row).getAsJsonObject();
        applyStringIds(json, stringIds);
        @SuppressWarnings("unchecked")
        Map<String, Object> map = GsonInitUtils.getGson().fromJson(json, Map.class);
        if (map != null && stringIds) {
            if (row.getId() != null) {
                map.put("id", String.valueOf(row.getId()));
            }
            if (row.getOriginId() != null) {
                map.put("originId", String.valueOf(row.getOriginId()));
            }
        }
        return map;
    }

    /**
     * Builds a row for insert/update from JSON (WS snake_case or HTTP camelCase).
     */
    @NonNull
    public static ProcessParametersData fromPayload(@NonNull JsonObject payload, boolean wsFieldNames) {
        JsonObject normalized = normalizePayloadKeys(payload, wsFieldNames);
        ProcessParametersData data = GsonInitUtils.getGson().fromJson(normalized, ProcessParametersData.class);
        if (data == null) {
            data = new ProcessParametersData();
        }
        return data;
    }

    public static boolean isEngineerMode(@Nullable Integer dataType) {
        return ProcessDataType.isEngineerModeDataType(dataType);
    }

    @NonNull
    private static JsonObject normalizePayloadKeys(@NonNull JsonObject payload, boolean wsFieldNames) {
        JsonObject out = payload.deepCopy();
        if (wsFieldNames) {
            copyIfPresent(out, payload, "process_type", "processType");
            copyIfPresent(out, payload, "material_type", "materialType");
            copyIfPresent(out, payload, "material_name", "materialName");
            out.remove("process_type");
            out.remove("material_type");
            out.remove("material_name");
        }
        if (out.has("id") && !out.get("id").isJsonNull()) {
            Long id = DeviceWsRowId.parse(out, "id");
            if (id != null) {
                out.addProperty("id", id);
            } else {
                out.remove("id");
            }
        }
        if (out.has("originId") && !out.get("originId").isJsonNull()) {
            Long originId = DeviceWsRowId.parse(out, "originId");
            if (originId != null) {
                out.addProperty("originId", originId);
            } else {
                out.remove("originId");
            }
        }
        return out;
    }

    private static void copyIfPresent(
            @NonNull JsonObject out,
            @NonNull JsonObject src,
            @NonNull String fromKey,
            @NonNull String toKey
    ) {
        if (src.has(fromKey) && !src.get(fromKey).isJsonNull()) {
            out.add(toKey, src.get(fromKey));
        }
    }

    private static void applyStringIds(@NonNull JsonObject json, boolean stringIds) {
        if (!stringIds) {
            return;
        }
        stringifyLongField(json, "id");
        stringifyLongField(json, "originId");
    }

    private static void stringifyLongField(@NonNull JsonObject json, @NonNull String field) {
        if (!json.has(field) || json.get(field).isJsonNull()) {
            return;
        }
        JsonElement el = json.get(field);
        if (el.isJsonPrimitive() && el.getAsJsonPrimitive().isNumber()) {
            json.addProperty(field, String.valueOf(el.getAsLong()));
        }
    }

    private static void putId(
            @NonNull Map<String, Object> m,
            @NonNull String key,
            @Nullable Long id,
            boolean stringIds
    ) {
        if (id == null) {
            m.put(key, null);
            return;
        }
        m.put(key, stringIds ? String.valueOf(id) : id);
    }
}
