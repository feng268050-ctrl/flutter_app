package com.lasercyber.lws.ui.network.http.local;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.gson.annotations.SerializedName;
import com.lasercyber.lws.ui.common.camera.CameraRecordCoordinator;

import java.util.LinkedHashMap;
import java.util.Map;

import fi.iki.elonen.NanoHTTPD;

/** JSON body for {@code POST /v1/camera/record}. */
public final class CameraRecordSwitchBody {
  private CameraRecordSwitchBody() {
  }

  public static final class Request {
    @SerializedName("switch")
    @Nullable
    public String recordSwitch;
  }

  public static final class Data {
    @SerializedName("switch")
    @Nullable
    public String recordSwitch;

    public Data(@Nullable String recordSwitch) {
      this.recordSwitch = recordSwitch;
    }
  }

  @Nullable
  public static String parseSwitch(@Nullable NanoHTTPD.IHTTPSession session) {
    com.google.gson.JsonObject json = ProcessParametersHttpBody.readJsonObject(session);
    if (json == null) {
      return null;
    }
    return parseSwitchFromJson(json);
  }

  @Nullable
  static String parseSwitchFromJson(@Nullable com.google.gson.JsonObject json) {
    if (json == null) {
      return null;
    }
    if (!json.has("switch") || json.get("switch").isJsonNull()) {
      return null;
    }
    if (!json.get("switch").isJsonPrimitive()) {
      return null;
    }
    String value = json.get("switch").getAsString();
    if (!"on".equals(value) && !"off".equals(value)) {
      return null;
    }
    return value;
  }

  @Nullable
  public static Map<String, Object> dataMapFor(@NonNull CameraRecordCoordinator.Result result) {
    Map<String, Object> data = new LinkedHashMap<>();
    data.put("switch", result.effectiveSwitch);
    return data;
  }
}
