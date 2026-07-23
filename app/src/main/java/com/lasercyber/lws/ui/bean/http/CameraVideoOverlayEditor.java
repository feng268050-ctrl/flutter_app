package com.lasercyber.lws.ui.bean.http;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.gson.JsonObject;

/** Mutates camera {@code GET/PUT /Media/Video/overlays?channel=1} JSON. */
public final class CameraVideoOverlayEditor {
    /** Main-stream overlay channel (IPC HTTP query {@code channel=1}). */
    public static final String OVERLAYS_CHANNEL_1_PATH = "Media/Video/overlays?channel=1";

    public static final int NAME_OVERLAY_Y_OFFSET = 50;

    private CameraVideoOverlayEditor() {
    }

    /**
     * Returns overlay config root when {@code response} is a successful payload
     * ({@code VideoOverlay} present, no IPC {@code errCode} error wrapper).
     */
    @Nullable
    public static JsonObject parseOverlayConfig(@Nullable JsonObject response) {
        if (response == null) {
            return null;
        }
        if (response.has("errCode") && !response.get("errCode").isJsonNull()) {
            return null;
        }
        if (!response.has("VideoOverlay") || !response.get("VideoOverlay").isJsonObject()) {
            return null;
        }
        return response;
    }

    /**
     * Updates {@code VideoOverlay.NameOverlay}.
     * When {@code enable == 1}: {@code enable=1}, {@code x=positionX}, {@code y=positionY + 50}, {@code name}.
     * When {@code enable == 0}: {@code enable=0} (hide device name).
     */
    @Nullable
    public static JsonObject applyNameOverlay(@NonNull JsonObject config, int enable, int positionX,
                                              int positionY, @NonNull String name) {
        JsonObject root = config.deepCopy();
        JsonObject videoOverlay = root.getAsJsonObject("VideoOverlay");
        if (videoOverlay == null) {
            return null;
        }
        JsonObject nameOverlay = videoOverlay.getAsJsonObject("NameOverlay");
        if (nameOverlay == null) {
            nameOverlay = new JsonObject();
            videoOverlay.add("NameOverlay", nameOverlay);
        }
        if (enable == 1) {
            nameOverlay.addProperty("enable", 1);
            nameOverlay.addProperty("x", positionX);
            nameOverlay.addProperty("y", positionY + NAME_OVERLAY_Y_OFFSET);
            nameOverlay.addProperty("name", name);
        } else {
            nameOverlay.addProperty("enable", 0);
        }
        return root;
    }
}
