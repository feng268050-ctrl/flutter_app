package com.lasercyber.lws.ui.activitys.quick.mode.fragment;

import android.util.Log;

import androidx.fragment.app.Fragment;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.quick.mode.listener.CNCLinkSuccessListener;
import com.lasercyber.lws.ui.bean.entity.DeviceControlData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.gpio.LaserEnableStateHolder;
import com.lasercyber.lws.ui.common.handler.GpioLedHandler;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.utils.LoadingUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.databinding.FragmentCNCCutBinding;
import com.xuexiang.xui.widget.dialog.MiniLoadingDialog;

import lombok.Setter;

/**
 * A simple {@link Fragment} subclass.
 * Use the {@link CNCCutFragment#newInstance} factory method to
 * create an instance of this fragment.
 * CNC切割
 */
public class CNCCutFragment extends BaseFragment<FragmentCNCCutBinding> implements MemoryCacheManager.OnCacheChangedListener {
    private static final String TAG = LogTAGConstant.CNCCutFragment;
    // CNC连接超时时间
    private static final int CNC_CONNECTION_TIMEOUT = 10 * 1000;
    private final DeviceControlData deviceControlData = new DeviceControlData();
    private MiniLoadingDialog miniLoadingDialog;
    // 开始检测CNC连接的时间
    private volatile long startCheckConnectTime;
    /** 用户主动退出后，忽略设备状态位延迟清零前的 isConnectCNC=true，避免覆盖层被重新拉起。 */
    private volatile boolean sessionDismissed;
    @Setter
    private CNCLinkSuccessListener cncLinkSuccessListener;

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_c_n_c_cut;
    }

    @Override
    protected void initView() {
        binding.setCommunicationStatus(1);
        deviceControlData.setModel(ModelConstant.CNC_CUT);
        LaserEnableStateHolder.setWorkModel(ModelConstant.CNC_CUT);
        ModbusManagerRtu.get().writeRegisters(ModbusFiledBuilder.createDeviceControlData(deviceControlData));

        miniLoadingDialog = LoadingUtils.getMiniLoadingDialog(getActivity(), getString(R.string.detecting_connection));

        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
//        binding.cncCheckBtn.setOnClickListener(v -> checkCNCConnection());
        this.task = this::checkConnectDelayed;
        handler.postDelayed(task, CNC_CONNECTION_TIMEOUT);
    }

    private void checkConnectDelayed() {
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        boolean isConnectCNC = deviceStatus != null && deviceStatus.isConnectCNC();
        // 判断是否连接超时
        if (miniLoadingDialog != null && miniLoadingDialog.isLoading()) {
            // 先关闭加载中的弹窗
            miniLoadingDialog.dismiss();
            ToastUtils.showShort(isConnectCNC ? R.string.cnc_connection_successful : R.string.cnc_connection_failed);
        }
        if (binding != null) {
            binding.setCommunicationStatus(isConnectCNC ? 2 : 3);
        }
        if (isConnectCNC) {
            notifyCncLinkSuccess();
        }
        GpioLedHandler.refresh();
        this.task = null;
    }

    private void notifyCncLinkSuccess() {
        if (sessionDismissed || cncLinkSuccessListener == null) {
            return;
        }
        cncLinkSuccessListener.onSuccess();
    }

    @Override
    protected void initData() {

    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
    }

    @Override
    public void onCacheChanged(String key) {
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(key);
        if (deviceStatus == null) {
            return;
        }
        int communicationStatus = 3;
        if (!deviceStatus.isConnectCNC()) {
            sessionDismissed = false;
        } else if (sessionDismissed) {
            GpioLedHandler.refresh();
            return;
        }
        if (deviceStatus.isConnectCNC()) {
            if (this.task != null) {
                // 关闭最大连接时长检测
                handler.removeCallbacks(this.task);
                this.task = null;
            }
            if (startCheckConnectTime > 0 && miniLoadingDialog.isLoading()) {
                long time = System.currentTimeMillis() - startCheckConnectTime;
                // 限制弹窗的最短显示时长
                if (time < 1000) {
                    startCheckConnectTime = -1;
                    handler.postDelayed(() -> {
                        ToastUtils.showShort(R.string.cnc_connection_successful);
                        miniLoadingDialog.dismiss();
                    }, 700);
                } else {
                    ToastUtils.showShort(R.string.cnc_connection_successful);
                    miniLoadingDialog.dismiss();
                }

            }
            communicationStatus = 2;
        }
        if (binding != null && binding.getCommunicationStatus() != communicationStatus) {
            Log.d(TAG, "onCacheChanged: 正在更新CNC连接状态:" + communicationStatus);
            binding.setCommunicationStatus(communicationStatus);
            if (communicationStatus == 2) {
                notifyCncLinkSuccess();
            }
        }
        GpioLedHandler.refresh();
    }

    @Override
    public void onResume() {
        super.onResume();
        LaserEnableStateHolder.setWorkModel(ModelConstant.CNC_CUT);
        GpioLedHandler.refresh();
    }

    /**
     * CNC 运行会话结束（主动退出或设备断开）后，回到未连接引导界面。
     */
    public void onCncSessionClosed() {
        sessionDismissed = true;
        GpioLedHandler.refresh();
        if (this.task != null) {
            handler.removeCallbacks(this.task);
            this.task = null;
        }
        if (miniLoadingDialog != null && miniLoadingDialog.isLoading()) {
            miniLoadingDialog.dismiss();
        }
        if (binding != null) {
            binding.setCommunicationStatus(3);
        }
    }

    /**
     * 检测CNC连接
     */
    public void checkCNCConnection() {
        GlobalSoundManager.playClickSound();
        sessionDismissed = false;
        miniLoadingDialog.show();
        if (this.task == null) {
            this.task = this::checkConnectDelayed;
            handler.postDelayed(task, 3 * 1000);
        }
        startCheckConnectTime = System.currentTimeMillis();
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlData(deviceControlData),
                new ModbusManagerRtu.WriteCallback() {
                    @Override
                    public void onSuccess() {
                        Log.d(TAG, "onSuccess: 下发CNC模式成功");
                    }

                    @Override
                    public void onFailure() {
                        miniLoadingDialog.dismiss();
                        ToastUtils.showShort(R.string.cnc_connection_failed);
                    }
                });
    }
}
