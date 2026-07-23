package com.lasercyber.lws.ui.common.network;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.config.CameraConfig;

/**
 * Chooses a tablet {@code eth0} IPv4 on the camera /24 subnet, avoiding the camera IP and
 * the current {@code wlan0} address when they share that subnet.
 */
public final class CameraEth0AddressPlanner {

    private static final int[] CANDIDATE_HOST_OCTETS = {234, 253, 252, 200, 11};

    private CameraEth0AddressPlanner() {
    }

    /**
     * @param cameraHost IPC host ({@link CameraConfig#getCameraIp()})
     * @param wlanIp     Current Wi-Fi IPv4 from {@link com.lasercyber.lws.ui.common.utils.WifiStatusUtils#getConnectedWifiInfo}, or null
     */
    public static String pickTabletEth0Address(
            @Nullable String cameraHost,
            @Nullable String wlanIp) {
        Ipv4 camera = parseIpv4(cameraHost);
        if (camera == null) {
            camera = parseIpv4(CameraConfig.getCameraIp());
        }
        if (camera == null) {
            return "192.168.1." + CANDIDATE_HOST_OCTETS[0];
        }

        Ipv4 wlan = parseIpv4(wlanIp);
        int wlanHost = wlan != null && sameSubnet24(camera, wlan) ? wlan.hostOctet() : -1;
        int cameraHostOctet = camera.hostOctet();

        for (int candidate : CANDIDATE_HOST_OCTETS) {
            if (isUsableHost(candidate, cameraHostOctet, wlanHost)) {
                return camera.withHostOctet(candidate).format();
            }
        }

        for (int host = 2; host <= 254; host++) {
            if (isUsableHost(host, cameraHostOctet, wlanHost)) {
                return camera.withHostOctet(host).format();
            }
        }

        return camera.withHostOctet(254).format();
    }

    /** {@code a.b.c} prefix for /24 derived from the camera address. */
    @Nullable
    public static String subnetPrefix(@Nullable String cameraHost) {
        Ipv4 camera = parseIpv4(cameraHost);
        if (camera == null) {
            camera = parseIpv4(CameraConfig.getCameraIp());
        }
        return camera == null ? null : camera.subnetPrefix();
    }

    /** {@code a.b.c.0/24} route CIDR for the camera LAN. */
    @Nullable
    public static String lanCidr(@Nullable String cameraHost) {
        String prefix = subnetPrefix(cameraHost);
        return prefix == null ? null : prefix + ".0/24";
    }

    static boolean isUsableHost(int host, int cameraHostOctet, int wlanHostOctet) {
        if (host <= 0 || host >= 255) {
            return false;
        }
        if (host == cameraHostOctet) {
            return false;
        }
        return host != wlanHostOctet;
    }

    static boolean sameSubnet24(@Nullable Ipv4 a, @Nullable Ipv4 b) {
        if (a == null || b == null) {
            return false;
        }
        return a.octet0 == b.octet0 && a.octet1 == b.octet1 && a.octet2 == b.octet2;
    }

    @Nullable
    static Ipv4 parseIpv4(@Nullable String raw) {
        if (raw == null) {
            return null;
        }
        String s = raw.trim();
        if (s.isEmpty()) {
            return null;
        }
        String[] parts = s.split("\\.");
        if (parts.length != 4) {
            return null;
        }
        int[] octets = new int[4];
        try {
            for (int i = 0; i < 4; i++) {
                int value = Integer.parseInt(parts[i]);
                if (value < 0 || value > 255) {
                    return null;
                }
                octets[i] = value;
            }
        } catch (NumberFormatException e) {
            return null;
        }
        return new Ipv4(octets[0], octets[1], octets[2], octets[3]);
    }

    static final class Ipv4 {
        final int octet0;
        final int octet1;
        final int octet2;
        final int octet3;

        Ipv4(int octet0, int octet1, int octet2, int octet3) {
            this.octet0 = octet0;
            this.octet1 = octet1;
            this.octet2 = octet2;
            this.octet3 = octet3;
        }

        int hostOctet() {
            return octet3;
        }

        String subnetPrefix() {
            return octet0 + "." + octet1 + "." + octet2;
        }

        String format() {
            return subnetPrefix() + "." + octet3;
        }

        Ipv4 withHostOctet(int host) {
            return new Ipv4(octet0, octet1, octet2, host);
        }
    }
}
