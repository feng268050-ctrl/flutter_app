package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import android.view.View;

import com.lasercyber.lws.frostui.control.FrostHoldConfirmController;

/**
 * Laser Enable 按住确认：委托 {@link FrostHoldConfirmController} 实现可逆 ripple。
 */
public final class LaserEnableLongPressTouchHelper {

    public interface Host {
        boolean isLaserOpen();

        /** Work-status preflight before hold ripple (key switch, E-stop, etc.). */
        boolean passesLaserEnablePreflight();

        void onLaserDisableClick();

        void onLaserEnableConfirmed();
    }

    private final FrostHoldConfirmController controller;

    public LaserEnableLongPressTouchHelper(View target, Host host) {
        controller = new FrostHoldConfirmController(
                target,
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
                true
        );
    }

    public void attach() {
        controller.attach();
    }

    public void release() {
        controller.release();
    }
}
