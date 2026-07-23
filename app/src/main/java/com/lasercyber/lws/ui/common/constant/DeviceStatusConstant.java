package com.lasercyber.lws.ui.common.constant;

public class DeviceStatusConstant {
    /** Device status + data poll refresh attempt interval (Timer tick). */
    public static final long POLL_TIMER_INTERVAL_MS = 100;

    /**
     * @deprecated Use {@link #POLL_TIMER_INTERVAL_MS}.
     */
    @Deprecated
    public static final long LOOP_DEVICE_STATUS_TIME_INTERVAL = POLL_TIMER_INTERVAL_MS;
}
