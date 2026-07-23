package com.lasercyber.lws.ui.bean.push;

import com.blankj.utilcode.util.GsonUtils;

import java.io.Serializable;

import cn.hutool.core.util.IdUtil;
import lombok.Data;
import lombok.experimental.Accessors;

/**
 * Legacy JSON envelope for server push payloads ({@code data}, {@code msgType}, {@code msgId}, …).
 * Still used for Gson parsing of WebSocket {@code command.send_process_param} / {@code send_process_lib}.
 */
@Accessors(chain = true)
@Data
public abstract class ServerPushEnvelope<T extends ServerPushPayload> implements Serializable {
    private T data;
    private String msgId;
    private Long timestamp;
    private int version;
    private int msgType;

    public static <T extends ServerPushPayload, K extends ServerPushEnvelope<T>> K create(T dataContent, K envelope) {
        envelope.setData(dataContent)
                .setTimestamp(System.currentTimeMillis())
                .setMsgId(IdUtil.simpleUUID())
                .setVersion(1);
        return envelope;
    }

    public abstract int getMsgType();

    public String jsonString() {
        this.msgType = getMsgType();
        return GsonUtils.toJson(this);
    }
}
