package com.lasercyber.lws.ui.common.utils;

import android.app.Activity;
import android.os.Build;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;

import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

/**
 * Emulator display tweaks. LWS AVD defaults to 2560x1600 @ 320dpi (1280x800dp, same as hardware).
 * System bars are hidden on emulator like YNH on device.
 */
public final class AndroidEmulatorUtils {

    private AndroidEmulatorUtils() {
    }

    public static boolean isLikelyEmulator() {
        String fp = Build.FINGERPRINT != null ? Build.FINGERPRINT : "";
        String model = Build.MODEL != null ? Build.MODEL : "";
        String manufacturer = Build.MANUFACTURER != null ? Build.MANUFACTURER : "";
        String brand = Build.BRAND != null ? Build.BRAND : "";
        String device = Build.DEVICE != null ? Build.DEVICE : "";
        String hardware = Build.HARDWARE != null ? Build.HARDWARE : "";
        String product = Build.PRODUCT != null ? Build.PRODUCT : "";
        if (fp.startsWith("generic") || fp.toLowerCase().contains("emulator")) {
            return true;
        }
        if (model.contains("Emulator")
                || model.contains("Android SDK built for x86")
                || model.contains("google_sdk")
                || model.contains("sdk_gphone")) {
            return true;
        }
        if (manufacturer.contains("Genymotion")) {
            return true;
        }
        if (brand.startsWith("generic") && device.startsWith("generic")) {
            return true;
        }
        return "goldfish".equals(hardware)
                || "ranchu".equals(hardware)
                || product.contains("emulator")
                || product.contains("sdk_gphone")
                || product.contains("simulator");
    }

    /** Hide status/navigation bars so 1280x800dp layouts fill the guest display (emulator only). */
    public static void hideStatusBar(Activity activity) {
        if (!isLikelyEmulator() || activity == null) {
            return;
        }
        Window window = activity.getWindow();
        if (window == null) {
            return;
        }
        WindowCompat.setDecorFitsSystemWindows(window, true);
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
        window.clearFlags(WindowManager.LayoutParams.FLAG_FORCE_NOT_FULLSCREEN);

        View decor = window.getDecorView();
        WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window, decor);
        if (controller != null) {
            controller.hide(WindowInsetsCompat.Type.statusBars() | WindowInsetsCompat.Type.navigationBars());
            controller.setSystemBarsBehavior(
                    WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        }
    }
}
