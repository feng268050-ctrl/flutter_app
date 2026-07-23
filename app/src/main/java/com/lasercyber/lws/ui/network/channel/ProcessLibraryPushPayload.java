package com.lasercyber.lws.ui.network.channel;

import com.lasercyber.lws.ui.bean.entity.ProcessLibrary;

import lombok.Data;
import lombok.experimental.Accessors;

/**
 * WebSocket {@code command.send_process_lib} 解析结果（与传输层解耦，不含 Mq/MQTT 类型名）。
 */
@Data
@Accessors(chain = true)
public class ProcessLibraryPushPayload {
    private ProcessLibrary library;
    private String clientMessageId;
    private Long issuedAt;
}
