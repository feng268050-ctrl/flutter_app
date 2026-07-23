package com.lasercyber.lws.ui.network.channel;

import androidx.annotation.Nullable;

import com.blankj.utilcode.util.GsonUtils;
import com.google.gson.JsonObject;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.push.ProcessParametersPushEnvelope;
import com.lasercyber.lws.ui.common.enums.ServerPushMsgType;

/**
 * Parses WebSocket {@code command.send_process_param} {@code payload} into {@link ProcessParametersPushEnvelope}
 * for {@link ServerPushMessageHandler#saveProcessData}.
 */
public final class ServerPushProcessParamPayloadParser {
    private ServerPushProcessParamPayloadParser() {
    }

    /**
     * Accepts legacy server-push JSON (optional {@code msgType}), or a payload whose root is
     * a {@link ProcessParametersData} object (no {@code data} wrapper).
     */
    @Nullable
    public static ProcessParametersPushEnvelope parse(JsonObject payload) {
        if (payload == null) {
            return null;
        }
        JsonObject withType = payload.deepCopy();
        if (!withType.has("msgType")) {
            withType.addProperty("msgType", ServerPushMsgType.ONE_PROCESS_DATA.getValue());
        }
        try {
            ProcessParametersPushEnvelope envelope = GsonUtils.fromJson(withType.toString(), ProcessParametersPushEnvelope.class);
            if (envelope != null && envelope.getData() != null) {
                return envelope;
            }
        } catch (Exception ignored) {
            // fall through to bare ProcessParametersData
        }
        try {
            ProcessParametersData data = GsonUtils.fromJson(payload.toString(), ProcessParametersData.class);
            if (data == null) {
                return null;
            }
            ProcessParametersPushEnvelope envelope = new ProcessParametersPushEnvelope();
            envelope.setData(data);
            return envelope;
        } catch (Exception ignored) {
            return null;
        }
    }
}
