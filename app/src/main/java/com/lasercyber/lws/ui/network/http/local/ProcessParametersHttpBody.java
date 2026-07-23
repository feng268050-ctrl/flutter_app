package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.Nullable;

import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import java.util.HashMap;
import java.util.Map;

import fi.iki.elonen.NanoHTTPD;

/** Reads JSON request bodies for local HTTP process-parameter routes. */
public final class ProcessParametersHttpBody {
    private ProcessParametersHttpBody() {
    }

    @Nullable
    public static JsonObject readJsonObject(@Nullable NanoHTTPD.IHTTPSession session) {
        if (session == null) {
            return null;
        }
        try {
            Map<String, String> files = new HashMap<>();
            session.parseBody(files);
            String postData = files.get("postData");
            if (postData == null || postData.trim().isEmpty()) {
                return new JsonObject();
            }
            JsonObject parsed = GsonInitUtils.getGson().fromJson(postData, JsonObject.class);
            return parsed != null ? parsed : new JsonObject();
        } catch (JsonParseException | NanoHTTPD.ResponseException | java.io.IOException e) {
            return null;
        }
    }
}
