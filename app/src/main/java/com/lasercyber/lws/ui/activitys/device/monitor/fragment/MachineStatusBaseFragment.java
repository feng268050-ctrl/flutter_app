package com.lasercyber.lws.ui.activitys.device.monitor.fragment;

import android.graphics.Color;
import android.util.Log;

import androidx.databinding.ViewDataBinding;
import androidx.fragment.app.Fragment;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.bean.entity.DeviceData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.camera.CameraCommStatus;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.view.CircleProgressView;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

/**
 * A simple {@link Fragment} subclass.
 * create an instance of this fragment.
 * 机台状态
 */
public abstract class MachineStatusBaseFragment<T extends ViewDataBinding> extends BaseFragment<T> implements MemoryCacheManager.OnCacheChangedListener {
    protected static final String TAG = LogTAGConstant.MachineStatusFragment;
    /**
     * 设备状态
     */
    private DeviceStatus deviceStatus;
    /**
     * 设备数据
     **/
    private DeviceData deviceData;
    /**
     * Dialog first frame: bind tiles via DataBinding but defer gauge canvas work until overlay is shown.
     */
    private boolean deferGaugeRendering;
    /**
     * 任务列表
     */
    private final List<String> taskIdList = new ArrayList<>();

    @Override
    protected void initView() {

    }


    @Override
    protected void initData() {
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_DATA_KEY, this);
        MemoryCacheManager.getInstance().addListener(CacheKey.CAMERA_PING_REACHABLE, this);
        // 更新设备状态
        readUpdateDeviceStatus();
        // 更新设备数据
        readUpdateDeviceData();
        readUpdateCameraCommStatus();
    }

    /**
     * 设置数据
     * @param deviceData
     */
    protected abstract void setDeviceData(DeviceData deviceData);
    /**
     * 设置状态
     */
    protected abstract void setDeviceStatus(DeviceStatus deviceStatus);

    protected abstract void setCameraCommFault(boolean cameraCommFault);

    protected abstract CircleProgressView getLeftCircleView();
    protected abstract CircleProgressView getRightCircleView();

    protected void setDeferGaugeRendering(boolean deferGaugeRendering) {
        this.deferGaugeRendering = deferGaugeRendering;
    }

    /** Applies deferred gauge rendering after the overlay body is on screen. */
    public void flushDeferredGaugeRendering() {
        if (!deferGaugeRendering) {
            return;
        }
        deferGaugeRendering = false;
        if (deviceData == null) {
            return;
        }
        setBlowAirPressure(deviceData.getBlowAirPressure());
        Number rightData = getRightChartsData(deviceData);
        if (rightData != null) {
            setPumpSourceCurrent(rightData.doubleValue());
        }
    }

    /**
     * 获取右边图形的现在值
     * @param data
     * @return
     */
    protected Number getRightChartsData(DeviceData data) {
        if (data == null) {
            return null;
        }
        return data.getPumpGaugeCurrentAmps();
    }
    /*左侧的统计图*/
    private void setBlowAirPressure(Integer value){
        // 左侧：Blow pressure 45kpa（绿色）
        CircleProgressView leftCircleView = getLeftCircleView();
        if (leftCircleView == null){
            return;
        }
        leftCircleView.setProgress(
                value,
                " kpa",
                this.getResources().getString(R.string.machine_blow_title),
                this.getResources().getString(R.string.machine_blow_content),
                1500,
                new int[]{
                        Color.parseColor("#00C853"), // 进度0-50：绿色
                        Color.parseColor("#FFA500"), // 进度50-80：橙色
                        Color.parseColor("#FF4444") , // 进度80-100：红色
                        Color.parseColor("#00C853")
                }
        );
    }
    /*右侧的统计图*/
    private void setPumpSourceCurrent(Number value){
        // 右侧：Laser current
        CircleProgressView rightCircleView = getRightCircleView();
        if (rightCircleView == null){
            return;
        }
        rightCircleView.setProgress(
                value.doubleValue(),
                " A",
                this.getResources().getString(R.string.machine_laser_current_title),
                this.getResources().getString(R.string.machine_laser_current_content),
                100,
                new int[]{
                        Color.parseColor("#00C853"), // 进度0-50：绿色
                        Color.parseColor("#FFA500"), // 进度50-80：橙色
                        Color.parseColor("#FF4444") , // 进度80-100：红色
                        Color.parseColor("#00C853")
                }
        );
    }

    @Override
    protected void bindViewModel() {
        super.bindViewModel();
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        // 移除监听
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_DATA_KEY, this);
        MemoryCacheManager.getInstance().removeListener(CacheKey.CAMERA_PING_REACHABLE, this);
        /*RxTaskManager.getInstance().batchCancelTask(taskIdList);*/
    }

    @Override
    public void onCacheChanged(String key) {
        handler.post(() -> {
            if (Objects.equals(key, CacheKey.DEVICE_STATUS_KEY)) {
                // 更新设备状态
                readUpdateDeviceStatus();
            } else if (Objects.equals(key, CacheKey.DEVICE_DATA_KEY)) {
                // 更新设备数据
                readUpdateDeviceData();
            } else if (Objects.equals(key, CacheKey.CAMERA_PING_REACHABLE)) {
                readUpdateCameraCommStatus();
            }
        });
    }

    private void readUpdateCameraCommStatus() {
        setCameraCommFault(CameraCommStatus.isFault());
    }

    /**
     * 读取更新设备数据
     */
    private void readUpdateDeviceData() {
        DeviceData cacheData = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_DATA_KEY);
        if (cacheData == null) {
            cacheData=new DeviceData();
        }
        Log.d(TAG, "泵源表盘(0x006F): raw=" + cacheData.getPumpGaugeCurrentRaw()
                + ", amps=" + cacheData.getPumpGaugeCurrentAmps());
        if (this.deviceData != null && !this.deviceData.dataChange(cacheData)) {
            return;
        }
        // 气压
        Integer oldBlowAirPressure = deviceData != null ? deviceData.getBlowAirPressure() : null;
        Integer newBlowAirPressure = cacheData.getBlowAirPressure();
        Log.d(TAG, "机台状态读取数据: left：气压newBlowAirPressure:" + newBlowAirPressure + ",oldBlowAirPressure:" + oldBlowAirPressure);
        // 右边的图表
        Number oldRightData = getRightChartsData(deviceData);
        Number newRightData = getRightChartsData(cacheData);
        Log.d(TAG, "机台状态读取数据，newRightData：" + newRightData);
        this.deviceData = cacheData.clone();
        DeviceData finalCacheData = cacheData;
        handler.post(() -> {
            // 更新视图
            setDeviceData(finalCacheData);
            if (!Objects.equals(oldBlowAirPressure, newBlowAirPressure) && !deferGaugeRendering) {
                // 更新图表 吹气气压
                setBlowAirPressure(newBlowAirPressure);
            }
            if (!Objects.equals(oldRightData, newRightData) && !deferGaugeRendering) {
                setPumpSourceCurrent(newRightData.doubleValue());
            }
        });


    }

    /**
     * 读取并更新设备状态
     */
    private void readUpdateDeviceStatus() {
        DeviceStatus cacheData = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (cacheData==null){
            return;
        }
        if (deviceStatus != null
                && Objects.equals(deviceStatus.getMachineStatusSeg1(), cacheData.getMachineStatusSeg1())
                && Objects.equals(deviceStatus.getMachineStatusSeg2(), cacheData.getMachineStatusSeg2())) {
            return;
        }
        deviceStatus = cacheData.clone();
        setDeviceStatus(deviceStatus);
    }
}