package com.lasercyber.lws.ui.activitys.device.monitor.fragment;

import androidx.fragment.app.Fragment;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.view.CircleProgressView;
import com.lasercyber.lws.ui.databinding.FragmentMachineStatusBinding;

/**
 * A simple {@link Fragment} subclass.
 * create an instance of this fragment.
 * 机台状态
 */
public class MachineStatusFragment extends MachineStatusBaseFragment<FragmentMachineStatusBinding> {

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
        if (binding == null) {
            return;
        }
        binding.setCameraCommFault(cameraCommFault);
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
        return R.layout.fragment_machine_status;
    }
}
