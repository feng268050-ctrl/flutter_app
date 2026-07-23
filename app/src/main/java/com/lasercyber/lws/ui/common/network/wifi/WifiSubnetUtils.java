package com.lasercyber.lws.ui.common.network.wifi;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

/**
 * Subnet mask / prefix conversions shared by validator and UI.
 */
public final class WifiSubnetUtils {

    private WifiSubnetUtils() {
    }

    public static int maskToPrefixLength(@Nullable String mask) {
        if (mask == null || mask.isEmpty()) {
            return -1;
        }
        String trimmed = mask.trim();
        if (trimmed.startsWith("/")) {
            try {
                int prefix = Integer.parseInt(trimmed.substring(1));
                return prefix >= 0 && prefix <= 32 ? prefix : -1;
            } catch (NumberFormatException e) {
                return -1;
            }
        }
        int[] octets = parseIpv4Octets(trimmed);
        if (octets == null) {
            return -1;
        }
        int value = (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
        if (value == 0) {
            return -1;
        }
        int prefix = Integer.bitCount(value);
        if (prefix <= 0 || prefix > 32) {
            return -1;
        }
        int expected = (int) (0xFFFFFFFFL << (32 - prefix));
        return value == expected ? prefix : -1;
    }

    @Nullable
    public static String prefixLengthToMask(int prefixLength) {
        if (prefixLength <= 0 || prefixLength > 32) {
            return null;
        }
        int mask = prefixLength >= 32
                ? 0xFFFFFFFF
                : (int) (0xFFFFFFFFL << (32 - prefixLength));
        return formatOctets(
                (mask >>> 24) & 0xFF,
                (mask >>> 16) & 0xFF,
                (mask >>> 8) & 0xFF,
                mask & 0xFF);
    }

    @Nullable
    public static String networkAddress(@NonNull String ip, int prefixLength) {
        long ipValue = ipv4ToLong(ip);
        if (ipValue < 0 || prefixLength < 0 || prefixLength > 32) {
            return null;
        }
        long mask = prefixLength == 0 ? 0 : (0xFFFFFFFFL << (32 - prefixLength)) & 0xFFFFFFFFL;
        return longToIpv4(ipValue & mask);
    }

    @Nullable
    public static String broadcastAddress(@NonNull String ip, int prefixLength) {
        long ipValue = ipv4ToLong(ip);
        if (ipValue < 0 || prefixLength < 0 || prefixLength > 32) {
            return null;
        }
        long mask = prefixLength == 0 ? 0 : (0xFFFFFFFFL << (32 - prefixLength)) & 0xFFFFFFFFL;
        return longToIpv4((ipValue & mask) | (~mask & 0xFFFFFFFFL));
    }

    public static boolean sameSubnet(@NonNull String ip, @NonNull String other, int prefixLength) {
        long a = ipv4ToLong(ip);
        long b = ipv4ToLong(other);
        if (a < 0 || b < 0 || prefixLength < 0 || prefixLength > 32) {
            return false;
        }
        long mask = prefixLength == 0 ? 0 : (0xFFFFFFFFL << (32 - prefixLength)) & 0xFFFFFFFFL;
        return (a & mask) == (b & mask);
    }

    @VisibleForTesting
    public static long ipv4ToLong(@NonNull String ip) {
        int[] octets = parseIpv4Octets(ip);
        if (octets == null) {
            return -1L;
        }
        return ((long) octets[0] << 24)
                | ((long) octets[1] << 16)
                | ((long) octets[2] << 8)
                | octets[3];
    }

    @Nullable
    @VisibleForTesting
    static int[] parseIpv4Octets(@NonNull String ip) {
        String[] parts = ip.trim().split("\\.");
        if (parts.length != 4) {
            return null;
        }
        int[] out = new int[4];
        try {
            for (int i = 0; i < 4; i++) {
                int value = Integer.parseInt(parts[i]);
                if (value < 0 || value > 255) {
                    return null;
                }
                out[i] = value;
            }
        } catch (NumberFormatException e) {
            return null;
        }
        return out;
    }

    @NonNull
    private static String formatOctets(int a, int b, int c, int d) {
        return a + "." + b + "." + c + "." + d;
    }

    @Nullable
    private static String longToIpv4(long value) {
        return formatOctets(
                (int) ((value >>> 24) & 0xFF),
                (int) ((value >>> 16) & 0xFF),
                (int) ((value >>> 8) & 0xFF),
                (int) (value & 0xFF));
    }
}
