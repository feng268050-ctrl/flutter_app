package com.lasercyber.lws.ui.activitys.quick.mode.ui;

import android.view.View;

import com.lasercyber.lws.frostui.control.FrostHoldConfirmController;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserEnableLongPressTouchHelper;
import com.lasercyber.lws.ui.activitys.quick.mode.component.LaserButtonLinearLayout;

/**
 * Quick-mode Laser Enable: hold ripple on trapezoid-clipped overlay above button content.
 */
public final class QuickModeLaserEnableLongPressTouchHelper {

    private final FrostHoldConfirmController controller;

    public QuickModeLaserEnableLongPressTouchHelper(LaserButtonLinearLayout button, LaserEnableLongPressTouchHelper.Host host) {
        controller = new FrostHoldConfirmController(
                button.getRippleOverlay(),
                null,
                new FrostHoldConfirmController.Listener() {
                    @Override
                    public boolean useHoldConfirm() {
                        return !host.isLaserOpen();
                    }

                    @Override
                    public boolean passesHoldPreflight() {
                        return host.passesLaserEnablePreflight();
                    }

                    @Override
                    public void onConfirm() {
                        host.onLaserEnableConfirmed();
                    }

                    @Override
                    public void onImmediateClick() {
                        host.onLaserDisableClick();
                    }
                },
                true,
                QuickModeLaserHoldConfirmConfig.create()
        );
    }

    public void attach() {
        controller.attach();
    }

    public void release() {
        controller.release();
    }
}
