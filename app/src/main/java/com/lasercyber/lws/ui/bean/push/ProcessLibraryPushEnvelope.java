package com.lasercyber.lws.ui.bean.push;

import com.lasercyber.lws.ui.bean.entity.ProcessLibrary;
import com.lasercyber.lws.ui.common.enums.ServerPushMsgType;

import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.experimental.Accessors;

@EqualsAndHashCode(callSuper = true)
@Data
@Accessors(chain = true)
public class ProcessLibraryPushEnvelope extends ServerPushEnvelope<ProcessLibrary> {
    @Override
    public int getMsgType() {
        return ServerPushMsgType.PROCESS_LIB.getValue();
    }
}
