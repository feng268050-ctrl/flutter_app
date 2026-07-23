package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.gson.JsonObject;
import com.google.gson.annotations.SerializedName;
import com.lasercyber.lws.ui.bean.http.CameraVideoOverlayEditor;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;

import java.util.LinkedHashMap;
import java.util.Map;

import fi.iki.elonen.NanoHTTPD;

/** JSON body for {@code POST /v1/camera/show-overlay}. */
public final class CameraShowOverlayBody {
    private static final int DEFAULT_POSITION = 10;
    private static final int MIN_POSITION_X = 0;
    private static final int MAX_POSITION_X = 384;
    private static final int MIN_POSITION_Y = 0;
    private static final int MAX_POSITION_Y = 288;
    /** Max {@code Y} when {@code enable=1} so {@code NameOverlay.y = Y + 30} stays in range. */
    private static final int MAX_POSITION_Y_WHEN_ENABLED =
            MAX_POSITION_Y - CameraVideoOverlayEditor.NAME_OVERLAY_Y_OFFSET;

    private CameraShowOverlayBody() {
    }

    public static final class Request {
        @Nullable
        public Integer enable;

        @SerializedName("positionx")
        @Nullable
        public Integer positionX;

        @SerializedName("positiony")
        @Nullable
        public Integer positionY;
    }

    public static final class Data {
        public final int enable;
        public final int positionX;
        public final int positionY;
        @NonNull
        public final String machineModel;

        public Data(int enable, int positionX, int positionY, @NonNull String machineModel) {
            this.enable = enable;
            this.positionX = positionX;
            this.positionY = positionY;
            this.machineModel = machineModel;
        }
    }

    @Nullable
    public static Request parse(@Nullable NanoHTTPD.IHTTPSession session) {
        JsonObject json = ProcessParametersHttpBody.readJsonObject(session);
        if (json == null) {
            return null;
        }
        return parseFromJson(json);
    }

    @Nullable
    static Request parseFromJson(@Nullable JsonObject json) {
        if (json == null || !json.has("enable") || json.get("enable").isJsonNull()) {
            return null;
        }
        if (!json.get("enable").isJsonPrimitive()) {
            return null;
        }
        int enable;
        try {
            enable = json.get("enable").getAsInt();
        } catch (NumberFormatException | UnsupportedOperationException ex) {
            return null;
        }
        if (enable != 0 && enable != 1) {
            return null;
        }
        int maxY = enable == 1 ? MAX_POSITION_Y_WHEN_ENABLED : MAX_POSITION_Y;
        Integer positionX = readPosition(json, "positionx", DEFAULT_POSITION, MIN_POSITION_X, MAX_POSITION_X);
        if (positionX == null) {
            return null;
        }
        Integer positionY = readPosition(json, "positiony", DEFAULT_POSITION, MIN_POSITION_Y, maxY);
        if (positionY == null) {
            return null;
        }
        Request request = new Request();
        request.enable = enable;
        request.positionX = positionX;
        request.positionY = positionY;
        return request;
    }

    @Nullable
    private static Integer readPosition(JsonObject json, String key, int defaultValue, int min, int max) {
        if (!json.has(key) || json.get(key).isJsonNull()) {
            return defaultValue;
        }
        if (!json.get(key).isJsonPrimitive()) {
            return null;
        }
        int value;
        try {
            value = json.get(key).getAsInt();
        } catch (NumberFormatException | UnsupportedOperationException ex) {
            return null;
        }
        if (value < min || value > max) {
            return null;
        }
        return value;
    }

    /** Same source as Settings → Device Information → Machine Model. */
    @NonNull
    public static String resolveMachineModel() {
        String model = DeviceModelConfig.getModel();
        return model != null ? model.trim() : "";
    }

    public static Map<String, Object> dataMapFor(@Nullable Data data) {
        Map<String, Object> map = new LinkedHashMap<>();
        if (data == null) {
            return map;
        }
        map.put("enable", data.enable);
        map.put("positionx", data.positionX);
        map.put("positiony", data.positionY);
        map.put("machineModel", data.machineModel);
        if (data.enable == 1) {
            map.put("nameoverlayy", data.positionY + CameraVideoOverlayEditor.NAME_OVERLAY_Y_OFFSET);
        }
        return map;
    }
}
