package com.lasercyber.lws.ui.common.network.wifi;

import android.net.wifi.WifiConfiguration;
import android.util.Log;

import androidx.annotation.NonNull;

import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.util.ArrayList;
import java.util.List;

/**
 * Applies DHCP / STATIC IP to {@link WifiConfiguration} via reflection (hidden framework APIs).
 */
public final class WifiIpConfigApplier {

    private static final String TAG = "WifiIpConfigApplier";

    public static final class ApplyResult {
        public final boolean success;
        @NonNull
        public final String reason;

        private ApplyResult(boolean success, @NonNull String reason) {
            this.success = success;
            this.reason = reason;
        }

        public static ApplyResult ok() {
            return new ApplyResult(true, "ok");
        }

        public static ApplyResult fail(@NonNull String reason) {
            return new ApplyResult(false, reason);
        }
    }

    private WifiIpConfigApplier() {
    }

    public static boolean isSupported() {
        try {
            Class.forName("android.net.IpConfiguration");
            return true;
        } catch (ClassNotFoundException e) {
            return false;
        }
    }

    @NonNull
    public static ApplyResult applyDhcp(@NonNull WifiConfiguration config) {
        try {
            Object ipConfiguration = newIpConfiguration();
            setIpAssignment(ipConfiguration, "DHCP");
            setStaticIpConfiguration(ipConfiguration, null);
            attachIpConfiguration(config, ipConfiguration);
            return ApplyResult.ok();
        } catch (Throwable t) {
            Log.w(TAG, "applyDhcp failed", t);
            return ApplyResult.fail("dhcp_apply_failed:" + t.getClass().getSimpleName());
        }
    }

    @NonNull
    public static ApplyResult applyStatic(
            @NonNull WifiConfiguration config,
            @NonNull WifiIpConfig ipConfig) {
        if (ipConfig.mode != WifiIpConfig.Mode.STATIC) {
            return ApplyResult.fail("not_static");
        }
        WifiIpConfigValidator.Result validation =
                WifiIpConfigValidator.validate(ipConfig, null);
        if (!validation.valid) {
            return ApplyResult.fail(validation.reason != null ? validation.reason : "invalid");
        }
        try {
            Inet4Address ip = (Inet4Address) InetAddress.getByName(ipConfig.ip);
            Inet4Address gateway = (Inet4Address) InetAddress.getByName(ipConfig.gateway);
            List<InetAddress> dns = new ArrayList<>();
            if (ipConfig.dns1 != null && !ipConfig.dns1.isEmpty()) {
                dns.add(InetAddress.getByName(ipConfig.dns1));
            } else if (ipConfig.dns2 != null && !ipConfig.dns2.isEmpty()) {
                dns.add(InetAddress.getByName(ipConfig.dns2));
            }
            if (ipConfig.dns1 != null && !ipConfig.dns1.isEmpty()
                    && ipConfig.dns2 != null && !ipConfig.dns2.isEmpty()
                    && !ipConfig.dns1.equals(ipConfig.dns2)) {
                dns.add(InetAddress.getByName(ipConfig.dns2));
            }
            Object staticIp = newStaticIpConfiguration(ip, ipConfig.prefixLength, gateway, dns);
            Object ipConfiguration = newIpConfiguration();
            setIpAssignment(ipConfiguration, "STATIC");
            setStaticIpConfiguration(ipConfiguration, staticIp);
            attachIpConfiguration(config, ipConfiguration);
            return ApplyResult.ok();
        } catch (Throwable t) {
            Log.w(TAG, "applyStatic failed", t);
            return ApplyResult.fail("static_apply_failed:" + t.getClass().getSimpleName());
        }
    }

    private static Object newIpConfiguration() throws ReflectiveOperationException {
        Class<?> clazz = Class.forName("android.net.IpConfiguration");
        Constructor<?> ctor = clazz.getDeclaredConstructor();
        ctor.setAccessible(true);
        return ctor.newInstance();
    }

    private static void setIpAssignment(Object ipConfiguration, String assignmentName)
            throws ReflectiveOperationException {
        Class<?> ipConfigClass = Class.forName("android.net.IpConfiguration");
        Class<?> assignmentClass = Class.forName("android.net.IpConfiguration$IpAssignment");
        Object assignment = Enum.valueOf((Class<Enum>) assignmentClass, assignmentName);
        Method setter = ipConfigClass.getMethod("setIpAssignment", assignmentClass);
        setter.invoke(ipConfiguration, assignment);
    }

    private static void setStaticIpConfiguration(Object ipConfiguration, Object staticIp)
            throws ReflectiveOperationException {
        Class<?> ipConfigClass = Class.forName("android.net.IpConfiguration");
        Class<?> staticClass = Class.forName("android.net.StaticIpConfiguration");
        Method setter = ipConfigClass.getMethod("setStaticIpConfiguration", staticClass);
        setter.invoke(ipConfiguration, staticIp);
    }

    private static void attachIpConfiguration(WifiConfiguration config, Object ipConfiguration)
            throws ReflectiveOperationException {
        try {
            Method setter = WifiConfiguration.class.getMethod(
                    "setIpConfiguration", Class.forName("android.net.IpConfiguration"));
            setter.invoke(config, ipConfiguration);
            return;
        } catch (NoSuchMethodException ignored) {
            // fall through
        }
        Field field = WifiConfiguration.class.getField("ipConfiguration");
        field.set(config, ipConfiguration);
    }

    private static Object newStaticIpConfiguration(
            Inet4Address ip,
            int prefixLength,
            Inet4Address gateway,
            List<InetAddress> dns) throws ReflectiveOperationException {
        Class<?> staticClass = Class.forName("android.net.StaticIpConfiguration");
        Object builder;
        try {
            Class<?> builderClass = Class.forName("android.net.StaticIpConfiguration$Builder");
            builder = builderClass.getConstructor().newInstance();
            Object linkAddress = newLinkAddress(ip, prefixLength);
            invokeBuilder(builder, "setIpAddress", linkAddress);
            invokeBuilder(builder, "setGateway", gateway);
            invokeBuilder(builder, "setDnsServers", dns);
            Method build = builderClass.getMethod("build");
            return build.invoke(builder);
        } catch (ClassNotFoundException | NoSuchMethodException e) {
            Object staticIp = staticClass.getConstructor().newInstance();
            setField(staticIp, "ipAddress", newLinkAddress(ip, prefixLength));
            setField(staticIp, "gateway", gateway);
            setField(staticIp, "dnsServers", dns);
            return staticIp;
        }
    }

    private static void invokeBuilder(Object builder, String method, Object arg)
            throws ReflectiveOperationException {
        for (Method m : builder.getClass().getMethods()) {
            if (m.getName().equals(method) && m.getParameterTypes().length == 1) {
                m.invoke(builder, arg);
                return;
            }
        }
        throw new NoSuchMethodException(method);
    }

    private static Object newLinkAddress(Inet4Address ip, int prefixLength)
            throws ReflectiveOperationException {
        Class<?> linkClass = Class.forName("android.net.LinkAddress");
        try {
            Constructor<?> ctor = linkClass.getConstructor(InetAddress.class, int.class);
            return ctor.newInstance(ip, prefixLength);
        } catch (NoSuchMethodException e) {
            Object link = linkClass.getConstructor().newInstance();
            setField(link, "address", ip);
            setField(link, "prefixLength", prefixLength);
            return link;
        }
    }

    private static void setField(Object target, String name, Object value)
            throws ReflectiveOperationException {
        Field field = target.getClass().getDeclaredField(name);
        field.setAccessible(true);
        field.set(target, value);
    }
}
