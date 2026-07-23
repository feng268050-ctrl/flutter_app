package com.lasercyber.lws.ui.common.network;

import android.content.Context;
import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.AndroidEmulatorUtils;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Watches {@code eth0} physical link (sysfs carrier) and re-applies camera addressing when the
 * dedicated camera cable is re-plugged. Android's Ethernet stack does not restore our static
 * {@code eth0} IPv4 after link down/up; Wi-Fi {@link CameraEth0WifiNetworkCallback} does not run.
 */
public final class CameraEth0LinkMonitor implements Runnable {

    private static final String TAG = LogTAGConstant.SystemSettingUtils;
    private static final String IFACE = "eth0";
    private static final String CARRIER_PATH = "/sys/class/net/" + IFACE + "/carrier";

    private static final long POLL_INTERVAL_MS = 500L;
    /** Wait for GMAC / PHY to finish link-up before {@code ip addr replace}. */
    private static final long LINK_UP_SETTLE_MS = 800L;
    private static final long REFRESH_DEBOUNCE_MS = 600L;

    private static final AtomicBoolean STARTED = new AtomicBoolean();
    private static volatile long lastRefreshRequestMs;

    private CameraEth0LinkMonitor() {
    }

    /** Idempotent; safe to call from {@link com.lasercyber.lws.ui.LaserApplication}. */
    public static void start() {
        if (AndroidEmulatorUtils.isLikelyEmulator()) {
            Log.i(TAG, "CameraEth0LinkMonitor skipped on emulator");
            return;
        }
        if (!STARTED.compareAndSet(false, true)) {
            return;
        }
        Thread thread = new Thread(new CameraEth0LinkMonitor(), "camera-eth0-link");
        thread.setDaemon(true);
        thread.start();
    }

    @Override
    public void run() {
        Integer previousCarrier = null;
        while (!Thread.currentThread().isInterrupted()) {
            Integer carrier = readCarrier();
            if (carrier != null) {
                if (shouldReconfigureOnCarrierTransition(previousCarrier, carrier)) {
                    scheduleRefresh("eth0_link_up");
                }
                previousCarrier = carrier;
            }
            try {
                Thread.sleep(POLL_INTERVAL_MS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            }
        }
    }

    @VisibleForTesting
    static boolean shouldReconfigureOnCarrierTransition(@Nullable Integer previous, int current) {
        return previous != null && previous == 0 && current == 1;
    }

    @VisibleForTesting
    @Nullable
    static Integer parseCarrierLine(@Nullable String line) {
        if (line == null) {
            return null;
        }
        String trimmed = line.trim();
        if ("0".equals(trimmed)) {
            return 0;
        }
        if ("1".equals(trimmed)) {
            return 1;
        }
        return null;
    }

    @Nullable
    private static Integer readCarrier() {
        File carrierFile = new File(CARRIER_PATH);
        if (!carrierFile.canRead()) {
            return null;
        }
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                new FileInputStream(carrierFile), StandardCharsets.UTF_8))) {
            return parseCarrierLine(reader.readLine());
        } catch (IOException e) {
            Log.d(TAG, "readCarrier failed", e);
            return null;
        }
    }

    private static void scheduleRefresh(String reason) {
        long now = SystemClock.elapsedRealtime();
        if (now - lastRefreshRequestMs < REFRESH_DEBOUNCE_MS) {
            return;
        }
        lastRefreshRequestMs = now;
        ThreadPoolManager.getExecutor().execute(() -> {
            try {
                Thread.sleep(LINK_UP_SETTLE_MS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            }
            Context app = Utils.getApp();
            if (app == null) {
                return;
            }
            Log.i(TAG, "eth0 refresh (" + reason + ")");
            SystemSettingUtils.setCameraNetworkSegment(app);
        });
    }
}
