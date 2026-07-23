package com.lasercyber.lws.ui.network.channel;

import androidx.annotation.Nullable;

import com.blankj.utilcode.util.GsonUtils;
import com.google.gson.JsonObject;
import com.lasercyber.lws.ui.bean.entity.ProcessLibrary;
import com.lasercyber.lws.ui.bean.push.ProcessLibraryPushEnvelope;
import com.lasercyber.lws.ui.common.enums.ServerPushMsgType;

/**
 * Parses WebSocket {@code command.send_process_lib} {@code payload} into {@link ProcessLibraryPushPayload}
 * for {@link ServerPushMessageHandler#saveProcessLibrary}. Accepts legacy envelope JSON or bare {@link ProcessLibrary}.
 */
public final class ServerPushProcessLibPayloadParser {
    private ServerPushProcessLibPayloadParser() {
    }

    /**
     * Accepts legacy server-push JSON (optional {@code msgType}), or a payload whose root is
     * a {@link ProcessLibrary} object (no {@code data} wrapper).
     */
    @Nullable
    public static ProcessLibraryPushPayload parse(JsonObject payload) {
        if (payload == null) {
            return null;
        }
        JsonObject withType = payload.deepCopy();
        if (!withType.has("msgType")) {
            withType.addProperty("msgType", ServerPushMsgType.PROCESS_LIB.getValue());
        }
        try {
            ProcessLibraryPushEnvelope envelope = GsonUtils.fromJson(withType.toString(), ProcessLibraryPushEnvelope.class);
            if (envelope != null && envelope.getData() != null && envelope.getData().getDataList() != null) {
                return new ProcessLibraryPushPayload()
                        .setLibrary(envelope.getData())
                        .setClientMessageId(envelope.getMsgId())
                        .setIssuedAt(envelope.getTimestamp());
            }
        } catch (Exception ignored) {
            // fall through to bare ProcessLibrary
        }
        try {
            ProcessLibrary lib = GsonUtils.fromJson(payload.toString(), ProcessLibrary.class);
            if (lib != null && lib.getDataList() != null) {
                return new ProcessLibraryPushPayload().setLibrary(lib);
            }
        } catch (Exception ignored) {
            return null;
        }
        return null;
    }
}
