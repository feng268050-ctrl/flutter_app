package com.lasercyber.lws.ui.common.camera;

/**
 * Previously hid EasyFloat camera panels under MachineStatusOverlay.
 * Record Working is now an in-layout control, so this coordinator is a no-op
 * kept for existing call sites.
 */
public final class CameraFloatOverlayCoordinator {

  private CameraFloatOverlayCoordinator() {}

  public static void onMachineStatusOverlayShowing() {
    // no-op: Record Working is no longer an EasyFloat window
  }

  public static void onMachineStatusOverlayDismissed() {
    // no-op
  }
}
