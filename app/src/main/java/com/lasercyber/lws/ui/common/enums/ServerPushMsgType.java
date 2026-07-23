package com.lasercyber.lws.ui.common.enums;

import lombok.AllArgsConstructor;
import lombok.Getter;

/** {@code msgType} values in legacy server-push JSON envelopes (WebSocket payload compatibility). */
@Getter
@AllArgsConstructor
public enum ServerPushMsgType {
    ONE_PROCESS_DATA(1),
    PROCESS_LIB(2);

    private final int value;
}
