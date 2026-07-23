package com.lasercyber.lws.ui.common.config;

public class SerialPortConfig {
    /**
     * 串口设备路径
     */
    public static final String DEVICE_PATH="/dev/ttyS5";
    /**
     * 串口波特率
     */
    public static final int BAUD_RATE=115200;
    /**
     * 8数据位
     */
    public static final int DATA_BITS = 8;
    /**
     * 1停止位
     */
    public static final int STOP_BITS = 1;
    /**
     * 无校验（8-N-1）
     */
    public static final char PARITY = 'N';
    /**
     * 无流控
     */
    public static final int FLOW_CONTROL = 0;
    /**
     * 从机地址固定为1
     */
    public static final byte SLAVE_ADDRESS = 0x01;
    /**
     * 重连间隔
     */
    public static final int RECONNECT_INTERVAL = 3000;
    /**
     * 最大重连次数
     */
    public static final int MAX_RECONNECT_COUNT = 5;
    /**
     * 超时时间
     */
    public static final int TIME_OUT = 500;
    /**
     * 重试次数
     */
    public static final int RETRIES = 1;
}
