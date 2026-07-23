package com.lasercyber.lws.ai.bridge;

import com.lasercyber.lws.ui.common.utils.AndroidEmulatorUtils;

/**
 * Host/runtime policy for AI native libraries. Emulator images have no Rockchip NPU;
 * {@code librknnrt} may load but {@code nativeCreate} and inference must not run.
 */
public final class AiNativeRuntime {

    /** App-level error when RKNN session or inference is requested on an unsupported host. */
    public static final int CODE_RKNN_UNAVAILABLE = -3001;

    private AiNativeRuntime() {
    }

    /** {@code true} on AVD / emulator — allow {@link NativeBridge#ensureLoaded} only. */
    public static boolean blocksRknnSession() {
        return AndroidEmulatorUtils.isLikelyEmulator();
    }

    public static String rknnUnavailableMessage() {
        return "RKNN inference unavailable on emulator (no Rockchip NPU)";
    }
}
