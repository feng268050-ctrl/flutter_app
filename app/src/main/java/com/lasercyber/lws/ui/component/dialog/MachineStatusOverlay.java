package com.lasercyber.lws.ui.component.dialog;

import android.app.Activity;
import android.content.Context;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentActivity;
import androidx.fragment.app.FragmentManager;

import com.lasercyber.lws.frostui.border.FrostTone;
import com.lasercyber.lws.frostui.button.interop.FrostButtonView;
import com.lasercyber.lws.frostui.card.interop.FrostCardView;
import com.lasercyber.lws.frostui.dialog.FrostOverlayHost;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.engineer.mode.fragment.LaserLiveMonitorOverlayFragment;
import com.lasercyber.lws.ui.common.camera.CameraFloatOverlayCoordinator;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;

/**
 * Machine real-time status / Live Monitor overlay on {@link FrostDialog} with {@link FrostTone#LIGHT}.
 */
public final class MachineStatusOverlay {

    public static final String FRAGMENT_TAG = "frost_machine_status";

    @Nullable
    private static FrostDialog.Handle sActiveHandle;
    private static int sShowGeneration;

    private MachineStatusOverlay() {
    }

    @Nullable
    public static FrostDialog.Handle show(
            @NonNull Context context,
            boolean showConfirmButton) {
        return show(context, showConfirmButton, null);
    }

    @Nullable
    public static FrostDialog.Handle show(
            @NonNull Context context,
            boolean showConfirmButton,
            @Nullable Runnable onDismissed) {
        Activity activity = FrostOverlayHost.findActivity(context);
        if (!(activity instanceof FragmentActivity fragmentActivity)) {
            return null;
        }
        if (activity.isFinishing() || activity.isDestroyed()) {
            return null;
        }

        synchronized (MachineStatusOverlay.class) {
            if (sActiveHandle != null && sActiveHandle.isShowing()) {
                if (!showConfirmButton) {
                    hideActionBar(sActiveHandle);
                }
                return sActiveHandle;
            }
            dismissActiveHandleLocked(fragmentActivity);
            final int showGeneration = ++sShowGeneration;

            CameraFloatOverlayCoordinator.onMachineStatusOverlayShowing();

            FrostDialog.PromptBuilder builder = FrostDialog.prompt(context)
                    .tone(FrostTone.LIGHT)
                    .title(R.string.real_time_machine_status_text)
                    .contentInsetDimen(R.dimen.machine_status_dialog_screen_inset)
                    .showTitle(true)
                    .dismissOnScrimClick(false)
                    .customBodyView(R.layout.machine_status_overlay_body, body -> bindBody(
                            body,
                            fragmentActivity,
                            showConfirmButton,
                            showGeneration))
                    .onDismiss(() -> {
                        synchronized (MachineStatusOverlay.class) {
                            sActiveHandle = null;
                            sShowGeneration++;
                        }
                        CameraFloatOverlayCoordinator.onMachineStatusOverlayDismissed();
                        removeMachineStatusFragment(fragmentActivity);
                        if (onDismissed != null) {
                            onDismissed.run();
                        }
                    });

            if (showConfirmButton) {
                builder.showActionBar(true)
                        .autoDismissOnConfirm(false)
                        .customActionBarView(
                                R.layout.dialog_frost_action_prompt,
                                action -> bindConfirmAction(action));
            } else {
                builder.showActionBar(false)
                        .showConfirm(false)
                        .showCancel(false);
            }

            FrostDialog.Handle handle = builder.show();
            if (handle == null) {
                removeMachineStatusFragment(fragmentActivity);
                CameraFloatOverlayCoordinator.onMachineStatusOverlayDismissed();
                return null;
            }

            sActiveHandle = handle;
            if (!showConfirmButton) {
                // Gun-triggered Live Monitor is controlled exclusively by the gun edge.
                // Hide defensively after body/slot installation as well as through config.
                hideActionBar(handle);
            }
            return handle;
        }
    }

    private static void hideActionBar(@NonNull FrostDialog.Handle handle) {
        View root = handle.getRootView();
        if (root == null) {
            return;
        }
        View actionSection = root.findViewById(R.id.frost_dialog_action_section);
        if (actionSection != null) {
            actionSection.setVisibility(View.GONE);
        }
    }

    public static void dismiss() {
        dismissActiveHandle();
    }

    public static void dismiss(@Nullable Activity activity) {
        dismissActiveHandle();
    }

    private static void dismissActiveHandle() {
        synchronized (MachineStatusOverlay.class) {
            Activity activity = null;
            if (sActiveHandle != null && sActiveHandle.getRootView() != null) {
                activity = FrostOverlayHost.findActivity(sActiveHandle.getRootView().getContext());
            }
            dismissActiveHandleLocked(
                    activity instanceof FragmentActivity fragmentActivity ? fragmentActivity : null);
        }
    }

    private static void dismissActiveHandleLocked(@Nullable FragmentActivity fragmentActivity) {
        if (sActiveHandle != null && sActiveHandle.isShowing()) {
            sActiveHandle.dismissImmediate();
        }
        sActiveHandle = null;
        sShowGeneration++;
        if (fragmentActivity != null) {
            removeMachineStatusFragmentNow(fragmentActivity);
        }
    }

    private static void bindBody(
            @NonNull View body,
            @NonNull FragmentActivity fragmentActivity,
            boolean quickModeMoreMonitor,
            int showGeneration) {
        prepareMachineStatusBody(body, quickModeMoreMonitor);
        LaserLiveMonitorOverlayFragment fragment = attachLiveMonitorFragment(
                fragmentActivity,
                body,
                quickModeMoreMonitor);
        if (fragment == null) {
            return;
        }
        setBackdropBlurEnabled(body, false);
        scheduleDeferredChrome(body, fragmentActivity, showGeneration);
    }

    private static void bindConfirmAction(@NonNull View action) {
        FrostButtonView confirm = action.findViewById(R.id.btn_confirm);
        if (confirm == null) {
            return;
        }
        confirm.setText(R.string.i_understand_text);
        confirm.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            FrostDialog.Handle handle = sActiveHandle;
            if (handle != null && handle.isShowing()) {
                handle.dismiss();
            }
        });
    }

    private static void prepareMachineStatusBody(@NonNull View body, boolean quickModeMoreMonitor) {
        if (!quickModeMoreMonitor) {
            return;
        }
        if (body instanceof ViewGroup bodyGroup) {
            bodyGroup.setClipChildren(false);
            bodyGroup.setClipToPadding(false);
        }
        ViewGroup host = (ViewGroup) body.getParent();
        if (host != null) {
            host.setClipChildren(false);
            host.setClipToPadding(false);
        }
        View foreground = body.getRootView().findViewById(R.id.frost_dialog_light_foreground);
        if (foreground instanceof ViewGroup group) {
            group.setClipChildren(false);
            group.setClipToPadding(false);
        }
    }

    private static void scheduleDeferredChrome(
            @NonNull View body,
            @NonNull FragmentActivity fragmentActivity,
            int showGeneration) {
        body.post(() -> {
            synchronized (MachineStatusOverlay.class) {
                if (showGeneration != sShowGeneration) {
                    return;
                }
                if (sActiveHandle == null || !sActiveHandle.isShowing()) {
                    return;
                }
            }
            setBackdropBlurEnabled(body, true);
            LaserLiveMonitorOverlayFragment fragment = findLiveMonitorFragment(fragmentActivity);
            if (fragment != null) {
                fragment.flushDeferredGaugeRendering();
            }
        });
    }

    @Nullable
    private static LaserLiveMonitorOverlayFragment attachLiveMonitorFragment(
            @NonNull FragmentActivity fragmentActivity,
            @NonNull View body,
            boolean quickModeMoreMonitor) {
        FragmentManager fragmentManager = fragmentActivity.getSupportFragmentManager();
        if (fragmentManager.isDestroyed()) {
            return null;
        }
        removeMachineStatusFragmentNow(fragmentActivity);

        ViewGroup container = body.findViewById(R.id.work_status_content);
        if (container == null) {
            return null;
        }
        assignUniqueContainerId(container);

        LaserLiveMonitorOverlayFragment fragment = new LaserLiveMonitorOverlayFragment();
        fragment.prepareForOverlayShow();
        if (quickModeMoreMonitor) {
            Bundle args = new Bundle();
            args.putBoolean(LaserLiveMonitorOverlayFragment.ARG_QUICK_MODE_MORE_MONITOR, true);
            fragment.setArguments(args);
        }
        fragmentManager.beginTransaction()
                .replace(container.getId(), fragment, FRAGMENT_TAG)
                .commitNow();
        return fragment;
    }

    private static void assignUniqueContainerId(@NonNull ViewGroup container) {
        int containerId = container.getId();
        if (containerId == View.NO_ID || containerId == R.id.work_status_content) {
            container.setId(View.generateViewId());
        }
    }

    @Nullable
    private static LaserLiveMonitorOverlayFragment findLiveMonitorFragment(
            @NonNull FragmentActivity fragmentActivity) {
        Fragment fragment = fragmentActivity.getSupportFragmentManager().findFragmentByTag(FRAGMENT_TAG);
        return fragment instanceof LaserLiveMonitorOverlayFragment liveMonitor
                ? liveMonitor
                : null;
    }

    static void removeMachineStatusFragment(@NonNull Context context) {
        Activity activity = FrostOverlayHost.findActivity(context);
        if (!(activity instanceof FragmentActivity fragmentActivity)) {
            return;
        }
        removeMachineStatusFragmentNow(fragmentActivity);
    }

    private static void removeMachineStatusFragmentNow(@NonNull FragmentActivity fragmentActivity) {
        FragmentManager fragmentManager = fragmentActivity.getSupportFragmentManager();
        if (fragmentManager.isDestroyed()) {
            return;
        }
        Fragment fragment = fragmentManager.findFragmentByTag(FRAGMENT_TAG);
        if (fragment == null) {
            return;
        }
        fragmentManager.beginTransaction()
                .remove(fragment)
                .commitNowAllowingStateLoss();
    }

    private static void setBackdropBlurEnabled(@NonNull View root, boolean enabled) {
        if (root instanceof FrostCardView card) {
            card.setEnableBackdropBlur(enabled);
        }
        if (root instanceof ViewGroup group) {
            for (int index = 0; index < group.getChildCount(); index++) {
                setBackdropBlurEnabled(group.getChildAt(index), enabled);
            }
        }
    }
}
