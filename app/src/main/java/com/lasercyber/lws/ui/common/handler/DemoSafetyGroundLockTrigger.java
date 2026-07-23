package com.lasercyber.lws.ui.common.handler;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.blankj.utilcode.util.ActivityUtils;
import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.SafetyGroundLockPrompt;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;

/**
 * Staging/debug helper: show the safety ground lock prompt (adb broadcast).
 * Disabled when {@link BuildConfig#RELEASE_CHANNEL} is true.
 */
public final class DemoSafetyGroundLockTrigger {

    public static final String ACTION_DEMO_SAFETY_GROUND_LOCK =
            "com.lasercyber.lws.ui.action.DEMO_SAFETY_GROUND_LOCK";
    private static final String TAG = "DemoSafetyGroundLock";

    /** machineStatusSeg1 Bit9 — gun switch on. */
    private static final int GUN_SWITCH_BIT = 1 << 9;

    @Nullable
    private static volatile Boolean releaseChannelOverride;

    private DemoSafetyGroundLockTrigger() {
    }

    public static void handle(@Nullable Context context) {
        if (isReleaseChannel()) {
            Log.d(TAG, "ignored: release channel");
            return;
        }
        Activity topActivity = ActivityUtils.getTopActivity();
        if (topActivity == null || topActivity.isFinishing() || topActivity.isDestroyed()) {
            Log.w(TAG, "demo_safety_ground_lock_skipped: no active activity");
            return;
        }
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance()
                .getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus == null) {
            deviceStatus = new DeviceStatus();
        }
        int seg1 = deviceStatus.getMachineStatusSeg1() != null ? deviceStatus.getMachineStatusSeg1() : 0;
        seg1 |= GUN_SWITCH_BIT;
        seg1 &= ~(1 << 5);
        deviceStatus.setMachineStatusSeg1(seg1);
        MemoryCacheManager.getInstance().putSerializableNoNotice(CacheKey.DEVICE_STATUS_KEY, deviceStatus);
        SafetyGroundLockPrompt.reset();
        SafetyGroundLockPrompt.maybeShow(topActivity, deviceStatus, true);
        Log.i(TAG, "triggered");
    }

    @VisibleForTesting
    static boolean isReleaseChannel() {
        if (releaseChannelOverride != null) {
            return releaseChannelOverride;
        }
        return BuildConfig.RELEASE_CHANNEL;
    }

    @VisibleForTesting
    static void setReleaseChannelOverrideForTest(@Nullable Boolean releaseChannel) {
        releaseChannelOverride = releaseChannel;
    }
}
