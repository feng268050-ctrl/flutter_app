package com.lasercyber.lws.ui.component.dialog;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.databinding.DataBindingUtil;

import com.lasercyber.lws.ui.R;

/**
 * Warms the machine-status dialog layout cache while engineer / quick mode is idle.
 */
public final class MachineStatusOverlayPreloader {

    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static volatile boolean warmedForProcess;

    private MachineStatusOverlayPreloader() {
    }

    public static void warmWhenIdle(@NonNull Context context) {
        Context appContext = context.getApplicationContext();
        MAIN.post(() -> Looper.myQueue().addIdleHandler(() -> {
            warmNow(appContext);
            return false;
        }));
    }

    private static void warmNow(@NonNull Context context) {
        if (warmedForProcess) {
            return;
        }
        warmedForProcess = true;
        try {
            FrameLayout scratch = new FrameLayout(context);
            DataBindingUtil.inflate(
                    LayoutInflater.from(context),
                    R.layout.fragment_laser_live_monitor_overlay,
                    scratch,
                    false);
            LayoutInflater.from(context).inflate(R.layout.machine_status_overlay_body, scratch, false);
        } catch (RuntimeException ignored) {
            warmedForProcess = false;
        }
    }
}
