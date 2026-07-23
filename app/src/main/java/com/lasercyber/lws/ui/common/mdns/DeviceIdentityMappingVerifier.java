package com.lasercyber.lws.ui.common.mdns;

import androidx.annotation.Nullable;

import java.util.Locale;

/**
 * Verifies that discovered identity converges with existing QR/SN identity semantics.
 */
public final class DeviceIdentityMappingVerifier {
    private DeviceIdentityMappingVerifier() {
    }

    public static boolean isCanonicalIdentityMatch(@Nullable String discoveredDeviceId, @Nullable String qrOrSnId) {
        return normalize(discoveredDeviceId).equals(normalize(qrOrSnId));
    }

    private static String normalize(@Nullable String raw) {
        if (raw == null) {
            return "";
        }
        return raw.trim().toLowerCase(Locale.US);
    }
}
