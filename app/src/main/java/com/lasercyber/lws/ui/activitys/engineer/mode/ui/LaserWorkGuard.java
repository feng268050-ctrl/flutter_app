package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import android.content.Context;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;

/**
 * When laser enable is active in Quick/Engineer mode, force laser off if a guarded alarm is active
 * and the matching dangerous-operations bypass is OFF.
 */
public final class LaserWorkGuard {

    public interface Host {
        boolean isLaserEnableActive();

        void forceLaserOffForGuardedAlarm();
    }

    @Nullable
    private static volatile Host registeredHost;

    private LaserWorkGuard() {
    }

    public static void register(@Nullable Host host) {
        registeredHost = host;
    }

    public static void unregister(@Nullable Host host) {
        if (registeredHost == host) {
            registeredHost = null;
        }
    }

    public static void evaluateAndInterruptIfNeeded(@Nullable Context context) {
        Host host = registeredHost;
        if (host == null || context == null || !host.isLaserEnableActive()) {
            return;
        }
        Context app = context.getApplicationContext();
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (!LaserEnableAlarmGuard.isWorkBlocked(app, deviceStatus)) {
            return;
        }
        host.forceLaserOffForGuardedAlarm();
    }
}
