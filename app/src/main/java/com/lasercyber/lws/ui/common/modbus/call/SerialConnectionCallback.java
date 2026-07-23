package com.lasercyber.lws.ui.common.modbus.call;

/**
 * 串口连接状态回调
 */
public interface SerialConnectionCallback {
    /**
     * 串口连接成功
     */
    void onConnected();

    /**
     * 串口断开连接
     */
    void onDisconnected();

    /**
     * 串口重连中
     * @param retryCount
     */
    void onReconnecting(int retryCount);

    /**
     * 串口重连失败
     * @param totalRetryCount
     */
    void onReconnectFailed(int totalRetryCount);
}
