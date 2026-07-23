package com.lasercyber.lws.ui.common.gpio;

import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Tracks work-screen state for GPIO indicator rules (Laser Enable, active work model).
 */
public final class LaserEnableStateHolder {

    public interface Listener {
        void onLaserEnableChanged(boolean active);
    }

    private static final CopyOnWriteArrayList<Listener> LISTENERS = new CopyOnWriteArrayList<>();

    private static volatile boolean laserEnableActive;
    private static volatile int activeWorkModel;

    private LaserEnableStateHolder() {
    }

    public static void addListener(Listener listener) {
        if (listener != null) {
            LISTENERS.add(listener);
        }
    }

    public static void removeListener(Listener listener) {
        if (listener != null) {
            LISTENERS.remove(listener);
        }
    }

    public static boolean isActive() {
        return laserEnableActive;
    }

    public static int getActiveWorkModel() {
        return activeWorkModel;
    }

    public static void setWorkModel(int workModel) {
        activeWorkModel = workModel;
    }

    public static void setActive(boolean active) {
        setActive(active, activeWorkModel);
    }

    public static void setActive(boolean active, int workModel) {
        boolean previous = laserEnableActive;
        laserEnableActive = active;
        activeWorkModel = workModel;
        notifyIfChanged(previous, active);
    }

    /** Clears laser-enable only; work model is owned by the active screen. */
    public static void clearLaserEnable() {
        boolean previous = laserEnableActive;
        laserEnableActive = false;
        notifyIfChanged(previous, false);
    }

    public static void clear() {
        boolean previous = laserEnableActive;
        laserEnableActive = false;
        activeWorkModel = 0;
        notifyIfChanged(previous, false);
    }

    private static void notifyIfChanged(boolean previous, boolean active) {
        if (previous == active) {
            return;
        }
        for (Listener listener : LISTENERS) {
            listener.onLaserEnableChanged(active);
        }
    }
}
