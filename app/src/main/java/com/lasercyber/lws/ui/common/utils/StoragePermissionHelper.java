package com.lasercyber.lws.ui.common.utils;

import android.Manifest;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Environment;
import android.os.Process;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import java.lang.reflect.Field;

/**
 * Runtime permissions for reading videos under the agreed public path (e.g. {@code /sdcard/lws/...}).
 * <p>
 * On production devices where this package is a <b>privileged system app</b> (priv-app) or runs with a
 * system UID, {@link #shouldRequestRuntimeVideoRead(Context)} is false so we do not show the gallery /
 * media read dialog — access is expected to be granted by the platform or privapp permission allowlist.
 * <p>
 * Note: {@code EACCES} from {@code adb push} with restrictive POSIX modes is not fixed by Android
 * permissions; fix file mode/owner on device in that case.
 */
public final class StoragePermissionHelper {

    /** @see ApplicationInfo#PRIVATE_FLAG_PRIVILEGED (hidden); stable in AOSP. */
    private static final int PRIVATE_FLAG_PRIVILEGED = 1 << 3;

    private StoragePermissionHelper() {
    }

    @NonNull
    public static String[] videoReadPermissions() {
        if (Build.VERSION.SDK_INT >= 33) {
            return new String[]{Manifest.permission.READ_MEDIA_VIDEO};
        }
        return new String[]{Manifest.permission.READ_EXTERNAL_STORAGE};
    }

    public static boolean hasVideoReadAccess(@NonNull Context context) {
        for (String p : videoReadPermissions()) {
            if (ContextCompat.checkSelfPermission(context, p) != PackageManager.PERMISSION_GRANTED) {
                return false;
            }
        }
        return true;
    }

    /**
     * True when the platform is expected to allow reading agreed paths without a runtime media prompt
     * (even if {@link #hasVideoReadAccess(Context)} is still false on some builds).
     */
    public static boolean hasPrivilegedStorageBypass(@NonNull Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && Environment.isExternalStorageManager()) {
            return true;
        }
        if (Process.myUid() < Process.FIRST_APPLICATION_UID) {
            return true;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                ApplicationInfo ai = context.getApplicationInfo();
                Field pf = ApplicationInfo.class.getField("privateFlags");
                int privateFlags = pf.getInt(ai);
                if ((privateFlags & PRIVATE_FLAG_PRIVILEGED) != 0) {
                    return true;
                }
            } catch (ReflectiveOperationException ignored) {
                // SDK may hide the field name on some toolchains; fall through
            }
        }
        return false;
    }

    /**
     * Whether to show {@code READ_MEDIA_*} / {@code READ_EXTERNAL_STORAGE} runtime request UI.
     * When false, caller should proceed without prompting (system / priv-app / all-files access).
     */
    public static boolean shouldRequestRuntimeVideoRead(@NonNull Context context) {
        if (hasVideoReadAccess(context)) {
            return false;
        }
        return !hasPrivilegedStorageBypass(context);
    }

    public static boolean allGranted(@NonNull java.util.Map<String, Boolean> result) {
        for (Boolean b : result.values()) {
            if (b == null || !b) {
                return false;
            }
        }
        return true;
    }
}
