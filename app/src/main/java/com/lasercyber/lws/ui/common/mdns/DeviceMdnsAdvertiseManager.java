package com.lasercyber.lws.ui.common.mdns;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.LinkAddress;
import android.net.LinkProperties;
import android.net.Network;
import android.net.wifi.WifiManager;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.IOException;
import java.net.Inet4Address;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import javax.jmdns.JmDNS;
import javax.jmdns.ServiceInfo;

/**
 * Device-side DNS-SD advertiser using JmDNS (multicast on the Wi-Fi IPv4 address).
 * <p>
 * On several OEM stacks (including some Rockchip builds), {@link android.net.nsd.NsdManager} reports
 * {@code onServiceRegistered} but does not emit mDNS packets visible to Bonjour/Discovery.
 * JmDNS sends standard mDNS from the app process and is easier to verify on the LAN.
 */
public final class DeviceMdnsAdvertiseManager {
    private static final String TAG = LogTAGConstant.DEVICE_MDNS;
    private static final DeviceMdnsAdvertiseManager INSTANCE = new DeviceMdnsAdvertiseManager();

    private final AtomicBoolean initialized = new AtomicBoolean(false);
    private final AtomicBoolean networkReady = new AtomicBoolean(false);
    private final AtomicBoolean endpointHealthy = new AtomicBoolean(false);

    private Context appContext;
    private volatile boolean advertising;
    private volatile boolean registrationInFlight;
    private volatile String lastPublishFingerprint;
    @Nullable
    private volatile Network activeWifiNetwork;
    @Nullable
    private WifiManager.MulticastLock multicastLock;
    @Nullable
    private JmDNS jmdns;
    @Nullable
    private ServiceInfo registeredService;

    private DeviceMdnsAdvertiseManager() {
    }

    public static DeviceMdnsAdvertiseManager getInstance() {
        return INSTANCE;
    }

    /**
     * Current Wi-Fi {@link Network} from {@link DeviceMdnsWifiNetworkCallback}; used to resolve IPv4 for JmDNS.
     */
    public void setActiveWifiNetwork(@Nullable Network network) {
        activeWifiNetwork = network;
    }

    public synchronized void start(@NonNull Context context) {
        if (initialized.get()) {
            return;
        }
        appContext = context.getApplicationContext();
        initialized.set(true);
        endpointHealthy.set(true);
        updatePublishState("startup");
    }

    public void onNetworkAvailable() {
        networkReady.set(true);
        updatePublishState("network_available");
    }

    public void onNetworkLost() {
        networkReady.set(false);
        updatePublishState("network_lost");
    }

    public void onConnectionServiceHealthChanged(boolean healthy, String reason) {
        endpointHealthy.set(healthy);
        updatePublishState(reason == null ? "service_health_changed" : reason);
    }

    public synchronized void stop() {
        unregister("shutdown");
        releaseMulticastLockSafely();
        initialized.set(false);
        appContext = null;
        activeWifiNetwork = null;
    }

    private synchronized void updatePublishState(String reason) {
        if (!initialized.get() || appContext == null) {
            return;
        }
        boolean shouldAdvertise = networkReady.get() && endpointHealthy.get();
        if (shouldAdvertise) {
            registerOrRepublish(reason);
            return;
        }
        unregister(reason);
    }

    @NonNull
    private String resolveInstalledVersionName() {
        if (appContext == null) {
            return BuildConfig.VERSION_NAME != null ? BuildConfig.VERSION_NAME : "";
        }
        try {
            PackageInfo pi = appContext.getPackageManager()
                    .getPackageInfo(appContext.getPackageName(), 0);
            if (pi.versionName != null && !pi.versionName.isEmpty()) {
                return pi.versionName;
            }
        } catch (PackageManager.NameNotFoundException e) {
            Log.w(TAG, "resolveInstalledVersionName: package not found", e);
        }
        return BuildConfig.VERSION_NAME != null ? BuildConfig.VERSION_NAME : "";
    }

    private void registerOrRepublish(String reason) {
        if (appContext == null) {
            return;
        }
        String model = DeviceModelConfig.getModel();
        Map<String, String> txt = DeviceMdnsMetadataProvider.buildTxtRecord(model, resolveInstalledVersionName());
        DeviceMdnsMetadataProvider.MdnsMetadataValidationResult result =
                DeviceMdnsMetadataProvider.validate(txt);
        if (!result.isValid()) {
            Log.e(TAG, "skip mdns publish due to metadata validation: " + result.getReason());
            return;
        }

        Network network = activeWifiNetwork;
        if (network == null) {
            Log.e(TAG, "skip jmdns: no active Wi-Fi Network (wait for NetworkCallback)");
            return;
        }

        ConnectivityManager cm = (ConnectivityManager) appContext.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) {
            Log.e(TAG, "skip jmdns: ConnectivityManager null");
            return;
        }
        LinkProperties lp = cm.getLinkProperties(network);
        Inet4Address ipv4 = firstIpv4(lp);
        if (ipv4 == null) {
            Log.e(TAG, "skip jmdns: no IPv4 on Wi-Fi link yet (LinkProperties=" + lp + ")");
            return;
        }

        String instanceName = DeviceMdnsMetadataProvider.resolveServiceInstanceName(model);
        int port = DeviceMdnsContract.DEFAULT_CONNECT_PORT;
        String fingerprint = buildPublishFingerprint(instanceName, port, txt);
        if ((advertising || registrationInFlight) && fingerprint.equals(lastPublishFingerprint)) {
            Log.i(TAG, "skip jmdns register duplicate, reason=" + reason + ", fingerprint=" + fingerprint);
            return;
        }

        if (advertising || registrationInFlight || jmdns != null) {
            unregister("republish_" + reason);
        }

        lastPublishFingerprint = fingerprint;
        registrationInFlight = true;

        Log.i(TAG, "jmdns register request: name=" + instanceName
                + " type=" + DeviceMdnsContract.JMDNS_SERVICE_TYPE
                + " port=" + port
                + " hostIf=" + ipv4.getHostAddress()
                + " reason=" + reason);

        try {
            ensureMulticastLockForAdvertise();
            closeJmDnsWithoutClearingFingerprint();
            jmdns = JmDNS.create(ipv4);
            HashMap<String, String> props = new HashMap<>(txt);
            registeredService = ServiceInfo.create(
                    DeviceMdnsContract.JMDNS_SERVICE_TYPE,
                    instanceName,
                    port,
                    0,
                    0,
                    props);
            jmdns.registerService(registeredService);
            advertising = true;
            registrationInFlight = false;
            Log.i(TAG, "jmdns service registered (multicast from " + ipv4.getHostAddress() + ")");
        } catch (IOException e) {
            advertising = false;
            registrationInFlight = false;
            releaseMulticastLockSafely();
            closeJmDnsWithoutClearingFingerprint();
            lastPublishFingerprint = null;
            Log.e(TAG, "jmdns register failed", e);
        } catch (Throwable t) {
            advertising = false;
            registrationInFlight = false;
            releaseMulticastLockSafely();
            closeJmDnsWithoutClearingFingerprint();
            lastPublishFingerprint = null;
            Log.e(TAG, "jmdns register exception", t);
        }
    }

    @Nullable
    private static Inet4Address firstIpv4(@Nullable LinkProperties lp) {
        if (lp == null) {
            return null;
        }
        for (LinkAddress la : lp.getLinkAddresses()) {
            if (la == null || la.getAddress() == null) {
                continue;
            }
            if (la.getAddress() instanceof Inet4Address) {
                Inet4Address v4 = (Inet4Address) la.getAddress();
                if (!v4.isLoopbackAddress() && !v4.isLinkLocalAddress()) {
                    return v4;
                }
            }
        }
        for (LinkAddress la : lp.getLinkAddresses()) {
            if (la != null && la.getAddress() instanceof Inet4Address) {
                Inet4Address v4 = (Inet4Address) la.getAddress();
                if (!v4.isLoopbackAddress()) {
                    return v4;
                }
            }
        }
        return null;
    }

    private void unregister(String reason) {
        if (jmdns == null && !advertising) {
            return;
        }
        try {
            closeJmDnsWithoutClearingFingerprint();
            Log.i(TAG, "jmdns unregister/stop, reason=" + reason);
        } catch (Throwable t) {
            Log.w(TAG, "jmdns unregister exception, reason=" + reason, t);
        } finally {
            advertising = false;
            registrationInFlight = false;
            registeredService = null;
            lastPublishFingerprint = null;
            releaseMulticastLockSafely();
        }
    }

    private void closeJmDnsWithoutClearingFingerprint() {
        if (registeredService != null && jmdns != null) {
            try {
                jmdns.unregisterService(registeredService);
            } catch (Throwable t) {
                Log.w(TAG, "jmdns unregisterService", t);
            }
        }
        registeredService = null;
        if (jmdns != null) {
            try {
                jmdns.close();
            } catch (Throwable t) {
                Log.w(TAG, "jmdns close", t);
            }
            jmdns = null;
        }
    }

    private String buildPublishFingerprint(String instanceName, int port, Map<String, String> txt) {
        StringBuilder builder = new StringBuilder();
        builder.append(DeviceMdnsContract.JMDNS_SERVICE_TYPE).append('|')
                .append(instanceName).append('|')
                .append(port);
        for (Map.Entry<String, String> entry : txt.entrySet()) {
            builder.append('|').append(entry.getKey()).append('=').append(entry.getValue());
        }
        return builder.toString();
    }

    private void ensureMulticastLockForAdvertise() {
        if (appContext == null) {
            return;
        }
        try {
            if (multicastLock != null && multicastLock.isHeld()) {
                return;
            }
            WifiManager wifi = (WifiManager) appContext.getApplicationContext()
                    .getSystemService(Context.WIFI_SERVICE);
            if (wifi == null) {
                return;
            }
            multicastLock = wifi.createMulticastLock("lws-jmdns-advertise");
            multicastLock.setReferenceCounted(false);
            multicastLock.acquire();
            Log.i(TAG, "MulticastLock acquired for jmdns advertise");
        } catch (Throwable t) {
            Log.w(TAG, "MulticastLock acquire failed (jmdns may still work)", t);
        }
    }

    private void releaseMulticastLockSafely() {
        try {
            if (multicastLock != null) {
                if (multicastLock.isHeld()) {
                    multicastLock.release();
                }
                multicastLock = null;
                Log.i(TAG, "MulticastLock released");
            }
        } catch (Throwable t) {
            Log.w(TAG, "MulticastLock release failed", t);
            multicastLock = null;
        }
    }
}
