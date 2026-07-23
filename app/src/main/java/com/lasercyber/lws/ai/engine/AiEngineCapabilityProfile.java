package com.lasercyber.lws.ai.engine;
import com.lasercyber.lws.ai.engine.AiManager;
/**
 * Read-only snapshot of {@link AiManager} / native engine capabilities for UI branching.
 */
public final class AiEngineCapabilityProfile {

    private final boolean classificationEnabled;
    private final boolean detectionEnabled;
    private final boolean rknnStainDetectAvailable;
    private final boolean rknnStainDetectFromRgbAvailable;
    private final boolean focusMonitoringExpected;

    AiEngineCapabilityProfile(boolean classificationEnabled,
                              boolean detectionEnabled,
                              boolean rknnStainDetectAvailable,
                              boolean rknnStainDetectFromRgbAvailable,
                              boolean sessionRunning) {
        this.classificationEnabled = classificationEnabled;
        this.detectionEnabled = detectionEnabled;
        this.rknnStainDetectAvailable = rknnStainDetectAvailable;
        this.rknnStainDetectFromRgbAvailable = rknnStainDetectFromRgbAvailable;
        this.focusMonitoringExpected = classificationEnabled && sessionRunning;
    }

    public boolean isClassificationEnabled() {
        return classificationEnabled;
    }

    public boolean isDetectionEnabled() {
        return detectionEnabled;
    }

    public boolean isRknnStainDetectAvailable() {
        return rknnStainDetectAvailable;
    }

    public boolean isRknnStainDetectFromRgbAvailable() {
        return rknnStainDetectFromRgbAvailable;
    }

    public boolean isFocusMonitoringExpected() {
        return focusMonitoringExpected;
    }

    @Override
    public String toString() {
        return "AiEngineCapabilityProfile{"
                + "classificationEnabled=" + classificationEnabled
                + ", detectionEnabled=" + detectionEnabled
                + ", rknnStainDetectAvailable=" + rknnStainDetectAvailable
                + ", rknnStainDetectFromRgbAvailable=" + rknnStainDetectFromRgbAvailable
                + ", focusMonitoringExpected=" + focusMonitoringExpected
                + '}';
    }
}
