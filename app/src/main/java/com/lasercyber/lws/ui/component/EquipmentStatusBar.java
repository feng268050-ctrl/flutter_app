package com.lasercyber.lws.ui.component;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.content.res.TypedArray;
import android.graphics.Color;
import android.net.ConnectivityManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.AttributeSet;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.LinearLayout;

import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import androidx.core.app.ActivityCompat;

import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.EquipmentStatus;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.camera.CameraRecordStateStore;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockStore;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.TimeGlobalManager;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.holder.SimpleBluetoothConnectReceiver;
import com.lasercyber.lws.ui.component.holder.SimpleWifiConnectReceiver;
import com.lasercyber.lws.ui.databinding.EquipmentStatusBarBinding;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

import lombok.Setter;
import lombok.experimental.Accessors;

/*
 * 设备状态栏
 */
@Accessors(chain = true)
public class EquipmentStatusBar extends LinearLayout implements MemoryCacheManager.OnCacheChangedListener,
        SimpleWifiConnectReceiver.OnWifiConnectChangeListener,
        SimpleBluetoothConnectReceiver.OnBluetoothConnectChangeListener,
        DeviceRemoteLockStore.Listener,
        CameraRecordStateStore.Listener {

    private static final String TAG = LogTAGConstant.EquipmentStatusBar;
    private EquipmentStatusBarBinding binding;
    private EquipmentStatus equipmentStatus;
    private final Handler handler = new Handler(Looper.getMainLooper());
    @Setter
    private OnCallBackListener onCallBackListener;
    private Context currContext;

    private SimpleWifiConnectReceiver wifiReceiver;
    private SimpleBluetoothConnectReceiver bluetoothReceiver;
    /**
     * 设备状态
     */
    private DeviceStatus deviceStatus;

    private static final Integer DEFAULT_MODEL_TYPE = ModelConstant.CONTINUOUS_WELDING;

    private SimpleDateFormat statusBarTimeFormat;
    private final TimeGlobalManager.TimeUpdateListener timeUpdateListener = this::updateStatusBarTime;

    public EquipmentStatusBar(Context context) {
        super(context);
        initView(context);
    }

    public EquipmentStatusBar(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        initView(context);
        attrsHandler(context, attrs);
    }

    public EquipmentStatusBar(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        initView(context);
        attrsHandler(context, attrs);
    }

    public void initView(Context context) {
        this.currContext = context;
        binding = EquipmentStatusBarBinding.inflate(LayoutInflater.from(context), this, true);

        this.equipmentStatus = createInitEquipmentStatus();
        binding.setStatus(equipmentStatus);
        binding.setModelType(DEFAULT_MODEL_TYPE);
        binding.setCallBackHomeEnabled(Boolean.TRUE);
        applyCallBackHomeVisualState(true);

        binding.statusCallBackHome.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            if (onCallBackListener != null) {
                onCallBackListener.onCallBack();
            }
        });
        binding.bluetoothContent.setOnClickListener(v -> {
            Log.d(TAG, "点击蓝牙");
        });
        binding.wifiContent.setOnClickListener(v -> {
            Log.d(TAG, "点击WiFi");
        });
        DeviceRemoteLockStore.addListener(this);
        CameraRecordStateStore.addListener(this);
        refreshRemoteLockIcon();
        refreshRecordingIndicator();
    }

    private void refreshRecordingIndicator() {
        if (binding == null || binding.recordingIndicator == null) {
            return;
        }
        binding.recordingIndicator.setVisibility(
                CameraRecordStateStore.isRecording() ? View.VISIBLE : View.GONE);
    }

    @Override
    public void onRecordingChanged(boolean recording) {
        handler.post(() -> {
            if (binding == null || binding.recordingIndicator == null) {
                return;
            }
            binding.recordingIndicator.setVisibility(recording ? View.VISIBLE : View.GONE);
        });
    }

    private void refreshRemoteLockIcon() {
        if (binding == null || binding.remoteLockIcon == null) {
            return;
        }
        binding.remoteLockIcon.setVisibility(DeviceRemoteLockStore.isLocked() ? View.VISIBLE : View.GONE);
    }

    @Override
    public void onRemoteLockChanged(boolean locked) {
        handler.post(this::refreshRemoteLockIcon);
    }

    private void initData() {
        deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus == null) {
            deviceStatus = new DeviceStatus();
        } else {
            deviceStatus = deviceStatus.clone();
        }
        // 4. 将填充好数据的实体类设置到组件，自动刷新UI
        binding.setStatus(equipmentStatus);
        binding.setDeviceStatus(deviceStatus);
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
    }

    public void updateTitle(String title) {
        if (binding == null || binding.statusTitle == null) {
            return;
        }
        binding.statusTitle.setText(title);
    }

    public void setCallBackHomeText(int textResId) {
        if (binding == null || binding.statusCallBackHome == null) {
            return;
        }
        // Icon-only back control; keep contentDescription for accessibility.
        if (textResId != 0) {
            binding.statusCallBackHome.setContentDescription(getContext().getString(textResId));
        }
    }

    /**
     * 解析参数
     *
     * @param context
     * @param attrs
     */
    private void attrsHandler(Context context, @Nullable AttributeSet attrs) {
        TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.EquipmentStatusBarAttrs);
        // 自定义的属性xml
        boolean useTitle = typedArray.getBoolean(R.styleable.EquipmentStatusBarAttrs_use_title, false);
        if (useTitle) {
            binding.titleContent.setVisibility(View.VISIBLE);
            int titleId = typedArray.getResourceId(R.styleable.EquipmentStatusBarAttrs_bar_title, -1);
            if (titleId != -1) {
                binding.statusTitle.setText(titleId);
            }
        } else {
            binding.titleContent.setVisibility(View.GONE);
        }
        // 使用状态
        boolean useStatus = typedArray.getBoolean(R.styleable.EquipmentStatusBarAttrs_use_status, false);
        binding.statusContent.setVisibility(useStatus ? View.VISIBLE : View.GONE);
        if (useStatus) {
            // 初始化状态
            initData();
        }
        /*连接状态显示*/
        boolean connect = typedArray.getBoolean(R.styleable.EquipmentStatusBarAttrs_use_connect, false);
        binding.wifiContent.setVisibility(connect ? View.GONE : View.VISIBLE);

        binding.bluetoothContent.setVisibility(View.GONE);
        boolean useCallback = typedArray.getBoolean(R.styleable.EquipmentStatusBarAttrs_use_callback, true);
        binding.callbackContent.setVisibility(useCallback ? View.VISIBLE : View.GONE);

        int backGround = typedArray.getColor(R.styleable.EquipmentStatusBarAttrs_bar_background_color, Color.TRANSPARENT);
        binding.equipmentStatusContent.setBackgroundColor(backGround);
        int modelType = typedArray.getInt(R.styleable.EquipmentStatusBarAttrs_model_type, DEFAULT_MODEL_TYPE);
        binding.setModelType(modelType);
        boolean callBackHomeEnabled = typedArray.getBoolean(
                R.styleable.EquipmentStatusBarAttrs_call_back_home_enabled, true);
        setCall_back_home_enabled(callBackHomeEnabled);
        // 回收typedArray
        typedArray.recycle();
    }

    public void setModel_type(int modelType) {
        if (binding == null) {
            return;
        }
        binding.setModelType(modelType);
    }

    public void setCall_back_home_enabled(boolean enabled) {
        if (binding == null) {
            return;
        }
        binding.setCallBackHomeEnabled(enabled);
        applyCallBackHomeVisualState(enabled);
    }

    private void applyCallBackHomeVisualState(boolean enabled) {
        if (binding == null || binding.statusCallBackHome == null) {
            return;
        }
        int color = ContextCompat.getColor(getContext(),
                enabled ? R.color.white : R.color.side_tab_not_active_color);
        binding.statusCallBackHome.setImageTintList(ColorStateList.valueOf(color));
    }

    /**
     * 更新状态
     *
     * @param equipmentStatus
     */
    public void setEquipmentStatus(EquipmentStatus equipmentStatus) {
        this.equipmentStatus = equipmentStatus;
        if (binding == null) {
            return;
        }
        binding.setStatus(equipmentStatus);
    }

    /**
     * 获取初始化的设备状态
     *
     * @return
     */
    public EquipmentStatus createInitEquipmentStatus() {
        EquipmentStatus init = new EquipmentStatus();
        String wifiName = SystemSettingUtils.getConnectedWifiName(getContext());
        SystemSettingUtils.is4GConnected(getContext());
        // 网络状态
        initWifi();
        init.setNetworkConnected((!StringUtils.isEmpty(wifiName) && !wifiName.equals("<unknown ssid>")) || SystemSettingUtils.is4GConnected(getContext()));
        // 蓝牙状态
        init.setBluetoothConnected(initBluetooth());
        return init;
    }


    /*注册wifi监听*/
    private void initWifi() {
        // 1. 初始化接收器（仅监听连接/未连接）
        wifiReceiver = new SimpleWifiConnectReceiver(this);

        // 2. 动态注册广播（仅监听网络连接状态）
        IntentFilter filter = new IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION);
        getContext().registerReceiver(wifiReceiver, filter);
    }

    private boolean initBluetooth() {
        requestBluetoothPermission();
        // 2. 初始化蓝牙接收器
        bluetoothReceiver = new SimpleBluetoothConnectReceiver(this);

        // 3. 动态注册广播（必须动态注册，静态注册无效）
        IntentFilter filter = new IntentFilter();
        filter.addAction(BluetoothDevice.ACTION_ACL_CONNECTED); // 设备连接
        filter.addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED); // 设备断开
        filter.addAction(BluetoothAdapter.ACTION_STATE_CHANGED); // 蓝牙开关状态
        getContext().registerReceiver(bluetoothReceiver, filter);

        // 4. 主动获取当前蓝牙状态（避免首次无回调）
        return bluetoothReceiver.getCurrentBluetoothState(getContext());
    }

    private void requestBluetoothPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (getContext().checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions((Activity) currContext, new String[]{Manifest.permission.BLUETOOTH_CONNECT}, 1001);
            }
        }
    }

    public void updateData() {
        DeviceStatus cacheData = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
//        if (cacheData!=null){
//            Log.d(TAG, "枪头通信: "+deviceStatus.isGunCommunicationAlarm());
//            Log.d(TAG, "激光器: "+deviceStatus.isLaserCommunicationAlarm());
//            Log.d(TAG, "送丝机: "+deviceStatus.isWireFeederCommunicationAlarm());
//        }
//        if (cacheData != null) {
//            Log.d(TAG, "枪状态:" + cacheData.gunStatus());
//            Log.d(TAG, "安全地锁导通:" + cacheData.isSafetyGroundLockLocked());
//            Log.d(TAG, "通气状态:" + cacheData.isAirValveOn());
//            Log.d(TAG, "急停状态:" + cacheData.isEmergencyStopTriggered());
//            Log.d(TAG, "送丝: "+ cacheData.isWireFeedingOn());
//            Log.d(TAG, "红光状态:" + cacheData.isRedLightOn());
//            Log.d(TAG, "激光状态:" + cacheData.isLaserOn());
//            Log.d(TAG, "钥匙开关状态:" + cacheData.isKeySwitchOn());
//            Log.d(TAG, "安全门状态:" + cacheData.isSafetyDoorClosed());
//            Log.d(TAG, "枪头开关:" + cacheData.isGunSwitchOn());
//        }
        if (deviceStatus != null && !this.deviceStatus.dataChange(cacheData)) {
            // 没有变化
//            Log.d(TAG, "状态未变化,原始的："+ GsonUtils.toJson(this.deviceStatus)+",新的:"+GsonUtils.toJson(cacheData));
//            Log.d(TAG, "内存地址:"+this.deviceStatus.hashCode()+","+cacheData.hashCode());
            return;
        }
//        Log.d(TAG, "正在更新状态栏数据:"+cacheData);
        DeviceStatus copyData = cacheData.clone();
        handler.post(() -> {
            if (binding == null) {
                return;
            }
            this.deviceStatus = copyData;
            binding.setDeviceStatus(copyData);
        });
//        binding.setStatus(this.equipmentStatus);
    }

    @Override
    public void onCacheChanged(String key) {
        updateData();
    }

    private void updateStatusBarTime(long currentTime) {
        if (binding == null || binding.statusBarTime == null) {
            return;
        }
        handler.post(() -> {
            if (binding == null || binding.statusBarTime == null) {
                return;
            }
            if (statusBarTimeFormat == null) {
                statusBarTimeFormat = new SimpleDateFormat("HH:mm", Locale.getDefault());
            }
            binding.statusBarTime.setText(statusBarTimeFormat.format(new Date(currentTime)));
        });
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        TimeGlobalManager.getInstance().addTimeUpdateListener(timeUpdateListener);
    }

    @Override
    protected void onDetachedFromWindow() {
        TimeGlobalManager.getInstance().removeTimeUpdateListener(timeUpdateListener);
        handler.removeCallbacksAndMessages(null);
        super.onDetachedFromWindow();
        if (!isHostActivityDestroying()) {
            return;
        }
        releaseResources();
    }

    private boolean isHostActivityDestroying() {
        Context context = getContext();
        while (context instanceof ContextWrapper wrapper) {
            if (context instanceof Activity activity) {
                if (activity.isFinishing()) {
                    return true;
                }
                return Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1 && activity.isDestroyed();
            }
            context = wrapper.getBaseContext();
        }
        return true;
    }

    private void releaseResources() {
        Log.d(TAG, "onDetachedFromWindow: 正在回收状态栏====>");
        DeviceRemoteLockStore.removeListener(this);
        CameraRecordStateStore.removeListener(this);
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
        if (wifiReceiver != null) {
            getContext().unregisterReceiver(wifiReceiver);
        }
        if (bluetoothReceiver != null) {
            getContext().unregisterReceiver(bluetoothReceiver);
        }
        if (binding != null) {
            binding.unbind();
            binding = null;
        }
        wifiReceiver = null;
        bluetoothReceiver = null;
        onCallBackListener = null;
        currContext = null;
    }

    /*wifi监听状态回调*/
    @Override
    public void onWifiConnectStateChanged(boolean isConnected, Integer level) {
        equipmentStatus.setNetworkConnected(isConnected);
        Integer value = 0;
        switch (level) {
            case 0:
                value = R.mipmap.wifi_off;
            case 1:
                value = R.mipmap.wifi_icon_2;
            case 2:
                value = R.mipmap.wifi_icon_1;
            case 3:
                value = R.mipmap.wifi_icon;
            case 4:
                value = R.mipmap.wifi_icon;
            default:
                value = R.mipmap.wifi_icon;
        }
        if (binding == null) {
            return;
        }
        binding.wifiContentIcon.setImageResource(value);
        binding.setStatus(equipmentStatus);
    }

    @Override
    public void onBluetoothConnectStateChanged(boolean isConnected) {
        equipmentStatus.setBluetoothConnected(isConnected);
        if (binding == null) {
            return;
        }
        binding.setStatus(equipmentStatus);
    }

    public interface OnCallBackListener {
        void onCallBack();
    }
}
