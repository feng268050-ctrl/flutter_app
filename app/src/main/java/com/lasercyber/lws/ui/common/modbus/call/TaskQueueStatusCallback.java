package com.lasercyber.lws.ui.common.modbus.call;

/**
 * 任务队列状态回调（UI显示等待任务数）
 */
public interface TaskQueueStatusCallback {
    void onQueueSizeChanged(int size);
}
