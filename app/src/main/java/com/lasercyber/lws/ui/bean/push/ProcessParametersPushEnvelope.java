package com.lasercyber.lws.ui.bean.push;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.enums.ServerPushMsgType;

import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.experimental.Accessors;

@EqualsAndHashCode(callSuper = true)
@Data
@Accessors(chain = true)
public class ProcessParametersPushEnvelope extends ServerPushEnvelope<ProcessParametersData> {
    @Override
    public int getMsgType() {
        return ServerPushMsgType.ONE_PROCESS_DATA.getValue();
    }
}
