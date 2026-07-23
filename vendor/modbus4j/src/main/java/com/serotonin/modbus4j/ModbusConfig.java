package com.serotonin.modbus4j;

/**
 * Modbus配置
 */
public class ModbusConfig {

    private static boolean sEnableRtuCrc = true;
    private static boolean sShowSendLog = false;
    private static boolean sShowRecvLog = false;
    // 发送失败后，重新尝试连接的时间间隔(ms)
    private static SendErrorTryConnectionTime sendErrorTryConnectionTime = () -> 6000;

    /**
     * 是否启用Rtu的Crc校验
     *
     * @return
     */
    public static boolean isEnableRtuCrc() {
        return sEnableRtuCrc;
    }

    /**
     * 配置是否启用Rtu的Crc校验
     *
     * @param enableRtuCrc
     */
    public static void setEnableRtuCrc(boolean enableRtuCrc) {
        sEnableRtuCrc = enableRtuCrc;
    }

    /**
     * 配置是否打印log
     *
     * @param enableSendLog 是否显示发送的数据日志
     * @param eanbleRecvLog 是否显示接收的数据日志
     */
    public static void setEnableDataLog(boolean enableSendLog, boolean eanbleRecvLog) {
        sShowSendLog = enableSendLog;
        sShowRecvLog = eanbleRecvLog;
    }

    /**
     * 是否显示发送的数据日志
     *
     * @return
     */
    public static boolean isEnalbeSendLog() {
        return sShowSendLog;
    }

    /**
     * 是否显示接收的数据日志
     *
     * @return
     */
    public static boolean isEnalbeRecvLog() {
        return sShowRecvLog;
    }

    public static long getSendErrorTryConnectionTimeInterval() {
        if (sendErrorTryConnectionTime == null) {
            return 0;
        }
        return sendErrorTryConnectionTime.getSendErrorTryConnectionTime();
    }

    public static void setSendErrorTryConnectionTime(SendErrorTryConnectionTime sendErrorTryConnectionTime) {
        ModbusConfig.sendErrorTryConnectionTime = sendErrorTryConnectionTime;
    }

    /**
     * 发送失败后，重新尝试连接的时间间隔接口
     */
    public interface SendErrorTryConnectionTime {
        long getSendErrorTryConnectionTime();
    }
}
