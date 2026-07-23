package com.lasercyber.lws.ui.activitys.quick.mode;

import android.content.Intent;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;

import com.blankj.utilcode.util.GsonUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.activitys.engineer.mode.EngineerModeActivity;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.EngineerModeEntryTipsDialog;
import com.lasercyber.lws.ui.activitys.quick.mode.builder.OffsetWheelBuilder;
import com.lasercyber.lws.ui.activitys.quick.mode.fragment.CNCCutFragment;
import com.lasercyber.lws.ui.activitys.quick.mode.fragment.GeneralOperationsFragment;
import com.lasercyber.lws.ui.activitys.quick.mode.listener.BlurMaskControl;
import com.lasercyber.lws.ui.bean.entity.DeviceControlData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.ui.WheelViewItem;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockPolicy;
import com.lasercyber.lws.ui.common.device.DeviceRemoteLockStore;
import com.lasercyber.lws.ui.common.gpio.LaserEnableStateHolder;
import com.lasercyber.lws.ui.common.handler.GpioLedHandler;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.camera.LivePr1InferenceStreamCoordinator;
import com.lasercyber.lws.ui.common.weld.WeldModeHost;
import com.lasercyber.lws.ui.common.utils.BlurUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.adapter.OffsetWheelAdapter;
import com.lasercyber.lws.ui.component.dialog.MachineStatusOverlayPreloader;
import com.lasercyber.lws.ui.databinding.ActivityQuickModeBinding;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

/**
 * 快速模式
 */
public class QuickModeActivity extends BaseActivity<ActivityQuickModeBinding>
        implements BlurMaskControl, WeldModeHost, MemoryCacheManager.OnCacheChangedListener {
    private static final String TAG = LogTAGConstant.QuickModeActivity;
    private Map<Integer, Fragment> fragmentMap = new HashMap<>();
    private final LivePr1InferenceStreamCoordinator livePr1InferenceCoordinator =
            new LivePr1InferenceStreamCoordinator();

    @Override
    protected void initView() {
        QuickModeSelectionCarry.clear();
        binding.setLaserStatus(Boolean.FALSE);
        binding.setCncOpening(Boolean.FALSE);
        binding.setCncHomeBlocked(Boolean.FALSE);
        ArrayList<WheelViewItem> wheelViewItems = new ArrayList<>();
        binding.quickModeStatusBar.setOnCallBackListener(this::callBackHome);
        wheelViewItems.add(new WheelViewItem(getString(R.string.continuous_welding_text), ModelConstant.CONTINUOUS_WELDING));
        wheelViewItems.add(new WheelViewItem(getString(R.string.point_welding_text), ModelConstant.POINT_WELDING));
        wheelViewItems.add(new WheelViewItem(getString(R.string.weld_cleaning_text), ModelConstant.WELD_CLEAN));
        wheelViewItems.add(new WheelViewItem(getString(R.string.width_cleaning_text), ModelConstant.WIDTH_CLEAN));
        wheelViewItems.add(new WheelViewItem(getString(R.string.hand_cutting_text), ModelConstant.HAND_CUT));
        wheelViewItems.add(new WheelViewItem(getString(R.string.cnc_cutting_text), ModelConstant.CNC_CUT));

        OffsetWheelAdapter adapter = new OffsetWheelAdapter(this, OffsetWheelBuilder.builderOffsetModelOffset());
        binding.wheelView.setWheelAdapter(adapter);
        OffsetWheelBuilder.builderBasedWheelViewStyle(binding.wheelView);
        binding.wheelView.setWheelData(wheelViewItems);
        binding.wheelView.setSelection(0);
//        binding.wheelView.setWheelSize(9);

        binding.wheelView.setOnWheelItemSelectedListener((position, o) -> {
//                if (initWheelView){
//                    initWheelView=false;
//                }else {
//                    GlobalSoundManager.playClickSound();
//                }
            Log.d(TAG, "当前选中:" + position);
            if (o == null) {
                return;
            }
            delaySwitchFragment(((WheelViewItem) o).getType());
        });
        binding.wheelView.setOnWheelItemClickListener((position, o) -> {
//            GlobalSoundManager.playClickSound();
            Log.d(TAG, "当前选中:" + position);
            if (o == null) {
                return;
            }
            switchToFragmentContent(((WheelViewItem) o).getType(), false);
        });
        // 退出CNC监听（包括设备主动断开、界面上主动断开）
        binding.cncRunning.setCncLinkExitListener(this::cncLinkExit);
        // 初始化Fragment
        initFragment();
        // 初始化 Record Working
        this.initCameraController();
        livePr1InferenceCoordinator.attach(this);
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
        refreshCncHomeBlocked();
    }

    private void refreshCncHomeBlocked() {
        if (binding == null) {
            return;
        }
        binding.setCncHomeBlocked(isCncSessionActive());
    }

    @Override
    public void onCacheChanged(String key) {
        if (CacheKey.DEVICE_STATUS_KEY.equals(key)) {
            refreshCncHomeBlocked();
        }
    }

    /**
     * 退出CNC连接：关闭运行中覆盖层，保持在 CNC Cut 未连接界面。
     */
    private void cncLinkExit(boolean isErrorExit) {
        if (binding == null) {
            return;
        }
        releaseCncSessionUi();
        if (!isErrorExit) {
            requestDeviceExitCncMode(() -> { }, () ->
                    ToastUtils.showShort(R.string.cnc_connection_failed));
        }
    }

    private boolean isCncSessionActive() {
        if (binding == null || binding.getModeType() == null
                || binding.getModeType() != ModelConstant.CNC_CUT) {
            return false;
        }
        if (Boolean.TRUE.equals(binding.getCncOpening())) {
            return true;
        }
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance()
                .getSerializable(CacheKey.DEVICE_STATUS_KEY);
        return deviceStatus != null && deviceStatus.isConnectCNC();
    }

    private void releaseCncSessionUi() {
        if (binding != null) {
            binding.setCncOpening(Boolean.FALSE);
        }
        GpioLedHandler.refresh();
        Fragment fragment = fragmentMap.get(ModelConstant.CNC_CUT);
        if (fragment instanceof CNCCutFragment cncCutFragment) {
            cncCutFragment.onCncSessionClosed();
        }
        refreshCncHomeBlocked();
    }

    private void requestDeviceExitCncMode(@NonNull Runnable onSuccess, @NonNull Runnable onFailure) {
        DeviceControlData deviceControlData = new DeviceControlData();
        deviceControlData.setModel(ModelConstant.CONTINUOUS_WELDING);
        ModbusManagerRtu.get().writeRegistersCall(
                ModbusFiledBuilder.createDeviceControlData(deviceControlData),
                new ModbusManagerRtu.WriteCallback() {
                    @Override
                    public void onSuccess() {
                        onSuccess.run();
                    }

                    @Override
                    public void onFailure() {
                        onFailure.run();
                    }
                });
    }

    /**
     * 打开工程师模式并携带当前快速模式所选工艺参数。
     */
    public void onMoreParametersClick() {
        GlobalSoundManager.playClickSound();
        if (DeviceRemoteLockPolicy.blockHomeNavigationIfLocked(this, DeviceRemoteLockPolicy.HOME_PAGE_ENGINEER)) {
            return;
        }
        Integer modeType = binding.getModeType();
        if (modeType == null || modeType == ModelConstant.CNC_CUT) {
            return;
        }
        Fragment fragment = getSupportFragmentManager().findFragmentById(R.id.quick_mode_content);
        if (!(fragment instanceof GeneralOperationsFragment generalOperationsFragment)) {
            ToastUtils.showShort(R.string.parameter_exception);
            return;
        }
        ProcessParametersData data = generalOperationsFragment.findNowProcessParametersData();
        if (data == null || data.getId() == null) {
            ToastUtils.showShort(R.string.parameter_exception);
            return;
        }
        EngineerModeEntryTipsDialog.showIfNeeded(this, () -> {
            Intent intent = new Intent(this, EngineerModeActivity.class);
            intent.putExtra(EngineerModeActivity.EXTRA_QUICK_MODE_PROCESS_TYPE, modeType);
            intent.putExtra(EngineerModeActivity.EXTRA_QUICK_MODE_SOURCE_ROW_ID, data.getId());
            startActivity(intent);
        });
    }

    /**
     * 回到首页
     */
    private void callBackHome() {
        if (isCncSessionActive()) {
            ToastUtils.showShort(R.string.please_turn_off_the_cnc_first);
            return;
        }
        finishQuickMode();
    }

    private void finishQuickMode() {
        if (binding != null && binding.cameraController != null) {
            boolean stopRecord = binding.cameraController.tryStopRecord(this::finish);
            if (!stopRecord) {
                finish();
            }
        } else {
            finish();
        }
    }

    @Override
    protected void initData() {
        MemoryCacheManager.getInstance().putSerializableNoNotice(
                CacheKey.LAST_TOP_MODE_CONTEXT_KEY,
                Integer.valueOf(CacheKey.TOP_MODE_CONTEXT_QUICK));
//        generalOperationsFragment.updateGeneralOperations(GeneralOperationsUtils.createCuttingHandHeldCutting());
    }

    @Override
    protected int getLayoutId() {
        return R.layout.activity_quick_mode;
    }

    /*初始化init*/

    /**
     * 初始化Fragment
     */
    private void initFragment() {
        // ModelConstant.HAND_CUT
        GeneralOperationsFragment handCut = GeneralOperationsFragment.newInstance(ModelConstant.HAND_CUT, this);
        fragmentMap.put(ModelConstant.HAND_CUT, handCut);
        // ModelConstant.WELD_CLEAN
        GeneralOperationsFragment weldClean = GeneralOperationsFragment.newInstance(ModelConstant.WELD_CLEAN, this);
        fragmentMap.put(ModelConstant.WELD_CLEAN, weldClean);
        // ModelConstant.WIDTH_CLEAN
        GeneralOperationsFragment widthClean = GeneralOperationsFragment.newInstance(ModelConstant.WIDTH_CLEAN, this);
        fragmentMap.put(ModelConstant.WIDTH_CLEAN, widthClean);
        // ModelConstant.CONTINUOUS_WELDING
        GeneralOperationsFragment continuousWelding = GeneralOperationsFragment.newInstance(ModelConstant.CONTINUOUS_WELDING, this);
        fragmentMap.put(ModelConstant.CONTINUOUS_WELDING, continuousWelding);
        // ModelConstant.POINT_WELDING
        GeneralOperationsFragment pointWelding = GeneralOperationsFragment.newInstance(ModelConstant.POINT_WELDING, this);
        fragmentMap.put(ModelConstant.POINT_WELDING, pointWelding);
        // ModelConstant.CNC_CUT
        CNCCutFragment cncCut = new CNCCutFragment();
        // CNC连接成功后进行回调
        cncCut.setCncLinkSuccessListener(() -> {
            binding.setCncOpening(Boolean.TRUE);
            refreshCncHomeBlocked();
            GpioLedHandler.refresh();
        });
        fragmentMap.put(ModelConstant.CNC_CUT, cncCut);

        this.switchToFragmentContent(ModelConstant.CONTINUOUS_WELDING, true);
    }

    public void delaySwitchFragment(int modeType) {
        if (task != null) {
            handler.removeCallbacks(task);
        }
        task = () -> switchToFragmentContent(modeType, false);
        handler.postDelayed(task, 70);
    }

    /**
     * 切换类容
     *
     * @param modeType
     */
    public void switchToFragmentContent(int modeType, boolean isInit) {
        LaserEnableStateHolder.setWorkModel(modeType);
        if (modeType != ModelConstant.CNC_CUT && binding != null) {
            binding.setCncOpening(Boolean.FALSE);
        }
        if (binding != null) {
            binding.setModeType(modeType);
        }

        Fragment fragment = this.fragmentMap.get(modeType);
        FragmentManager manager = getSupportFragmentManager();
        if (manager.isDestroyed()) {
            return;
        }
        FragmentTransaction transaction = manager.beginTransaction();
        transaction.replace(R.id.quick_mode_content, fragment);
        transaction.commit();
        if (!isInit && binding != null && binding.cameraController != null) {
            binding.cameraController.setMode_type(modeType);
            if (modeType == ModelConstant.CNC_CUT) {
                binding.cameraController.tryStopRecord(null);
            }
            // 切换模式时停止录制
            binding.cameraController.tryStopRecord(null);
        }
        if (fragment instanceof GeneralOperationsFragment generalOperationsFragment) {
            try {
                generalOperationsFragment.sendAdvanceSettingData();
                generalOperationsFragment.sendProcessConfigData();
            } catch (Exception exception) {
                Log.d(TAG, "switchToFragmentContent: 下发配置异常", exception);
            }
        }
        refreshCncHomeBlocked();
    }

    @Override
    public void showBlurMask() {
//        binding.equipmentStatusBarContent,
        BlurUtils.showBlurView(getResources(), binding.modelWheelViewContent);
        binding.wheelView.setVisibility(View.INVISIBLE);
        binding.setLaserStatus(Boolean.TRUE);
    }

    @Override
    public void hideBlurMask() {
        binding.setLaserStatus(Boolean.FALSE);
//        binding.equipmentStatusBarContent,
        BlurUtils.hideBlurView(binding.modelWheelViewContent);
        binding.wheelView.setVisibility(View.VISIBLE);
    }

    /**
     * 初始化 Record Working 控件
     */
    public void initCameraController() {
        if (binding == null || binding.cameraController == null) {
            return;
        }
        binding.cameraController.setCameraControllerListener(() -> {
            Fragment fragment = fragmentMap.get(binding.getModeType());
            if (fragment instanceof GeneralOperationsFragment operationsFragment) {
                return operationsFragment.findNowProcessParametersData();
            }
            Log.d(TAG, "无法获取到当前的工艺参数:" + binding.getModeType());
            return null;
        });
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
     * Remote lock: stop work and return home without confirmation dialogs.
     */
    public void exitForRemoteLock() {
        Runnable finishToHome = () -> {
            DeviceRemoteLockPolicy.navigateToHome(this);
            finishQuickMode();
        };
        if (isCncSessionActive()) {
            requestDeviceExitCncMode(() -> {
                releaseCncSessionUi();
                finishToHome.run();
            }, finishToHome);
            return;
        }
        finishToHome.run();
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (isFinishing()) {
            MemoryCacheManager.getInstance().putSerializableNoNotice(
                    CacheKey.LAST_TOP_MODE_CONTEXT_KEY,
                    Integer.valueOf(CacheKey.TOP_MODE_CONTEXT_QUICK));
        }
    }

    @Override
    public int getActiveWeldModelType() {
        if (binding == null || binding.getModeType() == null) {
            return ModelConstant.CONTINUOUS_WELDING;
        }
        return binding.getModeType();
    }

    @Override
    public void exitWeldWorkForZeroPointSettings(@NonNull Runnable onDone) {
        Fragment fragment = getSupportFragmentManager().findFragmentById(R.id.quick_mode_content);
        Runnable finishAndOpen = () -> finishAfterStopRecord(onDone);
        if (fragment instanceof GeneralOperationsFragment ops) {
            ops.closeLaserEnableForExit(finishAndOpen);
        } else {
            finishAndOpen.run();
        }
    }

    private void finishAfterStopRecord(@NonNull Runnable onDone) {
        if (binding != null && binding.cameraController != null) {
            boolean stopRecord = binding.cameraController.tryStopRecord(() -> {
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
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
        livePr1InferenceCoordinator.detach();
        super.onDestroy();
    }
}