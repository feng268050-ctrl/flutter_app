package com.lasercyber.lws.ui.common.config;

import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;

/**
 * Loads device model and optional SN from ROM-level config file.
 */
public final class DeviceModelConfig {
    private static final String TAG = LogTAGConstant.APPLICATION;
    private static final String MODEL_FILE_PATH = "/system/etc/model.properties";
    private static final String MODEL_KEY = "model";
    private static final String SN_KEY = "sn";
    private static final String CAMERA_IP_KEY = "camera_ip";
    private static final String HOST_IP_KEY = "host_ip";
    private static final String CAMERA_TYPE_KEY = "camera_type";
    private static final String FOCUS_SCALE_REF_KEY = "focus_scale_ref";
    private static final String CONTROL_CARD_COMM_ALARM_MODE_KEY = "control_card_comm_alarm_mode";
    private static final String DEFAULT_MODEL = "LaserCyber L1";
    private static final int DEFAULT_FOCUS_SCALE_REF = 0;

    private static volatile String cachedModel = DEFAULT_MODEL;
    /** null means sn key was absent or empty in the file. */
    private static volatile String cachedSn = null;
    /** null means camera_ip key was absent or empty in the file. */
    private static volatile String cachedCameraIp = null;
    /** null means host_ip key was absent or empty in the file. */
    private static volatile String cachedHostIp = null;
    private static volatile CameraType cachedCameraType = CameraType.BLUE_LIGHT;
    private static volatile int cachedFocusScaleRef = DEFAULT_FOCUS_SCALE_REF;
    private static volatile ControlCardCommAlarmMode cachedControlCardCommAlarmMode =
            ControlCardCommAlarmMode.SLIDE_WINDOW;
    private static volatile boolean loaded;

    private DeviceModelConfig() {
    }

    public static void preload() {
        ensureLoaded();
    }

    public static String getModel() {
        ensureLoaded();
        return cachedModel;
    }

    /** Returns the {@code sn} value from model.properties, or {@code null} if absent. */
    public static String getSn() {
        ensureLoaded();
        return cachedSn;
    }

    /** Returns the {@code camera_ip} value from model.properties, or {@code null} if absent. */
    public static String getCameraIp() {
        ensureLoaded();
        return cachedCameraIp;
    }

    /** Returns the {@code host_ip} value from model.properties, or {@code null} if absent. */
    public static String getHostIp() {
        ensureLoaded();
        return cachedHostIp;
    }

    /** Returns camera modality from {@code camera_type}; defaults to {@link CameraType#BLUE_LIGHT}. */
    public static CameraType getCameraType() {
        ensureLoaded();
        return cachedCameraType;
    }

    /** Returns gun-head focus scale reference from {@code focus_scale_ref}; defaults to {@code 0}. */
    public static int getFocusScaleRef() {
        ensureLoaded();
        return cachedFocusScaleRef;
    }

    /**
     * Returns C001 detection mode from {@code control_card_comm_alarm_mode};
     * defaults to {@link ControlCardCommAlarmMode#SLIDE_WINDOW}.
     */
    public static ControlCardCommAlarmMode getControlCardCommAlarmMode() {
        ensureLoaded();
        return cachedControlCardCommAlarmMode;
    }

    static int parseFocusScaleRefProperty(String raw) {
        if (raw == null || raw.trim().isEmpty()) {
            return DEFAULT_FOCUS_SCALE_REF;
        }
        try {
            return Integer.parseInt(raw.trim());
        } catch (NumberFormatException ignored) {
            // fall through to default
        }
        Log.w(TAG, "invalid focus_scale_ref in " + MODEL_FILE_PATH + ": " + raw + ", fallback to "
                + DEFAULT_FOCUS_SCALE_REF);
        return DEFAULT_FOCUS_SCALE_REF;
    }

    static CameraType parseCameraTypeProperty(String raw) {
        if (raw == null || raw.trim().isEmpty()) {
            return CameraType.BLUE_LIGHT;
        }
        try {
            int value = Integer.parseInt(raw.trim());
            if (value == CameraType.RED_LIGHT.getValue()) {
                return CameraType.RED_LIGHT;
            }
            if (value == CameraType.BLUE_LIGHT.getValue()) {
                return CameraType.BLUE_LIGHT;
            }
        } catch (NumberFormatException ignored) {
            // fall through to default
        }
        Log.w(TAG, "invalid camera_type in " + MODEL_FILE_PATH + ": " + raw + ", fallback to BLUE_LIGHT");
        return CameraType.BLUE_LIGHT;
    }

    static ControlCardCommAlarmMode parseControlCardCommAlarmModeProperty(String raw) {
        if (raw == null || raw.trim().isEmpty()) {
            return ControlCardCommAlarmMode.SLIDE_WINDOW;
        }
        String normalized = raw.trim().toLowerCase();
        for (ControlCardCommAlarmMode mode : ControlCardCommAlarmMode.values()) {
            if (mode.getPropertyValue().equals(normalized)) {
                return mode;
            }
        }
        Log.w(TAG, "invalid control_card_comm_alarm_mode in " + MODEL_FILE_PATH + ": " + raw
                + ", fallback to slide_window");
        return ControlCardCommAlarmMode.SLIDE_WINDOW;
    }

    private static void ensureLoaded() {
        if (!loaded) {
            synchronized (DeviceModelConfig.class) {
                if (!loaded) {
                    loadFromFile();
                    loaded = true;
                }
            }
        }
    }

    private static void loadFromFile() {
        File file = new File(MODEL_FILE_PATH);
        if (!file.isFile()) {
            Log.i(TAG, "device model config missing at " + MODEL_FILE_PATH + ", fallback model=" + DEFAULT_MODEL);
            cachedModel = DEFAULT_MODEL;
            cachedSn = null;
            cachedCameraIp = null;
            cachedHostIp = null;
            cachedCameraType = CameraType.BLUE_LIGHT;
            cachedFocusScaleRef = DEFAULT_FOCUS_SCALE_REF;
            cachedControlCardCommAlarmMode = ControlCardCommAlarmMode.SLIDE_WINDOW;
            return;
        }
        Properties properties = new Properties();
        try (FileInputStream inputStream = new FileInputStream(file)) {
            properties.load(inputStream);

            String model = properties.getProperty(MODEL_KEY);
            if (model == null || model.trim().isEmpty()) {
                Log.w(TAG, "device model key missing/empty in " + MODEL_FILE_PATH + ", fallback to default");
                cachedModel = DEFAULT_MODEL;
            } else {
                cachedModel = model.trim();
                Log.i(TAG, "device model loaded from " + MODEL_FILE_PATH + ": " + cachedModel);
            }

            String sn = properties.getProperty(SN_KEY);
            if (sn != null && !sn.trim().isEmpty()) {
                cachedSn = sn.trim();
                Log.i(TAG, "device SN loaded from " + MODEL_FILE_PATH + ": " + cachedSn);
            } else {
                cachedSn = null;
            }

            String cameraIp = properties.getProperty(CAMERA_IP_KEY);
            if (cameraIp != null && !cameraIp.trim().isEmpty()) {
                cachedCameraIp = cameraIp.trim();
                Log.i(TAG, "camera IP loaded from " + MODEL_FILE_PATH + ": " + cachedCameraIp);
            } else {
                cachedCameraIp = null;
            }

            String hostIp = properties.getProperty(HOST_IP_KEY);
            if (hostIp != null && !hostIp.trim().isEmpty()) {
                cachedHostIp = hostIp.trim();
                Log.i(TAG, "host IP loaded from " + MODEL_FILE_PATH + ": " + cachedHostIp);
            } else {
                cachedHostIp = null;
            }

            cachedCameraType = parseCameraTypeProperty(properties.getProperty(CAMERA_TYPE_KEY));
            Log.i(TAG, "camera type loaded from " + MODEL_FILE_PATH + ": " + cachedCameraType.name()
                    + " (" + cachedCameraType.getValue() + ")");

            cachedFocusScaleRef = parseFocusScaleRefProperty(properties.getProperty(FOCUS_SCALE_REF_KEY));
            Log.i(TAG, "focus scale ref loaded from " + MODEL_FILE_PATH + ": " + cachedFocusScaleRef);

            cachedControlCardCommAlarmMode = parseControlCardCommAlarmModeProperty(
                    properties.getProperty(CONTROL_CARD_COMM_ALARM_MODE_KEY));
            Log.i(TAG, "control card comm alarm mode loaded from " + MODEL_FILE_PATH + ": "
                    + cachedControlCardCommAlarmMode.getPropertyValue());
        } catch (IOException e) {
            Log.e(TAG, "failed to load device model config from " + MODEL_FILE_PATH + ", fallback to default", e);
            cachedModel = DEFAULT_MODEL;
            cachedSn = null;
            cachedCameraIp = null;
            cachedHostIp = null;
            cachedCameraType = CameraType.BLUE_LIGHT;
            cachedFocusScaleRef = DEFAULT_FOCUS_SCALE_REF;
            cachedControlCardCommAlarmMode = ControlCardCommAlarmMode.SLIDE_WINDOW;
        }
    }
}
