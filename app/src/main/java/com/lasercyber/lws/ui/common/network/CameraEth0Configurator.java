package com.lasercyber.lws.ui.common.network;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.common.utils.ShellCmdUtil;
import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import android.util.Log;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.TimeUnit;

/**
 * Applies {@code eth0} IPv4 + routes for the dedicated camera link (see {@code docs/camera-eth0-topology.md}).
 */
public final class CameraEth0Configurator {

    private static final String TAG = LogTAGConstant.SystemSettingUtils;
    private static final String IFACE = "eth0";
    private static final int ROUTE_ATTEMPTS = 3;
    private static final long ROUTE_RETRY_DELAY_MS = 350L;
    private static final long POST_ADDR_SETTLE_MS = 300L;

    private CameraEth0Configurator() {
    }

    public static final class Result {
        public final String cameraHost;
        public final String tabletIp;
        @Nullable
        public final String wlanIp;
        public final boolean linkUp;
        public final boolean addressOk;
        public final boolean routeOk;
        public final boolean pingOk;
        public final boolean flushed;
        @Nullable
        public final String eth0Ipv4;

        Result(String cameraHost, String tabletIp, @Nullable String wlanIp,
               boolean linkUp, boolean addressOk, boolean routeOk, boolean pingOk,
               boolean flushed, @Nullable String eth0Ipv4) {
            this.cameraHost = cameraHost;
            this.tabletIp = tabletIp;
            this.wlanIp = wlanIp;
            this.linkUp = linkUp;
            this.addressOk = addressOk;
            this.routeOk = routeOk;
            this.pingOk = pingOk;
            this.flushed = flushed;
            this.eth0Ipv4 = eth0Ipv4;
        }

        public boolean success() {
            return addressOk && (routeOk || pingOk);
        }
    }

    /**
     * Fast path: addressing, route, and camera ICMP are already good — skip {@code ip neigh flush}.
     */
    public static boolean isSegmentHealthy(@NonNull String cameraHost, @Nullable String wlanIp) {
        String tabletIp = CameraEth0AddressPlanner.pickTabletEth0Address(cameraHost, wlanIp);
        if (tabletIp == null) {
            return false;
        }
        String eth0Ipv4 = readEth0Ipv4Cidr();
        if (eth0Ipv4 == null || !eth0Ipv4.startsWith(tabletIp)) {
            return false;
        }
        if (!verifyRouteUsesEth0(cameraHost)) {
            return false;
        }
        return ShellCmdUtil.isCameraHostPingReachable(cameraHost);
    }

    @NonNull
    public static Result configure(@NonNull String cameraHost, @Nullable String wlanIp)
            throws IOException, InterruptedException {
        CameraRoutePolicy policy = CameraRoutePolicyResolver.resolve(wlanIp, cameraHost);
        return configure(cameraHost, wlanIp, policy);
    }

    /**
     * @param cameraHost {@link CameraConfig#getCameraIp()}
     * @param wlanIp     current Wi-Fi IPv4 or null
     */
    @NonNull
    public static Result configure(
            @NonNull String cameraHost,
            @Nullable String wlanIp,
            @NonNull CameraRoutePolicy routePolicy)
            throws IOException, InterruptedException {
        String tabletIp = CameraEth0AddressPlanner.pickTabletEth0Address(cameraHost, wlanIp);
        String lanCidr = CameraEth0AddressPlanner.lanCidr(cameraHost);
        String broadcast = broadcastFor(cameraHost);
        if (tabletIp == null || lanCidr == null || broadcast == null) {
            return new Result(cameraHost, "", wlanIp, false, false, false, false, false, null);
        }
        String ipCidrWithBrd = tabletIp + "/24 broadcast " + broadcast + " dev " + IFACE;

        boolean linkUp = run("ip link set " + IFACE + " up");
        run("ip neigh flush dev " + IFACE);

        boolean flushed = false;
        boolean addressOk = run("ip addr replace " + ipCidrWithBrd);
        if (!addressOk) {
            flushed = run("ip addr flush dev " + IFACE);
            addressOk = run("ip addr add " + ipCidrWithBrd);
            if (!addressOk) {
                addressOk = run("ip addr replace " + ipCidrWithBrd);
            }
        }

        if (addressOk) {
            Thread.sleep(POST_ADDR_SETTLE_MS);
        }

        boolean routeOk = false;
        if (addressOk) {
            routeOk = applyCameraRouteWithRetries(cameraHost, lanCidr, tabletIp, routePolicy);
        }

        boolean pingOk = false;
        if (addressOk) {
            pingOk = run("ping -I " + IFACE + " -c 1 -W 2 " + cameraHost);
            if (pingOk && !routeOk) {
                routeOk = true;
            }
        }

        String eth0Ipv4 = readEth0Ipv4Cidr();
        return new Result(cameraHost, tabletIp, wlanIp, linkUp, addressOk, routeOk, pingOk,
                flushed, eth0Ipv4);
    }

    @Nullable
    private static String broadcastFor(@NonNull String cameraHost) {
        String prefix = CameraEth0AddressPlanner.subnetPrefix(cameraHost);
        return prefix == null ? null : prefix + ".255";
    }

    private static boolean applyCameraRouteWithRetries(
            @NonNull String cameraHost,
            @NonNull String lanCidr,
            @NonNull String tabletIp,
            @NonNull CameraRoutePolicy routePolicy) throws InterruptedException {
        List<String> commands = buildRouteCommands(lanCidr, tabletIp, cameraHost, routePolicy);
        for (int attempt = 0; attempt < ROUTE_ATTEMPTS; attempt++) {
            if (attempt > 0) {
                Thread.sleep(ROUTE_RETRY_DELAY_MS);
            }
            run("ip route del " + lanCidr + " dev " + IFACE);
            run("ip route del " + cameraHost + "/32 dev " + IFACE);
            for (String cmd : commands) {
                if (run(cmd)) {
                    if (verifyRouteUsesEth0(cameraHost)) {
                        return true;
                    }
                }
            }
        }
        return verifyRouteUsesEth0(cameraHost);
    }

    @VisibleForTesting
    @NonNull
    static List<String> buildRouteCommands(
            @NonNull String lanCidr,
            @NonNull String tabletIp,
            @NonNull String cameraHost) {
        return buildRouteCommands(
                lanCidr, tabletIp, cameraHost, CameraRoutePolicy.CAMERA_SUBNET_ROUTE);
    }

    @VisibleForTesting
    @NonNull
    static List<String> buildRouteCommands(
            @NonNull String lanCidr,
            @NonNull String tabletIp,
            @NonNull String cameraHost,
            @NonNull CameraRoutePolicy routePolicy) {
        if (routePolicy == CameraRoutePolicy.CAMERA_HOST_ROUTE) {
            return Arrays.asList(
                    "ip route replace " + cameraHost + "/32 dev " + IFACE + " src " + tabletIp,
                    "ip route replace " + cameraHost + "/32 dev " + IFACE);
        }
        return Arrays.asList(
                "ip route replace " + lanCidr + " dev " + IFACE + " src " + tabletIp,
                "ip route replace " + lanCidr + " dev " + IFACE,
                "ip route add " + lanCidr + " dev " + IFACE + " proto static scope link",
                "ip route replace " + cameraHost + "/32 dev " + IFACE
        );
    }

    @Nullable
    public static String currentEth0Ipv4Host() {
        String cidr = readEth0Ipv4Cidr();
        if (cidr == null) {
            return null;
        }
        int slash = cidr.indexOf('/');
        return slash > 0 ? cidr.substring(0, slash) : cidr;
    }

    @VisibleForTesting
    static boolean verifyRouteUsesEth0(@NonNull String cameraHost) {
        return run("sh -c \"ip route get " + cameraHost + " 2>/dev/null | grep -q dev." + IFACE + "\"");
    }

    private static boolean run(@NonNull String command) {
        try {
            boolean ok = ShellCmdUtil.executeCmdAsRoot(command);
            if (!ok) {
                Log.d(TAG, "shell failed: " + command);
            }
            return ok;
        } catch (Throwable t) {
            Log.d(TAG, "shell error: " + command, t);
            return false;
        }
    }

    @Nullable
    private static String readEth0Ipv4Cidr() {
        try {
            Process process = Runtime.getRuntime().exec(new String[]{
                    "sh", "-c", "ip -4 addr show dev " + IFACE});
            if (!process.waitFor(2, TimeUnit.SECONDS)) {
                process.destroy();
                return null;
            }
            StringBuilder output = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (output.length() > 0) {
                        output.append('\n');
                    }
                    output.append(line);
                }
            }
            return parseEth0Ipv4Cidr(output.toString());
        } catch (Throwable t) {
            Log.d(TAG, "readEth0Ipv4Cidr failed", t);
            return null;
        }
    }

    @VisibleForTesting
    @Nullable
    static String parseEth0Ipv4Cidr(@Nullable String ipAddrShowOutput) {
        if (ipAddrShowOutput == null || ipAddrShowOutput.isEmpty()) {
            return null;
        }
        for (String line : ipAddrShowOutput.split("\n")) {
            String trimmed = line.trim();
            int inetIdx = trimmed.indexOf("inet ");
            if (inetIdx < 0 || trimmed.contains("inet6")) {
                continue;
            }
            String rest = trimmed.substring(inetIdx + 5).trim();
            int end = rest.indexOf(' ');
            String cidr = end > 0 ? rest.substring(0, end) : rest;
            if (cidr.contains(".") && cidr.contains("/")) {
                return cidr;
            }
            if (cidr.contains(".")) {
                return cidr + "/24";
            }
        }
        return null;
    }

    public static void logResult(@NonNull Result result) {
        String eth0Log = result.eth0Ipv4 != null ? result.eth0Ipv4 : "-";
        Log.i(TAG, String.format(Locale.US,
                "setCameraNetworkSegment camera=%s tablet=%s eth0=%s wlan=%s linkUp=%s addr=%s route=%s ping=%s flush=%s",
                result.cameraHost,
                result.tabletIp,
                eth0Log,
                result.wlanIp,
                result.linkUp,
                result.addressOk,
                result.routeOk,
                result.pingOk,
                result.flushed));
        if (result.eth0Ipv4 == null && result.addressOk) {
            Log.w(TAG, "setCameraNetworkSegment: addr commands ok but eth0 has no IPv4 in ip addr show");
        } else if (result.eth0Ipv4 != null && !result.eth0Ipv4.startsWith(result.tabletIp)) {
            Log.w(TAG, "setCameraNetworkSegment: eth0 IP mismatch tablet=" + result.tabletIp
                    + " eth0=" + result.eth0Ipv4);
        }
        if (result.addressOk && !result.success()) {
            Log.w(TAG, "setCameraNetworkSegment incomplete: L3 ok but camera not reachable on eth0"
                    + " (check cable, camera power, camera IP; many IPCs block ping)");
        }
    }
}
