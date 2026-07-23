package com.lasercyber.lws.ui.common.gpio;

import android.util.Log;

import com.innohi.YNHAPI;
import com.lasercyber.lws.ui.common.config.GpioLedConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.rx.modbus.task.AbstractRxModbusTask;
import com.lasercyber.lws.ui.common.rx.modbus.task.RxTaskManager;

import java.util.EnumMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Unified RGB side-panel indicator driver (YNHAPI GPIO).
 */
public final class LedIndicatorManager {

    static final int FLASH_ON_MS = 1000;
    static final int FLASH_OFF_MS = 1000;

    /**
     * Experimental Dev PWM: duty-cycle via GPIO on a dedicated thread.
     * Base 120 Hz; ramps up toward {@link #EXPERIMENTAL_PWM_MAX_FREQUENCY_HZ} when gamma duty is low.
     */
    public static final int EXPERIMENTAL_PWM_FREQUENCY_HZ = 120;
    public static final int EXPERIMENTAL_PWM_MAX_FREQUENCY_HZ = 400;
    public static final int EXPERIMENTAL_PWM_PERIOD_US = 1_000_000 / EXPERIMENTAL_PWM_FREQUENCY_HZ;
    /** Below this gamma-duty fraction, PWM frequency ramps up to reduce visible flicker when dim. */
    static final float EXPERIMENTAL_PWM_LOW_DUTY_THRESHOLD = 0.25f;
    /** Perceived-linear duty; 2.0 balances slider feel vs low-brightness flicker (with adaptive Hz). */
    public static final float EXPERIMENTAL_PWM_GAMMA = 2.0f;

    private static final String TAG = LogTAGConstant.LedIndicatorManager;
    private static final boolean isDebug = false;
    private static final String FLASH_TASK_PREFIX = "ledFlash:";
    /** GPIO HIGH when music-reactive level exceeds this (0–255). */
    static final int MUSIC_REACTIVE_ON_THRESHOLD = 28;
    private static final Map<LedColor, Thread> experimentalPwmThreads = new ConcurrentHashMap<>();
    private static volatile boolean musicReactiveActive = false;

    private static final YNHAPI mAPI;
    private static final EnumMap<LedColor, IndicatorMode> cachedModes = new EnumMap<>(LedColor.class);
    private static final EnumMap<LedColor, Integer> experimentalPwmBrightness = new EnumMap<>(LedColor.class);

    static {
        for (LedColor color : LedColor.values()) {
            cachedModes.put(color, IndicatorMode.OFF);
            experimentalPwmBrightness.put(color, 0);
        }
        cachedModes.put(LedColor.GREEN, IndicatorMode.STEADY_ON);

        YNHAPI api = null;
        if (GpioLedConfig.GPIO_ENABLE) {
            try {
                api = YNHAPI.getInstance();
            } catch (Throwable throwable) {
                Log.e(TAG, "GPIO init unavailable, running without YNHAPI", throwable);
            }
        }
        mAPI = api;
    }

    private LedIndicatorManager() {
    }

    private static boolean isApiReady() {
        return GpioLedConfig.GPIO_ENABLE && mAPI != null;
    }

    public static boolean isHardwareAvailable() {
        return isApiReady();
    }

    public static IndicatorMode getIndicatorMode(LedColor color) {
        synchronized (LedIndicatorManager.class) {
            return cachedModes.get(color);
        }
    }

    public static boolean isMusicReactiveActive() {
        return musicReactiveActive;
    }

    /**
     * Dev-only: take over RGB GPIO for music visualization (cancels flash / experimental PWM).
     */
    public static void enterMusicReactiveMode() {
        synchronized (LedIndicatorManager.class) {
            musicReactiveActive = true;
            if (!isApiReady()) {
                return;
            }
            for (LedColor color : LedColor.values()) {
                RxTaskManager.getInstance().cancelTask(flashTaskId(color));
                cancelExperimentalPwmLocked(color);
            }
        }
    }

    /**
     * Dev-only: release music visualization and turn all indicator GPIO LOW.
     */
    public static void leaveMusicReactiveMode() {
        synchronized (LedIndicatorManager.class) {
            musicReactiveActive = false;
            if (!isApiReady()) {
                return;
            }
            for (LedColor color : LedColor.values()) {
                mAPI.setGpioState(color.gpioPin(), YNHAPI.GpioState.LOW);
            }
        }
    }

    /**
     * Dev-only: vertical bar GPIO — bottom→top 绿/黄/红; [litSegments] 0=all off, 3=all on.
     */
    public static void setMusicReactiveBar(int litSegments) {
        if (!isApiReady() || !musicReactiveActive) {
            return;
        }
        synchronized (LedIndicatorManager.class) {
            if (!musicReactiveActive) {
                return;
            }
            applyMusicReactiveBarLocked(litSegments);
        }
    }

    /** @deprecated Use {@link #setMusicReactiveBar(int)} */
    public static void setMusicReactiveLevels(int red, int yellow, int green) {
        int segments = 0;
        if (green > MUSIC_REACTIVE_ON_THRESHOLD) {
            segments = 1;
        }
        if (yellow > MUSIC_REACTIVE_ON_THRESHOLD) {
            segments = 2;
        }
        if (red > MUSIC_REACTIVE_ON_THRESHOLD) {
            segments = 3;
        }
        setMusicReactiveBar(segments);
    }

    public static void setIndicator(LedColor color, IndicatorMode mode) {
        if (!isApiReady()) {
            return;
        }
        synchronized (LedIndicatorManager.class) {
            if (musicReactiveActive) {
                return;
            }
            IndicatorMode current = cachedModes.get(color);
            if (current == mode) {
                return;
            }
            cancelExperimentalPwmLocked(color);
            cachedModes.put(color, mode);
            applyHardwareLocked(color, mode);
        }
    }

    /**
     * Dev-only: simulate brightness with GPIO duty-cycle PWM (0 = off, 255 = steady HIGH).
     */
    public static int getExperimentalPwmFrequencyHz() {
        return EXPERIMENTAL_PWM_FREQUENCY_HZ;
    }

    public static int getExperimentalPwmFrequencyHz(int brightness) {
        return 1_000_000 / experimentalPwmPeriodUs(brightness);
    }

    public static void setExperimentalPwmBrightness(LedColor color, int brightness) {
        if (!isApiReady()) {
            return;
        }
        synchronized (LedIndicatorManager.class) {
            if (musicReactiveActive) {
                return;
            }
            int clamped = Math.max(0, Math.min(255, brightness));
            experimentalPwmBrightness.put(color, clamped);
            RxTaskManager.getInstance().cancelTask(flashTaskId(color));
            applyExperimentalPwmLocked(color, clamped);
            if (isDebug) {
                Log.d(TAG, color + " experimental PWM brightness=" + clamped);
            }
        }
    }

    public static int getExperimentalPwmBrightness(LedColor color) {
        synchronized (LedIndicatorManager.class) {
            Integer value = experimentalPwmBrightness.get(color);
            return value == null ? 0 : value;
        }
    }

    public static void clearAllExperimentalPwm() {
        if (!isApiReady()) {
            return;
        }
        synchronized (LedIndicatorManager.class) {
            for (LedColor color : LedColor.values()) {
                cancelExperimentalPwmLocked(color);
                mAPI.setGpioState(color.gpioPin(), YNHAPI.GpioState.LOW);
            }
        }
    }

    static float experimentalPwmDutyFraction(int brightness) {
        if (brightness <= 0) {
            return 0f;
        }
        if (brightness >= 255) {
            return 1f;
        }
        return (float) Math.pow(brightness / 255f, EXPERIMENTAL_PWM_GAMMA);
    }

    static int experimentalPwmPeriodUs(int brightness) {
        if (brightness <= 0 || brightness >= 255) {
            return EXPERIMENTAL_PWM_PERIOD_US;
        }
        float duty = experimentalPwmDutyFraction(brightness);
        if (duty >= EXPERIMENTAL_PWM_LOW_DUTY_THRESHOLD) {
            return EXPERIMENTAL_PWM_PERIOD_US;
        }
        float ramp = (EXPERIMENTAL_PWM_LOW_DUTY_THRESHOLD - duty) / EXPERIMENTAL_PWM_LOW_DUTY_THRESHOLD;
        int frequencyHz = Math.round(
                EXPERIMENTAL_PWM_FREQUENCY_HZ
                        + ramp * (EXPERIMENTAL_PWM_MAX_FREQUENCY_HZ - EXPERIMENTAL_PWM_FREQUENCY_HZ));
        return 1_000_000 / frequencyHz;
    }

    static int experimentalPwmOnUs(int brightness) {
        return experimentalPwmOnUs(brightness, experimentalPwmPeriodUs(brightness));
    }

    static int experimentalPwmOnUs(int brightness, int periodUs) {
        if (brightness <= 0 || brightness >= 255) {
            return 0;
        }
        return Math.max(1, Math.round(periodUs * experimentalPwmDutyFraction(brightness)));
    }

    static int experimentalPwmOffUs(int brightness) {
        return experimentalPwmOffUs(brightness, experimentalPwmPeriodUs(brightness));
    }

    static int experimentalPwmOffUs(int brightness, int periodUs) {
        int onUs = experimentalPwmOnUs(brightness, periodUs);
        if (onUs <= 0) {
            return 0;
        }
        return Math.max(1, periodUs - onUs);
    }

    private static void sleepMicros(long micros) {
        if (micros <= 0) {
            return;
        }
        try {
            Thread.sleep(micros / 1_000L, (int) ((micros % 1_000L) * 1_000L));
        } catch (InterruptedException ignored) {
            Thread.currentThread().interrupt();
        }
    }

    public static void syncHardwareToCachedModes() {
        if (!isApiReady()) {
            return;
        }
        synchronized (LedIndicatorManager.class) {
            for (Map.Entry<LedColor, IndicatorMode> entry : cachedModes.entrySet()) {
                applyHardwareLocked(entry.getKey(), entry.getValue());
            }
        }
    }

    private static void applyHardwareLocked(LedColor color, IndicatorMode mode) {
        String taskId = flashTaskId(color);
        cancelExperimentalPwmLocked(color);
        switch (mode) {
            case OFF:
                RxTaskManager.getInstance().cancelTask(taskId);
                mAPI.setGpioState(color.gpioPin(), YNHAPI.GpioState.LOW);
                if (isDebug) {
                    Log.d(TAG, color + " OFF");
                }
                break;
            case STEADY_ON:
                RxTaskManager.getInstance().cancelTask(taskId);
                mAPI.setGpioState(color.gpioPin(), YNHAPI.GpioState.HIGH);
                if (isDebug) {
                    Log.d(TAG, color + " STEADY_ON");
                }
                break;
            case BLINK:
                if (isDebug) {
                    Log.d(TAG, color + " BLINK");
                }
                scheduleFlashTask(color);
                break;
            default:
                break;
        }
    }

    private static void scheduleFlashTask(LedColor color) {
        String taskId = flashTaskId(color);
        RxTaskManager.getInstance().cancelTask(taskId);
        final int gpioPin = color.gpioPin();
        AbstractRxModbusTask task = new AbstractRxModbusTask() {
            @Override
            public void run() {
                mAPI.setGpioState(gpioPin, YNHAPI.GpioState.HIGH);
                if (isDebug) {
                    Log.d(TAG, "GPIO " + gpioPin + " HIGH");
                }
                try {
                    Thread.sleep(FLASH_ON_MS);
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                }
                mAPI.setGpioState(gpioPin, YNHAPI.GpioState.LOW);
                if (isDebug) {
                    Log.d(TAG, "GPIO " + gpioPin + " LOW");
                }
            }
        };
        task.setExecuteInterval(FLASH_ON_MS + FLASH_OFF_MS)
                .setTaskId(taskId);
        RxTaskManager.getInstance().addTask(task);
    }

    private static String flashTaskId(LedColor color) {
        return FLASH_TASK_PREFIX + color.name().toLowerCase();
    }

    private static void applyMusicReactiveBarLocked(int litSegments) {
        int segments = Math.max(0, Math.min(3, litSegments));
        mAPI.setGpioState(
                LedColor.GREEN.gpioPin(),
                segments >= 1 ? YNHAPI.GpioState.HIGH : YNHAPI.GpioState.LOW);
        mAPI.setGpioState(
                LedColor.YELLOW.gpioPin(),
                segments >= 2 ? YNHAPI.GpioState.HIGH : YNHAPI.GpioState.LOW);
        mAPI.setGpioState(
                LedColor.RED.gpioPin(),
                segments >= 3 ? YNHAPI.GpioState.HIGH : YNHAPI.GpioState.LOW);
    }

    private static void applyMusicReactiveLevelLocked(LedColor color, int level) {
        int clamped = Math.max(0, Math.min(255, level));
        YNHAPI.GpioState state = clamped > MUSIC_REACTIVE_ON_THRESHOLD
                ? YNHAPI.GpioState.HIGH
                : YNHAPI.GpioState.LOW;
        mAPI.setGpioState(color.gpioPin(), state);
    }

    private static void cancelExperimentalPwmLocked(LedColor color) {
        Thread thread = experimentalPwmThreads.remove(color);
        if (thread != null) {
            thread.interrupt();
        }
        experimentalPwmBrightness.put(color, 0);
    }

    private static void applyExperimentalPwmLocked(LedColor color, int brightness) {
        Thread existing = experimentalPwmThreads.remove(color);
        if (existing != null) {
            existing.interrupt();
        }
        final int gpioPin = color.gpioPin();
        if (brightness <= 0) {
            mAPI.setGpioState(gpioPin, YNHAPI.GpioState.LOW);
            return;
        }
        if (brightness >= 255) {
            mAPI.setGpioState(gpioPin, YNHAPI.GpioState.HIGH);
            return;
        }
        final int periodUs = experimentalPwmPeriodUs(brightness);
        final int onUs = experimentalPwmOnUs(brightness, periodUs);
        final int offUs = experimentalPwmOffUs(brightness, periodUs);
        Thread thread = new Thread(() -> {
            try {
                while (!Thread.currentThread().isInterrupted()) {
                    mAPI.setGpioState(gpioPin, YNHAPI.GpioState.HIGH);
                    sleepMicros(onUs);
                    if (Thread.currentThread().isInterrupted()) {
                        break;
                    }
                    mAPI.setGpioState(gpioPin, YNHAPI.GpioState.LOW);
                    sleepMicros(offUs);
                }
            } finally {
                mAPI.setGpioState(gpioPin, YNHAPI.GpioState.LOW);
            }
        }, "led-exp-pwm-" + color.name().toLowerCase());
        thread.setDaemon(true);
        experimentalPwmThreads.put(color, thread);
        thread.start();
    }

    /** Resets cached modes to boot defaults; for unit tests only. */
    static void resetForTest() {
        synchronized (LedIndicatorManager.class) {
            for (LedColor color : LedColor.values()) {
                Thread thread = experimentalPwmThreads.remove(color);
                if (thread != null) {
                    thread.interrupt();
                }
                cachedModes.put(color, IndicatorMode.OFF);
                experimentalPwmBrightness.put(color, 0);
            }
            cachedModes.put(LedColor.GREEN, IndicatorMode.STEADY_ON);
        }
    }
}
