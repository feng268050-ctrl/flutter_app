package com.lasercyber.lws.ui.activitys.engineer.mode;

import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;
import androidx.viewpager2.widget.ViewPager2;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.activitys.engineer.mode.adapter.EngineerModeFragmentPagerAdapter;
import com.lasercyber.lws.ui.activitys.engineer.mode.fragment.EngineerCuttingFragment;
import com.lasercyber.lws.ui.activitys.engineer.mode.fragment.EngineerWashFragment;
import com.lasercyber.lws.ui.activitys.engineer.mode.fragment.EngineerWeldingFragment;
import com.lasercyber.lws.ui.activitys.engineer.mode.listener.SendProcessParametersDataListener;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.CommonUseConsumableViewModel;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.StaticDataViewModel;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.EngineerModeCheck;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserEnableAlarmGuard;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.EngineerToggleButtonChrome;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserEnableLongPressTouchHelper;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserWorkGuard;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.OperationDialogBuilder;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.ProcessModelConvert;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.ReminderExactBuilder;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.SafetyGroundLockPrompt;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.WorkStatusDialogBuilder;
import com.lasercyber.lws.ui.component.dialog.MachineStatusOverlayPreloader;
import com.lasercyber.lws.ui.bean.entity.DeviceControlData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.WorkModel;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockPolicy;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockStore;
import com.lasercyber.lws.ui.common.enums.TimingJobType;
import com.lasercyber.lws.ui.common.handler.GpioLedHandler;
import com.lasercyber.lws.ui.common.gpio.LaserEnableStateHolder;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.task.TimingJobTaskManager;
import com.lasercyber.lws.ui.common.camera.LivePr1InferenceStreamCoordinator;
import com.lasercyber.lws.ui.common.weld.WeldModeHost;
import com.lasercyber.lws.ui.common.utils.DeviceControlUtils;
import com.lasercyber.lws.ui.common.utils.ManualWireButtonTouchHelper;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.CameraController;
import com.lasercyber.lws.ui.databinding.ActivityEngineerModeBinding;
import com.lasercyber.lws.ui.databinding.EngineerContinuousDeviceControlsBinding;

import java.util.ArrayList;
import java.util.Date;
import java.util.Objects;

import cn.hutool.core.date.DateUnit;
import cn.hutool.core.date.DateUtil;

/**
 * 工程师模式
 */
public class EngineerModeActivity extends BaseActivity<ActivityEngineerModeBinding>
        implements MemoryCacheManager.OnCacheChangedListener, WeldModeHost, LaserWorkGuard.Host {
    private static final String TAG = LogTAGConstant.EngineerModeActivity;
    public static final String EXTRA_QUICK_MODE_PROCESS_TYPE = "extra_quick_mode_process_type";
    public static final String EXTRA_QUICK_MODE_SOURCE_ROW_ID = "extra_quick_mode_source_row_id";
    private EngineerModeFragmentPagerAdapter adapter;
    /**
     * 控制设备的数据
     */
    private DeviceControlData deviceControlData;
    private static final int MODE_SWITCH_DELAY_MILLIS = 500;
    private ManualWireButtonTouchHelper wireButtonTouchHelper;
    private LaserEnableLongPressTouchHelper laserEnableTouchHelper;
    private final android.util.SparseArray<EngineerContinuousDeviceControlsBinding> deviceControlsByType =
            new android.util.SparseArray<>();
    private final android.util.SparseArray<LaserEnableLongPressTouchHelper> deviceLaserHelpers =
            new android.util.SparseArray<>();
    private boolean isContinuousFeed;
    private boolean startFeedClick;
    private boolean startRetractClick;
    /** Shared by the five tab-local CameraController instances. */
    private boolean engineerRecordWorkArmed;
    private boolean suppressRecordWorkSync;

    /**
     * 持续送丝
     */
//    private boolean isContinuousFeed = false;
    private StaticDataViewModel staticDataViewModel;
    /**
     * 开始出激光时间
     */
    private Date startLaserTime;
    // 上一次是否开启了枪
    private boolean lastIsGunSwitchOn=false;
    private CommonUseConsumableViewModel commonUseConsumableViewModel;
    private final LivePr1InferenceStreamCoordinator livePr1InferenceCoordinator =
            new LivePr1InferenceStreamCoordinator();
    @Nullable
    private Long pendingQuickModeSourceRowId;
    @Nullable
    private Integer pendingQuickModeProcessType;
    private boolean enteredFromQuickMode;
    /** Legacy latch flag; Retreat is hold-to-run and should stay false. */
    private boolean continuousRetractLatched;

    @Override
    protected void initView() {
        readQuickModeEntryIntent();
        updateBackNavigationLabel();
        continuousRetractLatched = false;
        isContinuousFeed = false;
        startFeedClick = false;
        startRetractClick = false;
        binding.engineerTab.setSwitchTabListener((activeType, index) -> {
            GlobalSoundManager.playClickSound();
            // 切换模式
            selectModel(activeType);
            // 只有相邻的页面切换才平滑切换
            binding.engineerModePageContent.setCurrentItem(index, Math.abs(binding.engineerModePageContent.getCurrentItem() - index) == 1);
        });
        binding.engineerEquipmentStatus.setOnCallBackListener(()->{
            // 关闭激光
            switchLaserEnable(false,true);
            if (resolveCameraController() != null) {
                // 停止录制
                boolean stopRecord = resolveCameraController().tryStopRecord(this::finish);
                if (!stopRecord) {
                    finish();
                }
            } else {
                finish();
            }
        });
        // 初始化按钮事件
        initClickEvent();
        // 初始化Fragment
        initFragment();
        // 初始化 Record Working
        initCameraController();
    }

    /**
     * 选择模式
     *
     * @param activeType
     */
    private void selectModel(int activeType) {
        closeContinuousFeed();
        closeContinuousRetract();
        // 缓存当前的模式
        MemoryCacheManager.getInstance().putSerializableNoNotice(CacheKey.ENGINEER_LAST_MODEL_KEY, activeType);
        binding.setActiveMode(activeType);
        syncBottomCheckboxesFromDevice();
        applyWireControlsEnabledForAll();
        notifyEngineerPageActivated(activeType);
        CameraController cameraController = resolveCameraController();
        if (cameraController != null) {
            // 停止录制
            cameraController.tryStopRecord(null);
            cameraController.setMode_type(activeType);
        }
        deviceControlData.setModel(activeType);
        LaserEnableStateHolder.setWorkModel(activeType);
        if (super.task != null) {
            handler.removeCallbacks(super.task);
        }
        super.task = () ->{
            Log.d(TAG, "正在将模式切换为："+activeType);
            ModbusManagerRtu.get().writeRegisters(ModbusFiledBuilder.createDeviceControlData(deviceControlData));
            // 关闭激光
            switchLaserEnable(false,false);
            // 下发工艺配置
            if (binding == null || adapter == null) {
                return;
            }
            try {
                Fragment fragment = adapter.createFragment(binding.engineerModePageContent.getCurrentItem());
                if (fragment instanceof SendProcessParametersDataListener sendProcessParametersDataListener) {
                    sendProcessParametersDataListener.sendData();
                }
            } catch (Exception exception) {
                Log.d(TAG, "selectModel: 切换模式时，下发配置异常", exception);
            }

        };
        handler.postDelayed(super.task, MODE_SWITCH_DELAY_MILLIS);
    }

    @Override
    protected void initData() {
        MemoryCacheManager.getInstance().putSerializableNoNotice(
                CacheKey.LAST_TOP_MODE_CONTEXT_KEY,
                Integer.valueOf(CacheKey.TOP_MODE_CONTEXT_ENGINEER));
        // 获取上一次的模式
        Integer defaultModelType = pendingQuickModeProcessType;
        if (defaultModelType == null) {
            defaultModelType = MemoryCacheManager.getInstance().getSerializable(CacheKey.ENGINEER_LAST_MODEL_KEY);
        }
        if (defaultModelType == null) {
            defaultModelType = ModelConstant.CONTINUOUS_WELDING;
        }
        binding.setActiveMode(defaultModelType);
        deviceControlData = new DeviceControlData();
        // 默认开启自动送丝
        deviceControlData.setAutoWireFeedEnable(1);
        deviceControlData.setModel(defaultModelType);
        LaserEnableStateHolder.setWorkModel(defaultModelType);
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus != null) {
            // 检测是否正在送丝
            if (deviceStatus.isWireFeedingOn()) {
                deviceControlData.setWireFeedEnable(1);
                deviceControlData.setWireFeedDirection(0);
                isContinuousFeed = false;
                syncContinuousFeedUi();
            }
        }
        // 初始化默认的页面
        int pageIndex = ProcessModelConvert.modelConstantConvertToPageIndex(defaultModelType);
        binding.engineerModePageContent.setCurrentItem(pageIndex, false);
        binding.engineerTab.setActiveType(defaultModelType);

        publishDeviceControlData();
        syncBottomCheckboxesFromDevice();
        ModbusManagerRtu.get().writeRegisters(ModbusFiledBuilder.createDeviceControlData(deviceControlData));
        // 下发控制
        ModbusManagerRtu.get().writeRegisters(ModbusFiledBuilder.createDeviceControlSwitchData(deviceControlData));
        staticDataViewModel = new ViewModelProvider(this).get(StaticDataViewModel.class);
        commonUseConsumableViewModel=new ViewModelProvider(this).get(CommonUseConsumableViewModel.class);
        staticDataViewModel.init(this);
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_DATA_KEY, this);
        LaserWorkGuard.register(this);
        livePr1InferenceCoordinator.attach(this);

    }

    private void readQuickModeEntryIntent() {
        if (getIntent() == null) {
            return;
        }
        if (!getIntent().hasExtra(EXTRA_QUICK_MODE_PROCESS_TYPE)
                || !getIntent().hasExtra(EXTRA_QUICK_MODE_SOURCE_ROW_ID)) {
            return;
        }
        int processType = getIntent().getIntExtra(EXTRA_QUICK_MODE_PROCESS_TYPE, -1);
        long sourceRowId = getIntent().getLongExtra(EXTRA_QUICK_MODE_SOURCE_ROW_ID, -1L);
        if (processType < ModelConstant.CONTINUOUS_WELDING || processType > ModelConstant.HAND_CUT
                || sourceRowId <= 0L) {
            return;
        }
        pendingQuickModeProcessType = processType;
        pendingQuickModeSourceRowId = sourceRowId;
        enteredFromQuickMode = true;
    }

    private void updateBackNavigationLabel() {
        int labelRes = enteredFromQuickMode
                ? R.string.call_back_to_quick_mode
                : R.string.call_back_to_home;
        binding.engineerEquipmentStatus.setCallBackHomeText(labelRes);
    }

    /**
     * 快速模式「更多参数」入口携带的快照，由对应工艺 Fragment 消费一次。
     */
    @Nullable
    public ProcessParametersData consumeQuickModeEntryFor(int processType) {
        if (pendingQuickModeSourceRowId == null || pendingQuickModeProcessType == null) {
            return null;
        }
        if (pendingQuickModeProcessType != processType) {
            return null;
        }
        ProcessParametersData placeholder = new ProcessParametersData();
        placeholder.setId(pendingQuickModeSourceRowId);
        pendingQuickModeSourceRowId = null;
        pendingQuickModeProcessType = null;
        return placeholder;
    }

    /**
     * 初始化Fragment
     */
    public void initFragment() {
        ArrayList<Fragment> fragments = new ArrayList<>();
        fragments.add(new EngineerWeldingFragment(ModelConstant.CONTINUOUS_WELDING));
        fragments.add(new EngineerWeldingFragment(ModelConstant.POINT_WELDING));
        fragments.add(new EngineerWashFragment(ModelConstant.WELD_CLEAN));
        fragments.add(new EngineerWashFragment(ModelConstant.WIDTH_CLEAN));
        fragments.add(new EngineerCuttingFragment(ModelConstant.HAND_CUT));
        adapter = new EngineerModeFragmentPagerAdapter(this, fragments);
        for (Fragment fragment : fragments) {
            if (fragment instanceof SendProcessParametersDataListener listener) {
                listener.setEngineerPageActiveListener(pageType -> binding.getActiveMode() == pageType);
            }
        }
        binding.engineerModePageContent.setAdapter(adapter);
        binding.engineerModePageContent.setOffscreenPageLimit(4);
        binding.engineerModePageContent.setUserInputEnabled(false);
        binding.engineerModePageContent.setOrientation(ViewPager2.ORIENTATION_HORIZONTAL);

        binding.engineerModePageContent.registerOnPageChangeCallback(new ViewPager2.OnPageChangeCallback() {
            @Override
            public void onPageSelected(int position) {
                super.onPageSelected(position);
                Log.d(TAG, "onPageSelected: 模式内容页面:" + position);
                binding.engineerTab.setActiveType(position);
                int modelType = ProcessModelConvert.pageIndexConvertToModelConstant(position);
                selectModel(modelType);
//                binding.engineerModePageContent.updateChange(position);
            }
        });
    }

    @Override
    protected int getLayoutId() {
        return R.layout.activity_engineer_mode;
    }

    /**
     * 初始化事件
     */
    public void initClickEvent() {
        applyEngineerToggleChrome(binding.btnLaserEnable);
        binding.btnManualGas.setOnCheckedChangeListener((checkbox, isChecked) -> {
            if (suppressBottomCheckboxCallback) {
                return;
            }
            applyManualGasChecked(isChecked);
        });
        laserEnableTouchHelper = new LaserEnableLongPressTouchHelper(binding.btnLaserEnable, createLaserEnableTouchHost());
        laserEnableTouchHelper.attach();
    }

    /**
     * 各 Tab 共用左侧六控件面板；连续焊启用送丝相关控件，其余 Tab 灰显禁用。
     */
    public void attachDeviceControls(
            int processType,
            @NonNull EngineerContinuousDeviceControlsBinding panel) {
        deviceControlsByType.put(processType, panel);
        boolean wireEnabled = processType == ModelConstant.CONTINUOUS_WELDING;
        boolean showRamp = processType == ModelConstant.CONTINUOUS_WELDING
                || processType == ModelConstant.POINT_WELDING;
        panel.setDeviceControlData(deviceControlData);
        panel.setIsContinuousFeed(wireEnabled && isContinuousFeed);
        panel.setStartFeedClick(wireEnabled && startFeedClick);
        panel.setStartRetractClick(wireEnabled && startRetractClick);
        panel.setShowRampAccordion(showRamp);
        panel.setWireControlsEnabled(wireEnabled);
        applyEngineerToggleChrome(panel.btnLaserEnable);
        panel.btnManualGas.setOnCheckedChangeListener((checkbox, isChecked) -> {
            if (suppressBottomCheckboxCallback) {
                return;
            }
            applyManualGasChecked(isChecked);
        });
        panel.btnFeedEnable.setOnCheckedChangeListener((checkbox, isChecked) -> {
            if (suppressBottomCheckboxCallback || !isWireControlsEnabledFor(processType)) {
                return;
            }
            applyFeedEnableChecked(isChecked);
        });
        panel.rowManualGas.setOnClickListener(v -> {
            if (panel.btnManualGas.isEnabled()) {
                panel.btnManualGas.toggle();
            }
        });
        panel.rowFeedEnable.setOnClickListener(v -> {
            if (panel.btnFeedEnable.isEnabled()) {
                panel.btnFeedEnable.toggle();
            }
        });
        panel.rowRecordWork.setOnClickListener(v -> {
            if (panel.cameraController != null) {
                panel.cameraController.toggleRecordWorkingArmed();
            }
        });
        if (wireEnabled) {
            if (wireButtonTouchHelper != null) {
                wireButtonTouchHelper.release();
            }
            wireButtonTouchHelper = new ManualWireButtonTouchHelper(panel.btnFeed, createWireButtonHost());
            wireButtonTouchHelper.attachFeedButton(panel.btnFeed);
            wireButtonTouchHelper.attachRetractButton(panel.btnRetract);
        }
        LaserEnableLongPressTouchHelper existing = deviceLaserHelpers.get(processType);
        if (existing != null) {
            existing.release();
        }
        LaserEnableLongPressTouchHelper helper =
                new LaserEnableLongPressTouchHelper(panel.btnLaserEnable, createLaserEnableTouchHost());
        helper.attach();
        deviceLaserHelpers.put(processType, helper);
        if (panel.cameraController != null) {
            CameraController cameraController = panel.cameraController;
            cameraController.setOnRecordWorkingArmedChangeListener(
                    armed -> syncEngineerRecordWorkArmed(cameraController, armed));
            suppressRecordWorkSync = true;
            try {
                cameraController.setRecordWorkingArmed(engineerRecordWorkArmed);
            } finally {
                suppressRecordWorkSync = false;
            }
            cameraController.setMode_type(processType);
            cameraController.setCameraControllerListener(() -> {
                if (adapter == null || binding == null) {
                    return null;
                }
                Fragment fragment = adapter.createFragment(binding.engineerModePageContent.getCurrentItem());
                if (fragment instanceof SendProcessParametersDataListener sendProcessParametersDataListener) {
                    return sendProcessParametersDataListener.getProcessParametersData();
                }
                return null;
            });
        }
        syncBottomCheckboxesFromDevice();
        setLaserButtonsEnabled(deviceControlData == null || !deviceControlData.isOpenManualGas());
    }

    private void syncEngineerRecordWorkArmed(
            @NonNull CameraController source, boolean armed) {
        if (suppressRecordWorkSync) {
            return;
        }
        engineerRecordWorkArmed = armed;
        suppressRecordWorkSync = true;
        try {
            for (int i = 0; i < deviceControlsByType.size(); i++) {
                EngineerContinuousDeviceControlsBinding panel = deviceControlsByType.valueAt(i);
                if (panel == null || panel.cameraController == null
                        || panel.cameraController == source) {
                    continue;
                }
                panel.cameraController.setRecordWorkingArmed(armed);
            }
        } finally {
            suppressRecordWorkSync = false;
        }
    }

    private boolean isWireControlsEnabledFor(int processType) {
        return processType == ModelConstant.CONTINUOUS_WELDING;
    }

    private boolean isActiveWireControlsEnabled() {
        Integer active = binding != null ? binding.getActiveMode() : null;
        return active != null && isWireControlsEnabledFor(active);
    }

    private void applyWireControlsEnabledForAll() {
        for (int i = 0; i < deviceControlsByType.size(); i++) {
            int processType = deviceControlsByType.keyAt(i);
            EngineerContinuousDeviceControlsBinding panel = deviceControlsByType.valueAt(i);
            if (panel == null) {
                continue;
            }
            boolean wireEnabled = isWireControlsEnabledFor(processType);
            panel.setWireControlsEnabled(wireEnabled);
            panel.btnFeedEnable.setEnabled(wireEnabled);
            panel.btnRetract.setEnabled(wireEnabled);
            panel.btnFeed.setEnabled(wireEnabled);
            if (!wireEnabled) {
                panel.btnFeedEnable.setChecked(false);
                panel.setIsContinuousFeed(false);
                panel.setStartFeedClick(false);
                panel.setStartRetractClick(false);
            }
        }
    }

    private boolean suppressBottomCheckboxCallback;

    private void syncBottomCheckboxesFromDevice() {
        if (deviceControlData == null) {
            return;
        }
        suppressBottomCheckboxCallback = true;
        try {
            boolean manualGas = deviceControlData.isOpenManualGas();
            boolean autoWire = deviceControlData.isOpenAutoWireFeed();
            if (binding != null && binding.btnManualGas != null) {
                binding.btnManualGas.setChecked(manualGas);
            }
            for (int i = 0; i < deviceControlsByType.size(); i++) {
                int processType = deviceControlsByType.keyAt(i);
                EngineerContinuousDeviceControlsBinding panel = deviceControlsByType.valueAt(i);
                if (panel == null) {
                    continue;
                }
                panel.btnManualGas.setChecked(manualGas);
                // 非连续焊：送丝使能不可用，强制不勾选（避免沿用连续焊状态）
                panel.btnFeedEnable.setChecked(
                        isWireControlsEnabledFor(processType) && autoWire);
                panel.setDeviceControlData(deviceControlData);
            }
        } finally {
            suppressBottomCheckboxCallback = false;
        }
    }

    @Nullable
    private CameraController resolveCameraController() {
        Integer activeMode = binding != null ? binding.getActiveMode() : null;
        if (activeMode == null) {
            return binding != null ? binding.cameraController : null;
        }
        EngineerContinuousDeviceControlsBinding panel = deviceControlsByType.get(activeMode);
        if (panel != null && panel.cameraController != null) {
            return panel.cameraController;
        }
        return binding != null ? binding.cameraController : null;
    }

    private void syncContinuousFeedUi() {
        EngineerContinuousDeviceControlsBinding continuous =
                deviceControlsByType.get(ModelConstant.CONTINUOUS_WELDING);
        if (continuous == null) {
            return;
        }
        continuous.setIsContinuousFeed(isContinuousFeed);
        continuous.setStartFeedClick(startFeedClick);
        continuous.setStartRetractClick(startRetractClick);
    }

    private void setLaserButtonsEnabled(boolean enabled) {
        if (binding != null && binding.btnLaserEnable != null) {
            binding.btnLaserEnable.setEnabled(enabled);
        }
        for (int i = 0; i < deviceControlsByType.size(); i++) {
            EngineerContinuousDeviceControlsBinding panel = deviceControlsByType.valueAt(i);
            if (panel != null && panel.btnLaserEnable != null) {
                panel.btnLaserEnable.setEnabled(enabled);
            }
        }
    }

    private void publishDeviceControlData() {
        if (binding != null) {
            binding.setDeviceControlData(deviceControlData);
        }
        for (int i = 0; i < deviceControlsByType.size(); i++) {
            EngineerContinuousDeviceControlsBinding panel = deviceControlsByType.valueAt(i);
            if (panel != null) {
                panel.setDeviceControlData(deviceControlData);
            }
        }
    }

    private void applyEngineerToggleChrome(android.view.View button) {
        EngineerToggleButtonChrome.apply(button);
    }

    private LaserEnableLongPressTouchHelper.Host createLaserEnableTouchHost() {
        return new LaserEnableLongPressTouchHelper.Host() {
            @Override
            public boolean isLaserOpen() {
                return deviceControlData != null && deviceControlData.isOpenLaser();
            }

            @Override
            public boolean passesLaserEnablePreflight() {
                DeviceStatus deviceStatus = MemoryCacheManager.getInstance()
                        .getSerializable(CacheKey.DEVICE_STATUS_KEY);
                return EngineerModeCheck.passesWorkStatusForLaserEnable(
                        EngineerModeActivity.this, deviceStatus);
            }

            @Override
            public void onLaserDisableClick() {
                disableLaserEnable();
            }

            @Override
            public void onLaserEnableConfirmed() {
                requestLaserEnable();
            }
        };
    }

    private ManualWireButtonTouchHelper.Host createWireButtonHost() {
        return new ManualWireButtonTouchHelper.Host() {
            @Override
            public android.os.Handler getHandler() {
                return handler;
            }

            @Override
            public boolean isContinuousFeed() {
                return isContinuousFeed;
            }

            @Override
            public void setContinuousFeed(boolean continuous) {
                isContinuousFeed = continuous;
                syncContinuousFeedUi();
            }

            @Override
            public void setStartFeedClick(boolean start) {
                startFeedClick = start;
                syncContinuousFeedUi();
            }

            @Override
            public boolean isContinuousRetract() {
                return continuousRetractLatched;
            }

            @Override
            public void setContinuousRetract(boolean continuous) {
                continuousRetractLatched = continuous;
            }

            @Override
            public void setStartRetractClick(boolean start) {
                startRetractClick = start;
                syncContinuousFeedUi();
            }

            @Override
            public void cancelPulseCloseTask() {
                if (task != null) {
                    handler.removeCallbacks(task);
                    task = null;
                }
            }

            @Override
            public void schedulePulseClose(Runnable closeTask) {
                task = closeTask;
                handler.postDelayed(task, ManualWireButtonTouchHelper.PULSE_CLOSE_DELAY_MS);
            }

            @Override
            public void openFeed(ModbusManagerRtu.WriteCallback callback) {
                EngineerModeActivity.this.openFeed(callback);
            }

            @Override
            public void closeFeedOrBack(ModbusManagerRtu.WriteCallback callback) {
                EngineerModeActivity.this.closeFeedOrBack(callback);
            }

            @Override
            public boolean openBackFeed(ModbusManagerRtu.WriteCallback callback) {
                return EngineerModeActivity.this.openBackFeed(callback);
            }

            @Override
            public void onContinuousFeedEntered() {
                ToastUtils.showShort(R.string.feed_ongoing_text);
            }

            @Override
            public void onContinuousFeedStopped() {
                ToastUtils.showShort(R.string.silk_feed_ends);
            }

            @Override
            public void onContinuousRetractEntered() {
                // no-op: Retreat does not latch
            }

            @Override
            public void onContinuousRetractStopped() {
                // no-op: Retreat does not latch
            }

            @Override
            public void onFeedPulseSuccess() {
                ToastUtils.showShort(R.string.silk_feed_successful);
            }

            @Override
            public void onFeedPulseFailure() {
                ToastUtils.showShort(R.string.operation_failed_text);
            }

            @Override
            public void onRetractPulseSuccess() {
                ToastUtils.showShort(R.string.successful_retreat);
            }

            @Override
            public void onFeedHoldReleased() {
                ToastUtils.showShort(R.string.silk_feed_successful);
            }

            @Override
            public void onRetractHoldReleased() {
                ToastUtils.showShort(R.string.retreat_ends);
            }

            @Override
            public void onRetractPulseFailure() {
                ToastUtils.showShort(R.string.operation_failed_text);
            }

            @Override
            public void playClickSound() {
                GlobalSoundManager.playClickSound();
            }

            @Override
            public void beforeFeedAction() {
                closeContinuousFeed();
                closeContinuousRetract();
                closeLaserEnableStatus();
            }

            @Override
            public void beforeRetractAction() {
                closeContinuousFeed();
                closeContinuousRetract();
                closeLaserEnableStatus();
            }
        };
    }

    /**
     * 送丝使能（Checkbox）
     */
    private void applyFeedEnableChecked(boolean wantEnabled) {
        if (deviceControlData == null || !isActiveWireControlsEnabled()) {
            return;
        }
        if (wantEnabled == deviceControlData.isOpenAutoWireFeed()) {
            return;
        }
        GlobalSoundManager.playClickSound();
        closeContinuousFeed();
        closeContinuousRetract();
        int orangeData = deviceControlData.getAutoWireFeedEnable();
        deviceControlData.setAutoWireFeedEnable(wantEnabled ? 1 : 0);
        publishDeviceControlData();
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlSwitchData(deviceControlData), new ModbusManagerRtu.WriteCallback() {
            @Override
            public void onSuccess() {
                ToastUtils.showShort(deviceControlData.isOpenAutoWireFeed()?R.string.wire_feed_enable_successful:R.string.wire_feed_successfully_closed);
            }

            @Override
            public void onFailure() {
                ToastUtils.showShort(R.string.operation_failed_text);
                deviceControlData.setAutoWireFeedEnable(orangeData);
                handler.post(() -> {
                    if (binding==null){
                        return;
                    }
                    publishDeviceControlData();
                    syncBottomCheckboxesFromDevice();
                });
            }
        });
    }

    /**
     * 送丝使能遗留入口（已改 Checkbox）
     */
    public void feedEnableClick(View view) {
        applyFeedEnableChecked(!deviceControlData.isOpenAutoWireFeed());
    }

    /**
     * 开始送丝
     */
    public boolean openFeed(ModbusManagerRtu.WriteCallback writeCallback) {
        if (!isActiveWireControlsEnabled()) {
            return false;
        }
        Log.d(TAG, "下发送丝=====>");
        DeviceControlData openFeedConfig = DeviceControlUtils.createOpenFeedConfig(deviceControlData);
        openFeedConfig.setLaserStatus(deviceControlData.getLaserStatus());
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlSwitchData(openFeedConfig), writeCallback);
        return true;
    }

    /**
     * 结束送丝或者退丝
     */
    public void closeFeedOrBack(ModbusManagerRtu.WriteCallback writeCallback) {
        if (!isActiveWireControlsEnabled()) {
            return;
        }
        Log.d(TAG, "下结束退丝=====>");
        DeviceControlData openFeedConfig = DeviceControlUtils.createCloseFeedOrBackConfig(deviceControlData);
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlSwitchData(openFeedConfig),writeCallback);
    }

    /**
     * 开启退丝
     */
    public boolean openBackFeed(ModbusManagerRtu.WriteCallback writeCallback) {
        if (!isActiveWireControlsEnabled()) {
            return false;
        }
        Log.d(TAG, "下发送退丝=====>");
        DeviceControlData openFeedConfig = DeviceControlUtils.createBackFeedConfig(deviceControlData);
        openFeedConfig.setLaserStatus(deviceControlData.getLaserStatus());
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlSwitchData(openFeedConfig),writeCallback);
        return true;
    }

    /**
     * 手动送气（Checkbox）
     */
    private void applyManualGasChecked(boolean wantOpen) {
        if (deviceControlData == null) {
            return;
        }
        if (wantOpen == deviceControlData.isOpenManualGas()) {
            return;
        }
        GlobalSoundManager.playClickSound();
        closeContinuousFeed();
        closeContinuousRetract();
        DeviceControlData sendConfig;
        int orangeData = deviceControlData.getManualGas();
        if (wantOpen) {
            setLaserButtonsEnabled(false);
            deviceControlData.setManualGas(1);
            sendConfig = DeviceControlUtils.createOpenManualGasConfig();
        } else {
            deviceControlData.setManualGas(0);
            setLaserButtonsEnabled(true);
            sendConfig = DeviceControlUtils.createCloseManualGasConfig();
        }
        // 开启送气时，关闭激光
        closeLaserEnableStatus();
        publishDeviceControlData();
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlSwitchData(sendConfig), new ModbusManagerRtu.WriteCallback() {
            @Override
            public void onSuccess() {
                ToastUtils.showShort(deviceControlData.isOpenManualGas()?R.string.manual_gas_supply_successful:R.string.manual_gas_supply_successfully_shut_down);
            }

            @Override
            public void onFailure() {
                ToastUtils.showShort(R.string.operation_failed_text);
                deviceControlData.setManualGas(orangeData);
                handler.post(() -> {
                    if (binding==null){
                        return;
                    }
                    publishDeviceControlData();
                    syncBottomCheckboxesFromDevice();
                    setLaserButtonsEnabled(!deviceControlData.isOpenManualGas());
                });
            }
        });
    }

    /**
     * 手动送气遗留入口（已改 Checkbox）
     */
    public void manualGasClick(View view) {
        applyManualGasChecked(!deviceControlData.isOpenManualGas());
    }

    /**
     * 关闭激光使能（单击）。
     */
    private void disableLaserEnable() {
        closeContinuousFeed();
        closeContinuousRetract();
        switchLaserEnable(false, true);
    }

    /**
     * 长按确认后请求开启激光。
     */
    private void requestLaserEnable() {
        closeContinuousFeed();
        closeContinuousRetract();
        if (adapter == null || binding == null) {
            return;
        }
        Fragment fragment = adapter.createFragment(binding.engineerModePageContent.getCurrentItem());
        if (fragment instanceof SendProcessParametersDataListener sendProcessParametersDataListener) {
            if (!sendProcessParametersDataListener.paramsCheck()) {
                return;
            }
        }
        if (!EngineerModeCheck.enableLaser(deviceControlData.getModel(), this)) {
            return;
        }
        ReminderExactBuilder.openReminderExactDialog(this, WorkModel.ENGINEER_MODE,
                deviceControlData.getModel(), () -> {
                    Log.d(TAG, "onConfirmClick: 确认");
                    if (!EngineerModeCheck.enableLaser(deviceControlData.getModel(), EngineerModeActivity.this)) {
                        return;
                    }
                    switchLaserEnable(true, true);
                });
    }

    /**
     * 激光开启（保留供 DataBinding / 外部调用；实际触摸由 {@link LaserEnableLongPressTouchHelper} 处理）。
     */
    public void laserEnableClick(View view) {
        if (deviceControlData.isOpenLaser()) {
            disableLaserEnable();
        } else {
            requestLaserEnable();
        }
    }

    /**
     * 将激光使能的状态变为关闭状态
     */
    public void closeLaserEnableStatus(){
        if (!deviceControlData.isOpenLaser()){
            return;
        }
        deviceControlData.setLaserStatus(0);
        handler.post(()->{
            if (binding==null){
                return;
            }
            publishDeviceControlData();
            saveWorkTime();
            LaserEnableStateHolder.setActive(false);
            GpioLedHandler.refresh();
        });
    }
    /**
     * 切换激光使能
     *
     * @param isOpen
     */
    private void switchLaserEnable(boolean isOpen, boolean showToast) {
        switchLaserEnable(isOpen, showToast, null);
    }

    private void switchLaserEnable(boolean isOpen, boolean showToast, @Nullable Runnable onModbusSuccess) {
        if (!isOpen && deviceControlData != null && !deviceControlData.isOpenLaser()) {
            if (onModbusSuccess != null) {
                handler.post(onModbusSuccess);
            }
            return;
        }
        if (isOpen) {
            DeviceControlUtils.createOpenLaserConfig(deviceControlData);
            Fragment fragment = adapter.createFragment(binding.engineerModePageContent.getCurrentItem());
            if (fragment instanceof SendProcessParametersDataListener sendProcessParametersDataListener){
                sendProcessParametersDataListener.sendData();
                // 下发高级配置
                sendProcessParametersDataListener.sendAdvanceSettingData();
            }
        } else {
            saveWorkTime();
            DeviceControlUtils.createCloseLaserConfig(deviceControlData);
            Fragment fragment = adapter.createFragment(binding.engineerModePageContent.getCurrentItem());
            if (fragment instanceof SendProcessParametersDataListener sendProcessParametersDataListener){
                ProcessParametersData processParametersData = sendProcessParametersDataListener.getProcessParametersData();
                if (processParametersData!=null&&processParametersData.getMaterialType()!=null){
                    commonUseConsumableViewModel.addUpdateCommonUseConsumableNumer(processParametersData.getMaterialType(), this);
                }
            }
        }
        handler.post(() -> {
            if (binding==null){
                return;
            }
            publishDeviceControlData();
        });
        // 下发激光使能
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlSwitchData(deviceControlData),
                new ModbusManagerRtu.WriteCallback() {
                    @Override
                    public void onSuccess() {
                        if (deviceControlData.isOpenLaser()) {
                            // 点击 Laser Enable 成功后，结束 End-of-work 快照窗口。
                            MemoryCacheManager.getInstance().remove(
                                    CacheKey.LAST_END_WORK_MODEL_ENGINEER_KEY);
                        } else {
                            // 点击 End of work 成功后，记录当前工程师模式功能快照。
                            MemoryCacheManager.getInstance().putSerializableNoNotice(
                                    CacheKey.LAST_END_WORK_MODEL_ENGINEER_KEY,
                                    Integer.valueOf(deviceControlData.getModel()));
                        }
                        startLaserTime = new Date();
                        if (showToast){
                            ToastUtils.showShort(deviceControlData.isOpenLaser() ? R.string.open_laser_success : R.string.close_laser_success);
                        }
                        LaserEnableStateHolder.setActive(
                                deviceControlData.isOpenLaser(), deviceControlData.getModel());
                        GpioLedHandler.refresh();
                        if (deviceControlData.isOpenLaser()){
                            TimingJobTaskManager.getInstance().startTask( TimingJobType.JOB_TIME_LENGTH.name() );
                            DeviceStatus deviceStatus = MemoryCacheManager.getInstance()
                                    .getSerializable(CacheKey.DEVICE_STATUS_KEY);
                            SafetyGroundLockPrompt.maybeShow(EngineerModeActivity.this, deviceStatus, true);
                        }else {
                            SafetyGroundLockPrompt.reset();
                            // 关闭弹窗
                            handler.post(() -> WorkStatusDialogBuilder.closeDialogDelayMillis(EngineerModeActivity.this));
                        }
                        if (onModbusSuccess != null) {
                            handler.post(onModbusSuccess);
                        }
                    }

                    @Override
                    public void onFailure() {
                        if (showToast){
                            ToastUtils.showShort(R.string.operation_failed_text);
                        }
                        GpioLedHandler.refresh();
                        if (!isOpen && onModbusSuccess != null) {
                            handler.post(onModbusSuccess);
                        }
                    }
                });
    }

    /**
     * 保存工作时长
     */
    private void saveWorkTime() {
        if (startLaserTime==null){
            return;
        }
        long between = DateUtil.between(startLaserTime, new Date(), DateUnit.SECOND);
        // 重置时间
        startLaserTime=null;
        Fragment fragment = adapter.createFragment(binding.engineerModePageContent.getCurrentItem());
//                modelContentFragment.get(this.titleId);
        Double feedSpeed = 0d;
        if (fragment instanceof SendProcessParametersDataListener sendProcessParametersDataListener) {
            feedSpeed = sendProcessParametersDataListener.wireFeedSpeed();
        }
        if (feedSpeed == null) {
            feedSpeed = 0d;
        }
        staticDataViewModel.weldStopProxy(deviceControlData.getModel(), (int) between, feedSpeed.longValue(), EngineerModeActivity.this);
    }

    @Override
    protected void onResume() {
        super.onResume();
        MachineStatusOverlayPreloader.warmWhenIdle(this);
        if (DeviceRemoteLockStore.isLocked()) {
            exitForRemoteLock();
        }
    }

    /**
     * Remote lock: stop laser/work and return home without confirmation dialogs.
     */
    public void exitForRemoteLock() {
        switchLaserEnable(false, false);
        Runnable finishToHome = () -> {
            DeviceRemoteLockPolicy.navigateToHome(this);
            finish();
        };
        CameraController cameraController = resolveCameraController();
        if (cameraController != null) {
            boolean stopRecord = cameraController.tryStopRecord(finishToHome::run);
            if (!stopRecord) {
                finishToHome.run();
            }
        } else {
            finishToHome.run();
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (isFinishing()) {
            MemoryCacheManager.getInstance().putSerializableNoNotice(
                    CacheKey.LAST_TOP_MODE_CONTEXT_KEY,
                    Integer.valueOf(CacheKey.TOP_MODE_CONTEXT_ENGINEER));
        }
    }

    @Override
    public int getActiveWeldModelType() {
        if (binding != null && binding.getActiveMode() != null) {
            return binding.getActiveMode();
        }
        if (deviceControlData != null) {
            return deviceControlData.getModel();
        }
        return ModelConstant.CONTINUOUS_WELDING;
    }

    @Override
    public void exitWeldWorkForZeroPointSettings(@NonNull Runnable onDone) {
        switchLaserEnable(false, false, () -> finishAfterStopRecord(onDone));
    }

    private void finishAfterStopRecord(@NonNull Runnable onDone) {
        CameraController cameraController = resolveCameraController();
        if (cameraController != null) {
            boolean stopRecord = cameraController.tryStopRecord(() -> {
                finish();
                onDone.run();
            });
            if (!stopRecord) {
                finish();
                onDone.run();
            }
        } else {
            finish();
            onDone.run();
        }
    }

    @Override
    protected void onDestroy() {
        livePr1InferenceCoordinator.detach();
        if (wireButtonTouchHelper != null) {
            wireButtonTouchHelper.release();
            wireButtonTouchHelper = null;
        }
        if (laserEnableTouchHelper != null) {
            laserEnableTouchHelper.release();
            laserEnableTouchHelper = null;
        }
        for (int i = 0; i < deviceLaserHelpers.size(); i++) {
            LaserEnableLongPressTouchHelper helper = deviceLaserHelpers.valueAt(i);
            if (helper != null) {
                helper.release();
            }
        }
        deviceLaserHelpers.clear();
        deviceControlsByType.clear();
        closeContinuousFeed();
        closeContinuousRetract();
        LaserWorkGuard.unregister(this);
        super.onDestroy();
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_DATA_KEY, this);
        EngineerModeCheck.removeHandlerCallBack();
        WorkStatusDialogBuilder.clearInstance();
        OperationDialogBuilder.closeDialog();
        SafetyGroundLockPrompt.reset();
        LaserEnableStateHolder.clear();
        GpioLedHandler.refresh();
    }

    @Override
    public void onCacheChanged(String key) {
        if (deviceControlData==null||!deviceControlData.isOpenLaser()){
            return;
        }
        if (Objects.equals(CacheKey.DEVICE_STATUS_KEY, key)) {
            deviceStatusListen();
        } else if (Objects.equals(CacheKey.DEVICE_DATA_KEY, key)) {
            deviceDataListen();
        }
    }

    /**
     * 设备数据监听
     */
    private void deviceDataListen() {
        EngineerModeCheck.checkLaserCurrentStatus(this);

    }

    /**
     * 设备状态监听
     */
    private void deviceStatusListen() {
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus==null){
            return;
        }
        if (deviceControlData.isOpenLaser()) {
            if (!EngineerModeCheck.checkWorkStatus(this, deviceStatus)) {
                // 关闭激光
                switchLaserEnable(false,true);
                return;
            }
            if (LaserEnableAlarmGuard.isWorkBlocked(this, deviceStatus)) {
                switchLaserEnable(false, true);
                return;
            }
        }
        // 打开机台状态弹窗
        openWorkStatusDialog(deviceStatus);
        SafetyGroundLockPrompt.maybeShow(this, deviceStatus, deviceControlData.isOpenLaser());
    }

    @Override
    public boolean isLaserEnableActive() {
        return deviceControlData != null && deviceControlData.isOpenLaser();
    }

    @Override
    public void forceLaserOffForGuardedAlarm() {
        if (!isLaserEnableActive()) {
            return;
        }
        switchLaserEnable(false, true);
    }

    /**
     * 打开机台状态弹窗
     * @param deviceStatus
     */
    private void openWorkStatusDialog(DeviceStatus deviceStatus) {
        if (Objects.equals(lastIsGunSwitchOn, deviceStatus.isGunSwitchOn())){
            // 状态没有变化
            return;
        }
        lastIsGunSwitchOn = deviceStatus.isGunSwitchOn();
        if (deviceStatus.isGunSwitchOn()) {
            // 打开枪头
            WorkStatusDialogBuilder.createShowNoButtonDialog(this);
        } else {
            WorkStatusDialogBuilder.scheduleCloseOnGunOff(this);
        }
    }

    /**
     * 通知指定工艺页刷新 UI（ViewPager 懒加载页可能在非激活时已完成数据加载）。
     */
    private void notifyEngineerPageActivated(int activeType) {
        if (adapter == null) {
            return;
        }
        int pageIndex = ProcessModelConvert.modelConstantConvertToPageIndex(activeType);
        try {
            Fragment fragment = adapter.createFragment(pageIndex);
            if (fragment instanceof SendProcessParametersDataListener listener) {
                listener.onEngineerPageActivated();
            }
        } catch (Exception exception) {
            Log.d(TAG, "notifyEngineerPageActivated: 刷新工艺页 UI 异常", exception);
        }
    }

    /**
     * 初始化 Record Working 控件
     */
    public void initCameraController() {
        if (binding == null || binding.cameraController == null) {
            return;
        }
        binding.cameraController.setCameraControllerListener(() -> {
            if (adapter == null || binding == null) {
                return null;
            }
            Fragment fragment = adapter.createFragment(binding.engineerModePageContent.getCurrentItem());
            if (fragment instanceof SendProcessParametersDataListener sendProcessParametersDataListener) {
                return sendProcessParametersDataListener.getProcessParametersData();
            }
            Log.d(TAG, "无法获取到当前的工艺参数:" + binding.getActiveMode());
            return null;
        });
    }

    /**
     * 关闭持续送丝
     */
    private void closeContinuousFeed() {
        if (!isContinuousFeed) {
            return;
        }
        isContinuousFeed = false;
        syncContinuousFeedUi();
        closeFeedOrBack(null);
    }

    /**
     * 关闭持续退丝（兼容旧锁存；当前 Retreat 为按住连续、松开即停）
     */
    private void closeContinuousRetract() {
        if (!continuousRetractLatched) {
            return;
        }
        continuousRetractLatched = false;
        startRetractClick = false;
        syncContinuousFeedUi();
        closeFeedOrBack(null);
    }
}