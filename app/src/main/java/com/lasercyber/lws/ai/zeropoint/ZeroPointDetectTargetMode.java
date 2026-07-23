package com.lasercyber.lws.ai.zeropoint;
import android.app.Activity;

import androidx.annotation.NonNull;

import com.blankj.utilcode.util.ActivityUtils;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.weld.WeldModeHost;

/**
 * Maps active weld process type to zero_point native detect target mode.
 */
public final class ZeroPointDetectTargetMode {

    public static final int POINT = 0;
    public static final int LINE = 1;

    private ZeroPointDetectTargetMode() {
    }

    public static int resolve(int weldModelType) {
        return weldModelType == ModelConstant.CONTINUOUS_WELDING ? LINE : POINT;
    }

    public static int resolveFromTopActivity() {
        Activity top = ActivityUtils.getTopActivity();
        if (top instanceof WeldModeHost host) {
            return resolve(host.getActiveWeldModelType());
        }
        return POINT;
    }

    @NonNull
    public static String logName(int mode) {
        return mode == LINE ? "line" : "point";
    }
}
