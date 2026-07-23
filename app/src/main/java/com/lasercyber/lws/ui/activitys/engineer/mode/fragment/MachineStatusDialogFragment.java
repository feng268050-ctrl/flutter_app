package com.lasercyber.lws.ui.activitys.engineer.mode.fragment;

import android.view.View;
import android.view.ViewGroup;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.device.monitor.fragment.MachineStatusBaseFragment;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.view.CircleProgressView;
import com.lasercyber.lws.ui.databinding.FragmentMachineStatusDialogBinding;

/**
 * 机台状态，加载弹窗中的内容。
 * <p>
 * Overlay / Live Monitor path now uses {@link LaserLiveMonitorOverlayFragment}
 * via {@link com.lasercyber.lws.ui.component.dialog.MachineStatusOverlay}.
 * This gauges-only fragment remains for any non-overlay callers; overlay cleanup
 * may remove that path in a follow-up if unused.
 */
public class MachineStatusDialogFragment extends MachineStatusBaseFragment<FragmentMachineStatusDialogBinding> {

    /**
     * 快速模式「更多监测」机台状态弹窗：避免表盘刻度/间距被圆角容器或父布局裁剪。
     */
    public static final String ARG_QUICK_MODE_MORE_MONITOR = "arg_quick_mode_more_monitor";

    public void prepareForOverlayShow() {
        setDeferGaugeRendering(true);
    }

    @Override
    protected void setDeviceData(DeviceData deviceData) {
        if (binding == null) {
            return;
        }
        binding.setDeviceData(deviceData);
    }

    @Override
    protected void setDeviceStatus(DeviceStatus deviceStatus) {
        if (binding == null) {
            return;
        }
        binding.setDeviceStatus(deviceStatus);
    }

    @Override
    protected void setCameraCommFault(boolean cameraCommFault) {
        // Quick-mode dialog layout has no camera comm tile.
    }

    @Override
    protected CircleProgressView getLeftCircleView() {
        return binding.leftCircleView;
    }

    @Override
    protected CircleProgressView getRightCircleView() {
        return binding.rightCircleView;
    }

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_machine_status_dialog;
    }

    @Override
    protected void initView() {
        super.initView();
        boolean quickModeMoreMonitor = getArguments() != null
                && getArguments().getBoolean(ARG_QUICK_MODE_MORE_MONITOR, false);
        if (!quickModeMoreMonitor) {
            return;
        }
        ViewGroup gaugeRow = (ViewGroup) binding.leftCircleViewContainer.getParent();
        if (gaugeRow != null) {
            gaugeRow.setClipChildren(false);
            gaugeRow.setClipToPadding(false);
        }
        View root = binding.getRoot();
        if (root instanceof ViewGroup) {
            ViewGroup g = (ViewGroup) root;
            g.setClipChildren(false);
            g.setClipToPadding(false);
            for (int i = 0; i < g.getChildCount(); i++) {
                View c = g.getChildAt(i);
                if (c instanceof ViewGroup) {
                    ((ViewGroup) c).setClipChildren(false);
                    ((ViewGroup) c).setClipToPadding(false);
                }
            }
        }
        binding.leftCircleViewContainer.setClipChildren(false);
        binding.leftCircleViewContainer.setClipToPadding(false);
        binding.rightCircleViewContainer.setClipChildren(false);
        binding.rightCircleViewContainer.setClipToPadding(false);
    }
}
