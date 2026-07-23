package com.lasercyber.lws.ui.common.network.wifi;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.network.CameraEth0AddressPlanner;

import java.util.Objects;

public final class WifiIpConfigValidator {

    public static final class Result {
        public final boolean valid;
        @Nullable
        public final String reason;

        private Result(boolean valid, @Nullable String reason) {
            this.valid = valid;
            this.reason = reason;
        }

        public static Result ok() {
            return new Result(true, null);
        }

        public static Result fail(@NonNull String reason) {
            return new Result(false, reason);
        }
    }

    private WifiIpConfigValidator() {
    }

    @NonNull
    public static Result validate(
            @NonNull WifiIpConfig config,
            @Nullable String currentEth0Ip) {
        if (config.mode == WifiIpConfig.Mode.DHCP) {
            return Result.ok();
        }
        if (config.ip == null || config.ip.isEmpty()) {
            return Result.fail("missing_ip");
        }
        if (WifiSubnetUtils.ipv4ToLong(config.ip) < 0) {
            return Result.fail("invalid_ip");
        }
        if (config.prefixLength <= 0 || config.prefixLength > 32) {
            return Result.fail("invalid_prefix");
        }
        if (config.gateway == null || config.gateway.isEmpty()) {
            return Result.fail("missing_gateway");
        }
        if (WifiSubnetUtils.ipv4ToLong(config.gateway) < 0) {
            return Result.fail("invalid_gateway");
        }
        String primaryDns = primaryDns(config);
        if (primaryDns == null || primaryDns.isEmpty()) {
            return Result.fail("missing_dns1");
        }
        if (WifiSubnetUtils.ipv4ToLong(primaryDns) < 0) {
            return Result.fail("invalid_dns1");
        }
        if (config.dns1 != null && !config.dns1.isEmpty()
                && config.dns2 != null && !config.dns2.isEmpty()
                && !config.dns1.equals(config.dns2)
                && WifiSubnetUtils.ipv4ToLong(config.dns2) < 0) {
            return Result.fail("invalid_dns2");
        }

        String network = WifiSubnetUtils.networkAddress(config.ip, config.prefixLength);
        String broadcast = WifiSubnetUtils.broadcastAddress(config.ip, config.prefixLength);
        if (Objects.equals(config.ip, network) || Objects.equals(config.ip, broadcast)) {
            return Result.fail("reserved_host_ip");
        }
        if (!WifiSubnetUtils.sameSubnet(config.ip, config.gateway, config.prefixLength)) {
            return Result.fail("gateway_not_in_subnet");
        }

        String cameraIp = CameraConfig.getCameraIp();
        if (Objects.equals(config.ip, cameraIp)) {
            return Result.fail("conflicts_with_camera_ip");
        }
        if (currentEth0Ip != null && Objects.equals(config.ip, currentEth0Ip)) {
            return Result.fail("conflicts_with_eth0_ip");
        }
        if (Objects.equals(config.gateway, cameraIp)) {
            return Result.fail("gateway_conflicts_with_camera");
        }
        return Result.ok();
    }

    @Nullable
    private static String primaryDns(@NonNull WifiIpConfig config) {
        if (config.dns1 != null && !config.dns1.isEmpty()) {
            return config.dns1;
        }
        return config.dns2;
    }

    @NonNull
    public static Result validateMaskOrPrefix(@Nullable String maskOrPrefix) {
        int prefix = WifiSubnetUtils.maskToPrefixLength(maskOrPrefix);
        return prefix > 0 ? Result.ok() : Result.fail("invalid_mask");
    }
}
