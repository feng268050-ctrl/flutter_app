package com.lasercyber.lws.ui.common.rx.modbus;

public final class ModbusStartupCapabilityDecider {

    private ModbusStartupCapabilityDecider() {
    }

    public static Decision decide(String buildFingerprint, String buildModel, boolean serialDeviceExists) {
        boolean emulator = isEmulator(buildFingerprint, buildModel);
        if (emulator && !serialDeviceExists) {
            return new Decision(true, ModbusStartupState.REASON_EMULATOR_UNSUPPORTED);
        }
        if (!serialDeviceExists) {
            return new Decision(true, ModbusStartupState.REASON_SERIAL_PORT_MISSING);
        }
        return new Decision(false, ModbusStartupState.REASON_NONE);
    }

    static boolean isEmulator(String buildFingerprint, String buildModel) {
        String fingerprint = buildFingerprint == null ? "" : buildFingerprint;
        String model = buildModel == null ? "" : buildModel;
        return fingerprint.contains("generic")
                || fingerprint.contains("emulator")
                || model.contains("Emulator")
                || model.contains("Android SDK built for");
    }

    public static final class Decision {
        private final boolean shouldSkip;
        private final String reasonCode;

        public Decision(boolean shouldSkip, String reasonCode) {
            this.shouldSkip = shouldSkip;
            this.reasonCode = reasonCode;
        }

        public boolean shouldSkip() {
            return shouldSkip;
        }

        public String reasonCode() {
            return reasonCode;
        }
    }
}
