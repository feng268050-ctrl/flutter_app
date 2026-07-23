package com.lasercyber.lws.ui.common.rx.modbus.protocol;

import com.lasercyber.lws.ui.bean.entity.WarnTable;

import java.util.List;

/*告警列表回调*/
public interface WarnTableCallBack {

    public void getTableList(List<WarnTable> list);

}
