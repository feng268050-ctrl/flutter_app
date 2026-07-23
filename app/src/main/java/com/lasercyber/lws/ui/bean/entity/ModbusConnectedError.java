package com.lasercyber.lws.ui.bean.entity;

import java.io.Serializable;
import java.util.Date;

import lombok.Data;

/**
 * modbus连接错误
 */
@Data
public class ModbusConnectedError implements Serializable {
    /**
     * 创建时间，第一次连接失败的时间
     */
    private Date createTime;
    /**
     * 重新连接的次数
     */
    private int reconnectCount;
    /**
     * 重试的时间间隔 ms
     */
    private int retryInterval;
    /**
     * 上一次连接的时间
     */
    private Date lastConnectTime;

    /**
     * 是否可以重试（指数退避，第一次重试150ms，无限重试）
     *
     * @return
     */
    public boolean isRetry() {
        // 1. 检查距离上次重试是否达到间隔时间，未达到则不重试
        long currentTime = new Date().getTime();
        if (currentTime - lastConnectTime.getTime() < retryInterval) {
            return false;
        }
        // 2. 重试次数自增（移除上限，支持无限重试）
        if (reconnectCount < Integer.MAX_VALUE) {
            reconnectCount++;
        }
        // 3. 更新上次重试时间
        lastConnectTime = new Date(currentTime);
        // 4. 退避规则：第一次150ms，后续指数递增，最大1分钟
        int baseInterval = 150; // 第一次重试间隔
        int maxRetryInterval = 1000 * 60; // 最大重试间隔1分钟
        // 计算下一次间隔：第1次重试后（reconnectCount=1），下一次间隔150*2^(1)=300ms；以此类推
        long nextInterval = baseInterval * (long) Math.pow(2, reconnectCount);
        // 限制最大间隔，避免超过1分钟
        retryInterval = (int) Math.min(nextInterval, maxRetryInterval);
        return true;
    }

    public static ModbusConnectedError create() {
        ModbusConnectedError modbusConnectedError = new ModbusConnectedError();
        Date date = new Date();
        modbusConnectedError.setCreateTime(date);
        modbusConnectedError.setRetryInterval(0);
        modbusConnectedError.setReconnectCount(0);
        modbusConnectedError.setLastConnectTime(date);
        return modbusConnectedError;
    }
}
