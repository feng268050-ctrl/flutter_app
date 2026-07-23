package com.lasercyber.lws.ui.common.camera;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class CameraRecordButtonVisualStateTest {

    @Test
    public void resolve_recordingOverridesCommFault() {
        assertEquals(
                CameraRecordButtonVisualState.State.RECORDING,
                CameraRecordButtonVisualState.resolve(true, false));
        assertFalse(CameraRecordButtonVisualState.commUnavailableVisual(true, false));
    }

    @Test
    public void resolve_idleFault_isUnavailable() {
        assertEquals(
                CameraRecordButtonVisualState.State.UNAVAILABLE,
                CameraRecordButtonVisualState.resolve(false, false));
        assertTrue(CameraRecordButtonVisualState.commUnavailableVisual(false, false));
    }

    @Test
    public void resolve_idleHealthy_isAvailable() {
        assertEquals(
                CameraRecordButtonVisualState.State.AVAILABLE,
                CameraRecordButtonVisualState.resolve(false, true));
        assertFalse(CameraRecordButtonVisualState.commUnavailableVisual(false, true));
    }

    @Test
    public void tapRouting_faultIdle_showsToastNotPreflight() {
        assertTrue(CameraRecordButtonVisualState.shouldShowCameraUnavailableToast(false, false));
        assertFalse(CameraRecordButtonVisualState.shouldStartPreflightOnTap(false, false));
    }

    @Test
    public void tapRouting_healthyIdle_startsPreflight() {
        assertFalse(CameraRecordButtonVisualState.shouldShowCameraUnavailableToast(false, true));
        assertTrue(CameraRecordButtonVisualState.shouldStartPreflightOnTap(false, true));
    }

    @Test
    public void tapRouting_recording_stopsOnly() {
        assertFalse(CameraRecordButtonVisualState.shouldShowCameraUnavailableToast(true, false));
        assertFalse(CameraRecordButtonVisualState.shouldStartPreflightOnTap(true, false));
        assertFalse(CameraRecordButtonVisualState.shouldStartPreflightOnTap(true, true));
    }
}
