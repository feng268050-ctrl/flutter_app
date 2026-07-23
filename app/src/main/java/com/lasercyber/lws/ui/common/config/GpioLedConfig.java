package com.lasercyber.lws.ui.common.config;

public class GpioLedConfig {
    /**
     * 红色灯（ynh960 实机：GPIO 4 驱动侧边红灯，原误配为 5）
     */
    public static final int GPIO_RED = 4;
    /**
     * 黄灯（ynh960 实机：GPIO 3）
     */
    public static final int GPIO_YELLOW = 3;
    /**
     * 绿灯（ynh960 实机：GPIO 6）
     */
    public static final int GPIO_GREEN = 6;
    /**
     * 灯是否可用
     */
    public static final boolean GPIO_ENABLE=true;
}
