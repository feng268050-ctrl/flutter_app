package com.lasercyber.lws.ui.common.utils;

import android.annotation.SuppressLint;
import android.content.Context;
import android.net.ConnectivityManager;
import android.net.DhcpInfo;
import android.net.LinkAddress;
import android.net.LinkProperties;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.wifi.ScanResult;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.text.TextUtils;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.entity.dto.ConnectedWifiInfo;
import com.lasercyber.lws.ui.common.network.wifi.WifiAssociationSnapshot;
import com.lasercyber.lws.ui.common.network.wifi.WifiIpConfig;
import com.lasercyber.lws.ui.common.network.wifi.WifiLinkSnapshot;
import com.lasercyber.lws.ui.common.network.wifi.WifiNetworkProfileStore;
import com.lasercyber.lws.ui.common.network.wifi.WifiSubnetUtils;

import java.util.ArrayList;
import java.util.List;

public class WifiStatusUtils {
    private static final String UNKNOWN_SSID = "<unknown ssid>";
    private static final String MASKED_MAC = "02:00:00:00:00:00";

    /**
     * Stricter than {@link #isWifiConnected(Context)} for onboarding: requires a usable SSID and LAN IP.
     */
    @Nullable
    public static ConnectedWifiInfo getUsableWifiConnection(@Nullable Context context) {
        return getConnectedWifiInfo(context);
    }

    public static boolean hasUsableWifiConnection(@Nullable Context context) {
        return getLinkSnapshot(context).l3Ready;
    }

    public static boolean isWifiAssociated(@Nullable Context context) {
        return getAssociationSnapshot(context).associated;
    }

    public static boolean isWifiL3Ready(@Nullable Context context) {
        return getLinkSnapshot(context).l3Ready;
    }

    @NonNull
    public static WifiAssociationSnapshot getAssociationSnapshot(@Nullable Context context) {
        if (context == null) {
            return new WifiAssociationSnapshot(null, null, null, null, null, null, false);
        }
        WifiManager wifiManager = (WifiManager) context.getApplicationContext()
                .getSystemService(Context.WIFI_SERVICE);
        if (wifiManager == null) {
            return new WifiAssociationSnapshot(null, null, null, null, null, null, false);
        }
        WifiInfo wifiInfo = wifiManager.getConnectionInfo();
        if (wifiInfo == null) {
            return new WifiAssociationSnapshot(null, null, null, null, null, null, false);
        }
        String ssid = normalizeSsid(wifiInfo.getSSID());
        if (TextUtils.isEmpty(ssid) || UNKNOWN_SSID.equals(ssid)) {
            return new WifiAssociationSnapshot(null, null, null, null, null, null, false);
        }
        String bssid = emptyToNull(wifiInfo.getBSSID());
        String capabilities = resolveSecurityCapabilitiesFromScan(wifiManager, ssid, bssid);
        Integer rssi = wifiInfo.getRssi();
        int frequency = wifiInfo.getFrequency();
        return new WifiAssociationSnapshot(
                ssid,
                bssid,
                deriveSecurityType(capabilities),
                capabilities,
                rssi,
                frequency > 0 ? frequency : null,
                true);
    }

    @NonNull
    public static WifiLinkSnapshot getLinkSnapshot(@Nullable Context context) {
        if (context == null) {
            return emptyLinkSnapshot();
        }
        ConnectivityManager cm = (ConnectivityManager)
                context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) {
            return emptyLinkSnapshot();
        }
        Network network = cm.getActiveNetwork();
        if (network == null) {
            return emptyLinkSnapshot();
        }
        NetworkCapabilities caps = cm.getNetworkCapabilities(network);
        if (caps == null || !caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
            return emptyLinkSnapshot();
        }
        LinkProperties lp = cm.getLinkProperties(network);
        if (lp == null) {
            return emptyLinkSnapshot();
        }
        String ipv4 = null;
        int prefix = 0;
        for (LinkAddress la : lp.getLinkAddresses()) {
            if (la == null || la.getAddress() == null) {
                continue;
            }
            byte[] bytes = la.getAddress().getAddress();
            if (bytes == null || bytes.length != 4) {
                continue;
            }
            ipv4 = formatIpAddress(toIpv4Int(bytes));
            prefix = la.getPrefixLength();
            break;
        }
        if (ipv4 == null) {
            return emptyLinkSnapshot();
        }
        String gateway = null;
        if (lp.getRoutes() != null) {
            for (android.net.RouteInfo route : lp.getRoutes()) {
                if (route != null && route.isDefaultRoute() && route.getGateway() != null) {
                    gateway = route.getGateway().getHostAddress();
                    break;
                }
            }
        }
        List<String> dns = new ArrayList<>();
        if (lp.getDnsServers() != null) {
            for (java.net.InetAddress addr : lp.getDnsServers()) {
                if (addr != null) {
                    dns.add(addr.getHostAddress());
                }
            }
        }
        return new WifiLinkSnapshot(
                ipv4,
                prefix,
                WifiSubnetUtils.prefixLengthToMask(prefix),
                gateway,
                dns,
                true);
    }

    @Nullable
    public static WifiIpConfig.Mode getConfiguredIpMode(
            @Nullable Context context,
            @NonNull String ssid,
            @NonNull String securityType) {
        if (context == null) {
            return WifiIpConfig.Mode.DHCP;
        }
        WifiIpConfig config = new WifiNetworkProfileStore(context)
                .getIpConfigOrDhcp(ssid, securityType);
        return config.mode;
    }

    @NonNull
    private static WifiLinkSnapshot emptyLinkSnapshot() {
        return new WifiLinkSnapshot(null, 0, null, null, null, false);
    }

    /**
     * 判断当前设备是否已连接 WiFi（核心方法）
     * @param context 上下文（建议用 Application Context 避免内存泄漏）
     * @return true=已连接 WiFi；false=未连接/无WiFi/无网络
     */
    public static boolean isWifiConnected(Context context) {
        if (context == null) {
            return false;
        }

        ConnectivityManager connectivityManager = (ConnectivityManager)
                context.getSystemService(Context.CONNECTIVITY_SERVICE);

        if (connectivityManager == null) {
            return false;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Network network = connectivityManager.getActiveNetwork();
            if (network == null) {
                return false;
            }
            NetworkCapabilities capabilities = connectivityManager.getNetworkCapabilities(network);
            return capabilities != null
                    && capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
                    && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
        } else {
            android.net.NetworkInfo networkInfo = connectivityManager.getNetworkInfo(ConnectivityManager.TYPE_WIFI);
            return networkInfo != null && networkInfo.isConnected();
        }
    }

    /**
     * Same formatting as Settings → Network → Wireless Network → Wi-Fi details
     * ({@link com.lasercyber.lws.ui.activitys.other.WifiDetailsActivity}).
     */
    public static String formatIpAddress(int ipAddress) {
        return (ipAddress & 0xFF) + "."
                + ((ipAddress >> 8) & 0xFF) + "."
                + ((ipAddress >> 16) & 0xFF) + "."
                + ((ipAddress >> 24) & 0xFF);
    }

    /**
     * Full connected Wi-Fi snapshot (same sources as Wi-Fi details screen), or {@code null} when
     * not connected / no usable LAN IP.
     */
    @SuppressLint("MissingPermission")
    @Nullable
    public static ConnectedWifiInfo getConnectedWifiInfo(@Nullable Context context) {
        if (context == null || !isWifiConnected(context)) {
            return null;
        }
        WifiManager wifiManager = (WifiManager) context.getApplicationContext()
                .getSystemService(Context.WIFI_SERVICE);
        if (wifiManager == null) {
            return null;
        }
        WifiInfo wifiInfo = wifiManager.getConnectionInfo();
        if (wifiInfo == null) {
            return null;
        }
        String ssid = normalizeSsid(wifiInfo.getSSID());
        if (TextUtils.isEmpty(ssid) || UNKNOWN_SSID.equals(ssid)) {
            return null;
        }
        int ipAddressRaw = wifiInfo.getIpAddress();
        if (ipAddressRaw == 0) {
            return null;
        }

        DhcpInfo dhcpInfo = wifiManager.getDhcpInfo();
        int netmask = dhcpInfo == null ? 0 : dhcpInfo.netmask;
        if (netmask == 0) {
            netmask = resolveSubnetMaskFromLinkProperties(context, ipAddressRaw);
        }
        int gateway = dhcpInfo == null ? 0 : dhcpInfo.gateway;
        int dns1 = dhcpInfo == null ? 0 : dhcpInfo.dns1;

        String bssid = emptyToNull(wifiInfo.getBSSID());
        String capabilities = resolveSecurityCapabilitiesFromScan(wifiManager, ssid, bssid);

        ConnectedWifiInfo out = new ConnectedWifiInfo();
        out.setSsid(ssid);
        out.setBssid(bssid);
        out.setCapabilities(emptyToNull(capabilities));
        out.setIpAddress(formatIpAddress(ipAddressRaw));
        out.setSubnetMask(formatIpOrNull(netmask));
        out.setRouter(formatIpOrNull(gateway));
        out.setDns(formatIpOrNull(dns1));
        out.setRssi(wifiInfo.getRssi());
        int linkSpeed = wifiInfo.getLinkSpeed();
        out.setLinkSpeed(linkSpeed > 0 ? linkSpeed : null);
        int frequency = wifiInfo.getFrequency();
        out.setFrequency(frequency > 0 ? frequency : null);
        out.setSecurityType(deriveSecurityType(capabilities));
        out.setMacAddress(formatMacOrNull(wifiInfo.getMacAddress()));
        return out;
    }

    public static String deriveSecurityType(@Nullable String capabilities) {
        if (capabilities == null || capabilities.isEmpty()) {
            return null;
        }
        if (capabilities.contains("WPA3")) {
            return "WPA3";
        }
        if (capabilities.contains("WPA2")) {
            return "WPA2";
        }
        if (capabilities.contains("WPA")) {
            return "WPA";
        }
        if (capabilities.contains("WEP")) {
            return "WEP";
        }
        return "Open";
    }

    @SuppressLint("MissingPermission")
    @Nullable
    static String resolveSecurityCapabilitiesFromScan(
            WifiManager wifiManager, String ssid, @Nullable String bssid) {
        if (wifiManager == null || TextUtils.isEmpty(ssid)) {
            return null;
        }
        List<ScanResult> scanResults = wifiManager.getScanResults();
        if (scanResults == null || scanResults.isEmpty()) {
            return null;
        }
        for (ScanResult result : scanResults) {
            if (result == null) {
                continue;
            }
            String scanSsid = normalizeSsid(result.SSID);
            if (!TextUtils.equals(scanSsid, ssid)) {
                continue;
            }
            if (!TextUtils.isEmpty(bssid) && !TextUtils.equals(result.BSSID, bssid)) {
                continue;
            }
            return emptyToNull(result.capabilities);
        }
        return null;
    }

    @Nullable
    static String formatIpOrNull(int value) {
        if (value == 0) {
            return null;
        }
        return formatIpAddress(value);
    }

    @SuppressLint("HardwareIds")
    @Nullable
    static String formatMacOrNull(@Nullable String mac) {
        if (mac == null || mac.isEmpty() || MASKED_MAC.equals(mac)) {
            return null;
        }
        return mac;
    }

    static String normalizeSsid(@Nullable String raw) {
        if (raw == null) {
            return "";
        }
        return raw.replace("\"", "");
    }

    @Nullable
    private static String emptyToNull(@Nullable String value) {
        return TextUtils.isEmpty(value) ? null : value;
    }

    private static int resolveSubnetMaskFromLinkProperties(Context context, int ipAddress) {
        ConnectivityManager connectivityManager =
                (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (connectivityManager == null) {
            return 0;
        }
        Network activeNetwork = connectivityManager.getActiveNetwork();
        if (activeNetwork == null) {
            return 0;
        }
        NetworkCapabilities networkCapabilities =
                connectivityManager.getNetworkCapabilities(activeNetwork);
        if (networkCapabilities == null
                || !networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
            return 0;
        }
        LinkProperties linkProperties = connectivityManager.getLinkProperties(activeNetwork);
        if (linkProperties == null) {
            return 0;
        }
        for (LinkAddress linkAddress : linkProperties.getLinkAddresses()) {
            if (linkAddress == null || linkAddress.getAddress() == null) {
                continue;
            }
            byte[] addressBytes = linkAddress.getAddress().getAddress();
            if (addressBytes == null || addressBytes.length != 4) {
                continue;
            }
            int currentIp = toIpv4Int(addressBytes);
            if (currentIp != ipAddress) {
                continue;
            }
            return prefixLengthToMask(linkAddress.getPrefixLength());
        }
        return 0;
    }

    private static int toIpv4Int(byte[] addressBytes) {
        return (addressBytes[0] & 0xFF)
                | ((addressBytes[1] & 0xFF) << 8)
                | ((addressBytes[2] & 0xFF) << 16)
                | ((addressBytes[3] & 0xFF) << 24);
    }

    private static int prefixLengthToMask(int prefixLength) {
        if (prefixLength <= 0) {
            return 0;
        }
        if (prefixLength >= 32) {
            return 0xFFFFFFFF;
        }
        int bigEndianMask = (int) (0xFFFFFFFFL << (32 - prefixLength));
        return Integer.reverseBytes(bigEndianMask);
    }
}
