package com.lasercyber.lws.ai.bridge;

import android.content.Context;

import com.lasercyber.lws.ui.BuildConfig;

import java.io.File;

/**
 * Resolves the APK-installed directory for AI native libraries ({@code libc++_shared.so},
 * {@code librknnrt.so}, {@code libai.so}). Libraries are bundled via {@code make ai} into
 * {@code app/src/main/jniLibs/arm64-v8a/} and extracted to {@code nativeLibraryDir} at install time.
 * <p>
 * Rockchip NPU userspace ({@code librknnrt.so}) must match the kernel NPU driver shipped with the BSP.
 * Set {@code ai.library.variant} in repo-root {@code local.properties} (e.g. {@code legacy}) when building
 * a BSP-specific {@code librknnrt.so}.
 */
public final class AiLibraryDirectory {

    private AiLibraryDirectory() {
    }

    /**
     * Trimmed build-time variant from {@link BuildConfig#AI_LIBRARY_VARIANT} (repo-root {@code local.properties}
     * key {@code ai.library.variant}).
     */
    public static String buildTimeVariant() {
        try {
            String v = BuildConfig.AI_LIBRARY_VARIANT;
            return v == null ? "" : v.trim();
        } catch (Throwable ignored) {
            return "";
        }
    }

    /**
     * Directory containing {@code libai.so} for load — APK {@code nativeLibraryDir} only.
     */
    public static File resolveNativeLibDir(Context context) {
        if (context == null) {
            return null;
        }
        File apkDir = apkNativeLibDir(context);
        return hasRequiredLibrariesInDir(apkDir) ? apkDir : null;
    }

    /** APK-installed {@code jniLibs} extract dir (after {@code make ai} + install). */
    public static File apkNativeLibDir(Context context) {
        if (context == null || context.getApplicationInfo() == null) {
            return null;
        }
        String nativeLibraryDir = context.getApplicationInfo().nativeLibraryDir;
        if (nativeLibraryDir == null || nativeLibraryDir.trim().isEmpty()) {
            return null;
        }
        return new File(nativeLibraryDir);
    }

    static boolean hasRequiredLibrariesInDir(File libDir) {
        if (libDir == null || !libDir.isDirectory()) {
            return false;
        }
        return new File(libDir, "libc++_shared.so").isFile()
                && new File(libDir, "librknnrt.so").isFile()
                && new File(libDir, "libai.so").isFile();
    }
}
