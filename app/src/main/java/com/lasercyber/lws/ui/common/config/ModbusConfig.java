package com.lasercyber.lws.ui.common.config;

import com.lasercyber.lws.ui.common.utils.AndroidEmulatorUtils;

public class ModbusConfig {
    /**
     * 发送数据超时时间
     */
    public static final long SEND_TIMEOUT = 3000;
    /**
     * 接收数据超时时间
     */
    public static final long RECEIVE_TIMEOUT = 3000;
    /**
     * Minimum spacing between consecutive Modbus RTU commands (control-board cooling).
     */
    public static final long COMMAND_INTERVAL_MS = 50;
    /**
     * 从机地址
     */
    public static final int SLAVE_DEVICE_ADDRESS = 1;

    private ModbusConfig() {
    }

    private static Boolean mockOverrideForTest;

    /**
     * In-process Modbus stub on Android emulator (no serial / lower controller).
     */
    public static boolean isMock() {
        if (mockOverrideForTest != null) {
            return mockOverrideForTest;
        }
        return AndroidEmulatorUtils.isLikelyEmulator();
    }

    /** @see com.lasercyber.lws.ui.common.boot.BootSelfCheckEvaluator#setEmulatorForTest */
    public static void setMockOverrideForTest(Boolean mock) {
        mockOverrideForTest = mock;
    }

    public static void resetForTest() {
        mockOverrideForTest = null;
    }
}
