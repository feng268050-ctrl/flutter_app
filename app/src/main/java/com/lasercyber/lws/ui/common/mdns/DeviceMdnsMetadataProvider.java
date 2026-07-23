package com.lasercyber.lws.ui.common.mdns;

import android.text.TextUtils;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.BuildConfig;
import com.lasercyber.lws.ui.common.device.DeviceIdentity;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/**
 * Produces and validates TXT metadata for DNS-SD advertisements.
 */
public final class DeviceMdnsMetadataProvider {
    private DeviceMdnsMetadataProvider() {
    }

    @NonNull
    public static Map<String, String> buildTxtRecord(@NonNull String model, @NonNull String systemVersion) {
        Map<String, String> txt = new LinkedHashMap<>();
        txt.put(DeviceMdnsContract.TXT_SN, DeviceIdentity.getDeviceSnSafely());
        txt.put(DeviceMdnsContract.TXT_MODEL, safe(model));
        txt.put(DeviceMdnsContract.TXT_SYSTEM_VERSION, safe(systemVersion));
        txt.put(DeviceMdnsContract.TXT_API_VER, DeviceMdnsContract.API_VERSION);
        txt.put(DeviceMdnsContract.TXT_CONNECT_PROTO, DeviceMdnsContract.CONNECT_PROTO_WS);
        return Collections.unmodifiableMap(txt);
    }

    /**
     * Validate required fields and value semantics before publish.
     */
    public static MdnsMetadataValidationResult validate(@NonNull Map<String, String> txtRecord) {
        Set<String> requiredKeys = DeviceMdnsContract.requiredTxtKeys();
        for (String key : requiredKeys) {
            String value = txtRecord.get(key);
            if (TextUtils.isEmpty(value)) {
                return MdnsMetadataValidationResult.invalid("Missing required TXT field: " + key);
            }
        }
        String sn = txtRecord.get(DeviceMdnsContract.TXT_SN);
        if (DeviceIdentity.UNKNOWN_SN.equals(sn)) {
            return MdnsMetadataValidationResult.invalid("Device identity unresolved: sn unknown");
        }
        String protocol = txtRecord.get(DeviceMdnsContract.TXT_CONNECT_PROTO);
        if (!DeviceMdnsContract.isSupportedProtocol(protocol)) {
            return MdnsMetadataValidationResult.invalid("Unsupported connect_proto: " + protocol);
        }
        return MdnsMetadataValidationResult.valid();
    }

    @NonNull
    public static String resolveServiceInstanceName(@NonNull String model) {
        String suffix = DeviceIdentity.getDeviceSnSafely();
        return safe(model) + "-" + suffix;
    }

    @NonNull
    private static String safe(String raw) {
        if (!TextUtils.isEmpty(raw)) {
            return raw.trim();
        }
        return BuildConfig.BUILD_TYPE;
    }

    public static final class MdnsMetadataValidationResult {
        private final boolean valid;
        private final String reason;

        private MdnsMetadataValidationResult(boolean valid, String reason) {
            this.valid = valid;
            this.reason = reason;
        }

        public static MdnsMetadataValidationResult valid() {
            return new MdnsMetadataValidationResult(true, "");
        }

        public static MdnsMetadataValidationResult invalid(String reason) {
            return new MdnsMetadataValidationResult(false, reason);
        }

        public boolean isValid() {
            return valid;
        }

        public String getReason() {
            return reason;
        }
    }
}
