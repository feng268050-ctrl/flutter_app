package com.lasercyber.lws.ui.activitys.quick.mode.fragment;

import android.content.Context;
import android.os.Handler;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.ViewModelProvider;

import com.blankj.utilcode.util.GsonUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.CommonUseConsumableViewModel;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.StaticDataViewModel;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.EngineerModeCheck;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserEnableAlarmGuard;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserWorkGuard;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.OperationDialogBuilder;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.SafetyGroundLockPrompt;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.ReminderExactBuilder;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.LaserEnableLongPressTouchHelper;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.WorkStatusDialogBuilder;
import com.lasercyber.lws.ui.activitys.quick.mode.QuickModeActivity;
import com.lasercyber.lws.ui.activitys.quick.mode.QuickModeSelectionCarry;
import com.lasercyber.lws.ui.activitys.quick.mode.QuickModeSelectionResolver;
import com.lasercyber.lws.ui.activitys.quick.mode.ui.QuickModeLaserEnableLongPressTouchHelper;
import com.lasercyber.lws.ui.activitys.quick.mode.builder.OffsetWheelBuilder;
import com.lasercyber.lws.ui.activitys.quick.mode.listener.BlurMaskControl;
import com.lasercyber.lws.ui.activitys.quick.mode.listener.CircularPickListener;
import com.lasercyber.lws.ui.activitys.quick.mode.model.QuickProcessParametersDataViewModel;
import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.DeviceControlData;
import com.lasercyber.lws.ui.bean.entity.DeviceStatus;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.ui.DoubleWheelViewItem;
import com.lasercyber.lws.ui.bean.ui.GeneralOperations;
import com.lasercyber.lws.ui.bean.ui.WheelViewItem;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.WorkModel;
import com.lasercyber.lws.ui.common.enums.TimingJobType;
import com.lasercyber.lws.ui.common.handler.GpioLedHandler;
import com.lasercyber.lws.ui.common.gpio.LaserEnableStateHolder;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.task.TimingJobTaskManager;
import com.lasercyber.lws.ui.common.state.ProcessParametersSnapshotStore;
import com.lasercyber.lws.ui.common.utils.BlurUtils;
import com.lasercyber.lws.ui.common.utils.DeviceControlUtils;
import com.lasercyber.lws.ui.common.utils.ManualWireButtonTouchHelper;
import com.lasercyber.lws.ui.common.utils.InchMillimeterUtils;
import com.lasercyber.lws.ui.common.utils.bean.GeneralOperationsUtils;
import com.lasercyber.lws.ui.common.utils.convert.EngineerWashConvert;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.adapter.OffsetWheelAdapter;
import com.lasercyber.lws.ui.component.dialog.MachineStatusOverlay;
import com.lasercyber.lws.ui.component.wheelview.widget.WheelView;
import com.lasercyber.lws.ui.databinding.FragmentGeneralOperationsBinding;

import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import cn.hutool.core.date.DateUnit;
import cn.hutool.core.date.DateUtil;
import lombok.Setter;

/**
 * A simple {@link Fragment} subclass.
 * Use the {@link GeneralOperationsFragment#newInstance} factory method to
 * create an instance of this fragment.
 * 快速模式通用的操作Fragment
 */
public class GeneralOperationsFragment extends BaseFragment<FragmentGeneralOperationsBinding>
        implements MemoryCacheManager.OnCacheChangedListener, LaserWorkGuard.Host {
    private static final String TAG = LogTAGConstant.GeneralOperationsFragment;
    private static final boolean isDebug = true;
    @Setter
    private GeneralOperations generalOperations;
    /**
     * 控制设备的数据
     */
    private DeviceControlData deviceControlData;
    private ManualWireButtonTouchHelper wireButtonTouchHelper;
    private QuickModeLaserEnableLongPressTouchHelper laserEnableTouchHelper;
    /** Last gun-switch value used for Live Monitor edge open/close. */
    @Nullable
    private Boolean lastIsGunSwitchOn;

    /**
     * 厚度字段为空时按 0mm 处理（如焊道清洗等无厚度维度的工艺）。
     */
    private static double thicknessMmOrZero(Double thickness) {
        return thickness == null ? 0d : thickness;
    }

    private static Double thicknessKey(Double thickness) {
        return thicknessMmOrZero(thickness);
    }

    /**
     * 摆宽（Scan Width）字段为空时按 0mm 处理。
     */
    private static double swingWidthMmOrZero(Double swingWidth) {
        return swingWidth == null ? 0d : swingWidth;
    }

    private static Double swingWidthKey(Double swingWidth) {
        return swingWidthMmOrZero(swingWidth);
    }

    private boolean usesScanWidthDimension() {
        int type = generalOperations.getType();
        return type == ModelConstant.WELD_CLEAN || type == ModelConstant.WIDTH_CLEAN;
    }
    /**
     * 数据mode
     */
    private QuickProcessParametersDataViewModel processParametersDataViewModel;
    /**
     * 当前材质
     */
    private Integer activeMaterials;
    /**
     * 当前档位
     */
    private Integer activeGear;

    /**
     * 当前厚度
     */
    private Double activeThickness;

    /**
     * 当前摆宽（Scan Width），焊道清洗 / 宽幅清洗使用。
     */
    private Double activeSwingWidth;
    @Setter
    private Context context;
    private Date startLaserTime;
    private StaticDataViewModel staticDataViewModel;
    private CommonUseConsumableViewModel commonUseConsumableViewModel;
    /**
     * 当前激活的模式类型
     */
    @Setter
    private int activeModelType = -1;

    public GeneralOperationsFragment() {
        // Required empty public constructor
    }

    public static GeneralOperationsFragment newInstance(Integer type, Context context) {
        GeneralOperationsFragment fragment = new GeneralOperationsFragment();
        if (Objects.equals(type, ModelConstant.HAND_CUT)) {
            fragment.setGeneralOperations(GeneralOperationsUtils.createCuttingHandHeldCutting());
        } else if (Objects.equals(type, ModelConstant.WIDTH_CLEAN)) {
            fragment.setGeneralOperations(GeneralOperationsUtils.createWashWidthCleaning());
        } else if (Objects.equals(type, ModelConstant.WELD_CLEAN)) {
            fragment.setGeneralOperations(GeneralOperationsUtils.createWashWeldCleaning());
        } else if (Objects.equals(type, ModelConstant.CONTINUOUS_WELDING)) {
            fragment.setGeneralOperations(GeneralOperationsUtils.createWeldingContinuousWelding());
        } else if (Objects.equals(type, ModelConstant.POINT_WELDING)) {
            fragment.setGeneralOperations(GeneralOperationsUtils.createWeldingPointWelding());
        }
        fragment.setContext(context);
        return fragment;
    }

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_general_operations;
    }

    @Override
    protected void initView() {
        commonUseConsumableViewModel=new ViewModelProvider(this).get(CommonUseConsumableViewModel.class);
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().addListener(CacheKey.DEVICE_DATA_KEY, this);
        LaserWorkGuard.register(this);
        // 初始化长按事件
        initClickEvent();
        // 初始化选择器
        initPicker();
    }

    @Override
    protected void initData() {
        if (generalOperations == null) {
            Log.e(TAG, "initData: generalOperations is null, skip init");
            return;
        }
        deviceControlData = new DeviceControlData();
        deviceControlData.setModel(this.generalOperations.getType());
        deviceControlData.setAutoWireFeedEnable(1);
        binding.setDeviceControlData(deviceControlData);
        ModbusManagerRtu.get().writeRegisters(ModbusFiledBuilder.createDeviceControlData(deviceControlData));
        // 下发控制
        ModbusManagerRtu.get().writeRegisters(ModbusFiledBuilder.createDeviceControlSwitchData(deviceControlData));
        if (isDebug) Log.d(TAG, "initData: 正在进行初始化:" + this.generalOperations.getType());
        processParametersDataViewModel = new ViewModelProvider(this).get(QuickProcessParametersDataViewModel.class);
        staticDataViewModel = new ViewModelProvider(this).get(StaticDataViewModel.class);
        staticDataViewModel.init(getContext());
        binding.setQuickProcessParametersDataViewModel(processParametersDataViewModel);
        processParametersDataViewModel.init(getContext(), this.generalOperations.getType());
        processParametersDataViewModel.getUseMMUnit().observe(getViewLifecycleOwner(), useMm -> {
            List<ProcessParametersData> list = processParametersDataViewModel.getListLiveData().getValue();
            if (list == null || list.isEmpty() || activeMaterials == null) {
                return;
            }
            initGearAndThickness(list);
        });

        processParametersDataViewModel.getListLiveData().observe(getViewLifecycleOwner(), dataList -> {
            // 获取到数据
            if (dataList == null || dataList.isEmpty()) {
                Log.w(TAG, "initData: 获取的工艺数据为空");
                return;
            }
            if (isDebug) Log.d(TAG, "initData: 加载的工艺数据:" + dataList);
            Set<Integer> materialsSet = dataList.stream().collect(Collectors.groupingBy(ProcessParametersData::getMaterialType)).keySet();
//            ArrayList<String> materialsList = new ArrayList<>();
            ArrayList<WheelViewItem> materialsList = new ArrayList<>();
            // 转换材质名称
            for (Integer materials : materialsSet) {
                WheelViewItem wheelViewItem = new WheelViewItem();
                wheelViewItem.setType(materials)
                        .setText(EngineerWashConvert.convertCleaningMaterialsText(materials))
//                        .setBackGroundRes(generalOperations.getBackGroundRes())
                ;
                materialsList.add(wheelViewItem);
            }
            // 材料：优先恢复会话携带的材质，否则第一项
            binding.materialsWheelView.setWheelData(materialsList);
            binding.materialsWheelView.addOnGlobalLayoutListener();
            int materialIndex = indexOfMaterial(materialsList, QuickModeSelectionCarry.getMaterialType());
            if (materialIndex < 0) {
                materialIndex = 0;
            }
            this.activeMaterials = materialsList.get(materialIndex).getType();
            binding.materialsWheelView.setSelection(materialIndex);
            if (isDebug) Log.d(TAG, "生成的材质列表：" + GsonUtils.toJson(materialsList));
            // 初始化档位和厚度
            initGearAndThickness(dataList);
        });
    }

    /**
     * 初始化档位和厚度
     *
     * @param dataList
     */
    private void initGearAndThickness(List<ProcessParametersData> dataList) {
        if (dataList == null || binding == null) {
            return;
        }
        boolean scanWidthMode = usesScanWidthDimension();
        LinkedHashMap<Integer, DoubleWheelViewItem> gearMap = new LinkedHashMap<>();
        LinkedHashMap<Double, DoubleWheelViewItem> rightDimensionMap = new LinkedHashMap<>();
        for (ProcessParametersData processParametersData : dataList) {
            if (!Objects.equals(activeMaterials, processParametersData.getMaterialType())) {
                // 排除其他材质
                continue;
            }
            if (!gearMap.containsKey(processParametersData.getGear())) {
                // 添加档位
                DoubleWheelViewItem doubleWheelViewItem = convertToGear(processParametersData);
                gearMap.put(processParametersData.getGear(), doubleWheelViewItem);
            }
            if (scanWidthMode) {
                Double key = swingWidthKey(processParametersData.getSwingWidth());
                if (!rightDimensionMap.containsKey(key)) {
                    rightDimensionMap.put(key, convertToSwingWidthData(processParametersData));
                }
            } else {
                Double key = thicknessKey(processParametersData.getThickness());
                if (!rightDimensionMap.containsKey(key)) {
                    rightDimensionMap.put(key, convertToThicknessData(processParametersData));
                }
            }
        }
        // 档位 / 右侧维度：会话携带（上一模式）优先于本 Fragment 缓存，缺省再回落第一项
        ArrayList<DoubleWheelViewItem> gearList = new ArrayList<>(gearMap.values());
        if (binding.gearPicker == null) {
            return;
        }
        Integer preferredGear = QuickModeSelectionResolver.preferCarryThenLocal(
                QuickModeSelectionCarry.getGear(), activeGear);
        int gearIndex = QuickModeSelectionResolver.indexOfGear(gearList, preferredGear);
        if (gearIndex < 0) {
            gearIndex = 0;
        }
        this.activeGear = !gearList.isEmpty() ? (int) gearList.get(gearIndex).getValue() : null;
        binding.gearPicker.setDataList(gearList, gearIndex);

        // 右侧滚轮：清洗模式为摆宽（Scan Width），其它模式为厚度
        ArrayList<DoubleWheelViewItem> rightDimensionList = new ArrayList<>(rightDimensionMap.values());
        int dimensionIndex = 0;
        if (scanWidthMode) {
            Double preferredSwing = QuickModeSelectionResolver.preferCarryThenLocal(
                    QuickModeSelectionCarry.getSwingWidth(), activeSwingWidth);
            dimensionIndex = QuickModeSelectionResolver.resolveDimensionIndex(
                    rightDimensionList,
                    dataList,
                    activeMaterials,
                    activeGear,
                    preferredSwing,
                    true);
            this.activeSwingWidth = !rightDimensionList.isEmpty()
                    ? rightDimensionList.get(dimensionIndex).getValue() : null;
        } else {
            Double preferredThickness = QuickModeSelectionResolver.preferCarryThenLocal(
                    QuickModeSelectionCarry.getThickness(), activeThickness);
            dimensionIndex = QuickModeSelectionResolver.resolveDimensionIndex(
                    rightDimensionList,
                    dataList,
                    activeMaterials,
                    activeGear,
                    preferredThickness,
                    false);
            this.activeThickness = !rightDimensionList.isEmpty()
                    ? rightDimensionList.get(dimensionIndex).getValue() : null;
        }
        binding.thicknessPicker.setDataList(rightDimensionList, dimensionIndex);
        rememberCurrentSelection();
        // 下发数据
        if (activeModelType == -1 || activeModelType == this.generalOperations.getType()) {
            this.sendProcessConfigDataProxy();
        } else {
            if (isDebug)
                Log.d(TAG, "initGearAndThickness: 不进行下发数据，当前快速模式为：[" + this.generalOperations.getType() + "]");
        }

    }

    private void rememberCurrentSelection() {
        QuickModeSelectionCarry.remember(activeMaterials, activeGear, activeThickness, activeSwingWidth);
    }

    private static int indexOfMaterial(List<WheelViewItem> materialsList, Integer preferredMaterial) {
        if (preferredMaterial == null || materialsList == null) {
            return -1;
        }
        for (int i = 0; i < materialsList.size(); i++) {
            if (Objects.equals(materialsList.get(i).getType(), preferredMaterial)) {
                return i;
            }
        }
        return -1;
    }

    @Override
    protected void bindViewModel() {
        super.bindViewModel();
        binding.setGeneralOperations(this.generalOperations);
        binding.setGeneralOperationsFragment(this);
        binding.setStartFeedClick(Boolean.FALSE);
    }

    /**
     * 初始化选择器
     */
    private void initPicker() {
        OffsetWheelAdapter adapter = new OffsetWheelAdapter(getContext(),OffsetWheelBuilder.builderOffsetMaterialsOffset());
        binding.materialsWheelView.setWheelAdapter(adapter);
        OffsetWheelBuilder.builderBasedWheelViewStyle(binding.materialsWheelView);
        binding.materialsWheelView.setWheelSize(7);
        binding.materialsWheelView.setOnWheelItemSelectedListener(new WheelView.OnWheelItemSelectedListener() {
            @Override
            public void onItemSelected(int position, Object o) {
//                if (initWheelView) {
//                    // 当前正在初始化中
//                    initWheelView = false;
//                } else {
//                    GlobalSoundManager.playClickSound();
//                }
                if (isDebug) Log.d(TAG, "当前选中:" + position);
                if (o == null) {
                    return;
                }
                activeMaterials = ((WheelViewItem) o).getType();
                initGearAndThickness(processParametersDataViewModel.getListLiveData().getValue());
            }
        });
        binding.materialsWheelView.setOnWheelItemClickListener((position, o) -> {
//            GlobalSoundManager.playClickSound();
            if (isDebug) Log.d(TAG, "当前选中:" + position);
            if (o == null) {
                return;
            }
            activeMaterials = ((WheelViewItem) o).getType();
            initGearAndThickness(processParametersDataViewModel.getListLiveData().getValue());
        });
        binding.thicknessPicker.setCircularPickListener(new CircularPickListener() {
            @Override
            public void onClickListener(DoubleWheelViewItem data) {
//                GlobalSoundManager.playClickSound();
                if (data == null) {
                    return;
                }
                if (usesScanWidthDimension()) {
                    if (isDebug) Log.d(TAG, "选择了摆宽(Scan Width):" + data);
                    activeSwingWidth = data.getValue();
                } else {
                    if (isDebug) Log.d(TAG, "选择了厚度:" + data);
                    activeThickness = data.getValue();
                }
                rememberCurrentSelection();
                sendProcessConfigDataProxy();
            }
        });
        // 档位选择
        binding.gearPicker.setCircularPickListener(new CircularPickListener() {
            @Override
            public void onClickListener(DoubleWheelViewItem data) {
//                GlobalSoundManager.playClickSound();
                if (data == null) {
                    return;
                }
                if (isDebug) Log.d(TAG, "选择了档位:" + data);
                activeGear = (int) data.getValue();
//                switchThicknesProcessData(activeGear,activeMaterials);
                // 下发数据
                rememberCurrentSelection();
                sendProcessConfigDataProxy();
            }
        });
    }

    /**
     * 切换档位
     *
     * @param thickness
     * @param materials
     */
    @Deprecated
    public void switchGearProcessData(Double thickness, Integer materials) {
        List<ProcessParametersData> list = processParametersDataViewModel.getListLiveData().getValue();
        if (list == null) {
            return;
        }
        List<DoubleWheelViewItem> viewItems = list.stream().filter(processParametersData -> Objects.equals(processParametersData.getMaterialType(), materials) &&
                Objects.equals(thicknessKey(processParametersData.getThickness()), thicknessKey(thickness)) && processParametersData.getGear() != null
        ).map((this::convertToGear)).collect(Collectors.toList());
        this.activeGear = (int) viewItems.get(0).getValue();
        binding.gearPicker.setDataList(viewItems);
    }

    private @NonNull DoubleWheelViewItem convertToGear(ProcessParametersData processParametersData) {
        DoubleWheelViewItem doubleWheelViewItem = new DoubleWheelViewItem();
        doubleWheelViewItem.setText(String.valueOf(processParametersData.getGear()));
        doubleWheelViewItem.setValue(processParametersData.getGear());
        doubleWheelViewItem.setDataId(processParametersData.getId());
        doubleWheelViewItem.setType(processParametersData.getDataType());
//        doubleWheelViewItem.setBackGroundRes(generalOperations.getBackGroundRes());
        return doubleWheelViewItem;
    }

    /**
     * 切换厚度
     */
    @Deprecated
    public void switchThicknessProcessData(Integer gear, Integer materials) {
        List<ProcessParametersData> list = processParametersDataViewModel.getListLiveData().getValue();
        if (list == null) {
            return;
        }
        List<DoubleWheelViewItem> viewItems = list.stream().filter(processParametersData -> Objects.equals(processParametersData.getMaterialType(), materials) &&
                Objects.equals(processParametersData.getGear(), gear)
        ).map((this::convertToThicknessData)).collect(Collectors.toList());
        this.activeGear = (int) viewItems.get(0).getValue();
        binding.thicknessPicker.setDataList(viewItems);
    }

    private @NonNull DoubleWheelViewItem convertToThicknessData(ProcessParametersData processParametersData) {
        DoubleWheelViewItem doubleWheelViewItem = new DoubleWheelViewItem();
        double mm = thicknessMmOrZero(processParametersData.getThickness());
        String thickness = String.valueOf(mm);
        if (!processParametersDataViewModel.useMMUnit()) {
            thickness = InchMillimeterUtils.mmToInStr(mm);
        }
        doubleWheelViewItem.setText(thickness);
        doubleWheelViewItem.setValue(mm);
        doubleWheelViewItem.setDataId(processParametersData.getId());
        doubleWheelViewItem.setType(processParametersData.getDataType());
//        doubleWheelViewItem.setBackGroundRes(generalOperations.getBackGroundRes());
        return doubleWheelViewItem;
    }

    private @NonNull DoubleWheelViewItem convertToSwingWidthData(ProcessParametersData processParametersData) {
        DoubleWheelViewItem doubleWheelViewItem = new DoubleWheelViewItem();
        double mm = swingWidthMmOrZero(processParametersData.getSwingWidth());
        String display = String.valueOf(mm);
        if (!processParametersDataViewModel.useMMUnit()) {
            display = InchMillimeterUtils.mmToInStr(mm);
        }
        doubleWheelViewItem.setText(display);
        doubleWheelViewItem.setValue(mm);
        doubleWheelViewItem.setDataId(processParametersData.getId());
        doubleWheelViewItem.setType(processParametersData.getDataType());
        return doubleWheelViewItem;
    }

    /**
     * 下发数据代理
     */
    private void sendProcessConfigDataProxy() {
        if (this.task != null) {
            handler.removeCallbacks(task);
        }
        this.task = this::sendProcessConfigData;
        handler.postDelayed(task, delayMillis);
    }

    /**
     * 下发工艺参数
     */
    public void sendProcessConfigData() {
        ProcessParametersData nowProcessParametersData = findNowProcessParametersData();
        if (nowProcessParametersData == null) {
            Log.e(TAG, "sendProcessConfigData: 下发工艺参数时，未找到对应的工艺，activeMaterials："
                    + activeMaterials + ",activeThickness:" + activeThickness
                    + ",activeSwingWidth:" + activeSwingWidth + ",activeGear:" + activeGear);
            return;
        }
        ProcessParametersSnapshotStore.update(nowProcessParametersData);
        ModbusManagerRtu.get().writeRegisters(ModbusFiledBuilder.createProcessParametersData(nowProcessParametersData));
    }

    public ProcessParametersData findNowProcessParametersData() {
        if (processParametersDataViewModel == null) {
            if (isDebug) Log.d(TAG, "findNowProcessParametersData: viewModel为空，无法找到工艺参数");
            return null;
        }
        LiveData<List<ProcessParametersData>> listLiveData = processParametersDataViewModel.getListLiveData();
        if (listLiveData == null) {
            if (isDebug) Log.d(TAG, "findNowProcessParametersData: 获取工艺参数列表失败");
            return null;
        }
        List<ProcessParametersData> list = listLiveData.getValue();
        if (list == null) {
            if (isDebug) Log.d(TAG, "findNowProcessParametersData: 工艺参数列表为空");
            return null;
        }
        boolean scanWidthMode = usesScanWidthDimension();
        for (ProcessParametersData processParametersData : list) {
            if (!Objects.equals(processParametersData.getMaterialType(), activeMaterials)) {
                continue;
            }
            if (scanWidthMode) {
                if (!Objects.equals(swingWidthKey(processParametersData.getSwingWidth()), swingWidthKey(activeSwingWidth))) {
                    continue;
                }
            } else if (!Objects.equals(thicknessKey(processParametersData.getThickness()), thicknessKey(activeThickness))) {
                continue;
            }
            if (!Objects.equals(processParametersData.getGear(), activeGear)) {
                continue;
            }
            // 列表为 SELECT * 全字段；克隆后返回，避免主线程同步读库
            if (isDebug) {
                Log.d(TAG, "找到工艺，下发工艺参数:" + GsonUtils.toJson(processParametersData));
            }
            return processParametersData.clone();
        }
        return null;
    }

    @Override
    public void onDestroyView() {
        rememberCurrentSelection();
        if (wireButtonTouchHelper != null) {
            wireButtonTouchHelper.release();
            wireButtonTouchHelper = null;
        }
        if (laserEnableTouchHelper != null) {
            laserEnableTouchHelper.release();
            laserEnableTouchHelper = null;
        }
        closeContinuousFeed();
        closeContinuousRetract();
        if (binding != null){
            binding.laserProgress.proactivelyDestroy();
        }
        super.onDestroyView();
        LaserWorkGuard.unregister(this);
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_STATUS_KEY, this);
        MemoryCacheManager.getInstance().removeListener(CacheKey.DEVICE_DATA_KEY, this);
        OperationDialogBuilder.closeDialog();
        WorkStatusDialogBuilder.clearInstance();
        WorkStatusDialogBuilder.closeDialog(requireContext().getApplicationContext());
        lastIsGunSwitchOn = null;
        EngineerModeCheck.removeHandlerCallBack();
        SafetyGroundLockPrompt.reset();
        LaserEnableStateHolder.clearLaserEnable();
        GpioLedHandler.refresh();
    }

    /**
     * 送丝使能
     */
    public void feedEnableClick() {
        GlobalSoundManager.playClickSound();
        closeContinuousFeed();
        closeContinuousRetract();
        int orangeData = deviceControlData.getAutoWireFeedEnable();
        if (deviceControlData.isOpenAutoWireFeed()) {
            deviceControlData.setAutoWireFeedEnable(0);
        } else {
            deviceControlData.setAutoWireFeedEnable(1);
        }
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlSwitchData(deviceControlData), new ModbusManagerRtu.WriteCallback() {
            @Override
            public void onSuccess() {
                ToastUtils.showShort(deviceControlData.isOpenAutoWireFeed()?R.string.wire_feed_enable_successful:R.string.wire_feed_successfully_closed);
                setDeviceControlData();
            }

            @Override
            public void onFailure() {
                ToastUtils.showShort(R.string.operation_failed_text);
                deviceControlData.setAutoWireFeedEnable(orangeData);
                setDeviceControlData();
            }
        });
    }

    /**
     * 手动送气
     */
    public void manualGasClick() {
        GlobalSoundManager.playClickSound();
        closeContinuousFeed();
        closeContinuousRetract();
        DeviceControlData sendConfig;
        int orangeData = deviceControlData.getManualGas();
        if (deviceControlData.isOpenManualGas()) {
            deviceControlData.setManualGas(0);
            sendConfig = DeviceControlUtils.createCloseManualGasConfig();
        } else {
            deviceControlData.setManualGas(1);
            sendConfig = DeviceControlUtils.createOpenManualGasConfig();
        }
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlSwitchData(sendConfig), new ModbusManagerRtu.WriteCallback() {
            @Override
            public void onSuccess() {
                ToastUtils.showShort(sendConfig.isOpenManualGas()?R.string.manual_gas_supply_successful:R.string.manual_gas_supply_successfully_shut_down);
                setDeviceControlData();
            }

            @Override
            public void onFailure() {
                ToastUtils.showShort(R.string.operation_failed_text);
                deviceControlData.setManualGas(orangeData);
                setDeviceControlData();
            }
        });
    }

    private void setDeviceControlData() {
        handler.post(() -> {
            if (deviceControlData == null) {
                Log.w(TAG, "更新设备控制数据，控制数据为空，不更新");
                return;
            }
            if (binding==null){
                Log.w(TAG, "更新设备控制数据，binding为空，不更新");
                return;
            }
            binding.setDeviceControlData(deviceControlData);
            if (isDebug)
                Log.d(TAG, "快速模式更新控制状态数据成功:" + GsonUtils.toJson(deviceControlData));
        });
    }

    /**
     * 激光开启使能（保留供外部调用；触摸由 {@link QuickModeLaserEnableLongPressTouchHelper} 处理）。
     */
    public void laserEnableClick() {
        if (deviceControlData.isOpenLaser()) {
            disableLaserEnable();
        } else {
            requestLaserEnable();
        }
    }

    private void disableLaserEnable() {
        closeContinuousFeed();
        closeContinuousRetract();
        switchLaserEnableStatus(true);
    }

    private void requestLaserEnable() {
        closeContinuousFeed();
        closeContinuousRetract();
        if (!EngineerModeCheck.enableLaser(deviceControlData.getModel(), requireActivity())) {
            return;
        }
        ReminderExactBuilder.openReminderExactDialog(getContext(), WorkModel.QUICK_MODE,
                deviceControlData.getModel(), () -> {
            if (!EngineerModeCheck.enableLaser(deviceControlData.getModel(), requireActivity())) {
                return;
            }
            switchLaserEnableStatus(true);
        });
    }

    /**
     * 关闭持续送丝
     */
    private void closeContinuousFeed() {
        if (binding == null || !Objects.equals(binding.getIsContinuousFeed(), Boolean.TRUE)) {
            return;
        }
        binding.setIsContinuousFeed(Boolean.FALSE);
        Log.d(TAG, "closeContinuousFeed: 关闭持续送丝:" + binding.getIsContinuousFeed());
        closeFeedOrBack(null);
    }

    /**
     * 关闭持续退丝
     */
    private void closeContinuousRetract() {
        if (binding == null || !Objects.equals(binding.getIsContinuousRetract(), Boolean.TRUE)) {
            return;
        }
        binding.setIsContinuousRetract(Boolean.FALSE);
        binding.setStartRetractClick(Boolean.FALSE);
        closeFeedOrBack(null);
    }

    /**
     * 切换激光使能状态
     * @param failRest 是否失败恢复
     */
    private void switchLaserEnableStatus(boolean failRest) {
        // 需要加入开启激光确认
        int orangeLaserStatus = deviceControlData.getLaserStatus();
        if (deviceControlData.isOpenLaser()) {
            deviceControlData.setLaserStatus(0);
        } else {
            if (deviceControlData.isOpenManualGas()) {
                ToastUtils.showShort(R.string.please_turn_off_the_manual_gas_supply_first);
                return;
            }
            deviceControlData.setLaserStatus(1);
        }
        if (deviceControlData.isOpenLaser()){
            // 下发工艺参数
            sendProcessConfigData();
            // 发送高级设置
            sendAdvanceSettingData();
        }else {
            ProcessParametersData nowProcessParametersData = findNowProcessParametersData();
            if (nowProcessParametersData!=null&&nowProcessParametersData.getMaterialType()!=null){
                commonUseConsumableViewModel.addUpdateCommonUseConsumableNumer(nowProcessParametersData.getMaterialType(), requireContext());
            }
        }
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlSwitchData(deviceControlData), new ModbusManagerRtu.WriteCallback() {
            @Override
            public void onSuccess() {
                if (deviceControlData.isOpenLaser()) {
                    // 点击 Laser Enable 成功后，结束 End-of-work 快照窗口。
                    MemoryCacheManager.getInstance().remove(
                            CacheKey.LAST_END_WORK_MODEL_QUICK_KEY);
                } else {
                    // 点击 End of work 成功后，记录当前快速模式功能快照。
                    MemoryCacheManager.getInstance().putSerializableNoNotice(
                            CacheKey.LAST_END_WORK_MODEL_QUICK_KEY,
                            Integer.valueOf(deviceControlData.getModel()));
                }
                if(deviceControlData.isOpenLaser()){
                    TimingJobTaskManager.getInstance().startTask( TimingJobType.JOB_TIME_LENGTH.name() );
                }
                LaserEnableStateHolder.setActive(deviceControlData.isOpenLaser(), deviceControlData.getModel());
                GpioLedHandler.refresh();
                handler.post(() -> {
                    if (binding==null){
                        return;
                    }
                    ToastUtils.showShort(deviceControlData.getLaserStatus() == 1 ? R.string.open_laser_success : R.string.close_laser_success);
//                    OperationDialogBuilder.openSuccessDialog(requireContext(), deviceControlData.getLaserStatus() == 1?R.string.open_laser_success:R.string.close_laser_success);
//                    binding.setLaserStatus(Objects.equals(deviceControlData.getLaserStatus(),1));
                    binding.setDeviceControlData(deviceControlData);
                    // 切换模糊状态
                    switchBlurStatus();
                    if (deviceControlData.isOpenLaser()) {
                        // 记录时间
                        startLaserTime = new Date();
                        DeviceStatus deviceStatus = MemoryCacheManager.getInstance()
                                .getSerializable(CacheKey.DEVICE_STATUS_KEY);
                        SafetyGroundLockPrompt.maybeShow(requireContext(), deviceStatus, true);
                    } else {
                        saveWorkTime();
                        SafetyGroundLockPrompt.reset();
                        lastIsGunSwitchOn = null;
                        WorkStatusDialogBuilder.closeDialogDelayMillis(requireContext());
                    }
//                    handler.postDelayed(OperationDialogBuilder::closeDialog,200);
                });
            }

            @Override
            public void onFailure() {
                // 重置状态
                if (failRest){
                    deviceControlData.setLaserStatus(orangeLaserStatus);
                }
                LaserEnableStateHolder.setActive(deviceControlData.isOpenLaser(), deviceControlData.getModel());
                GpioLedHandler.refresh();
                ToastUtils.showShort(R.string.operation_failed_text);
//                OperationDialogBuilder.openErrorDialog(requireContext(), R.string.please_check_the_equipment_text);
            }
        });
    }

    /**
     * Close laser enable when exiting weld work (e.g. zero-point alert jump to settings).
     */
    public void closeLaserEnableForExit(@NonNull Runnable onClosed) {
        closeContinuousFeed();
        closeContinuousRetract();
        if (deviceControlData == null || !deviceControlData.isOpenLaser()) {
            onClosed.run();
            return;
        }
        deviceControlData.setLaserStatus(0);
        ProcessParametersData nowProcessParametersData = findNowProcessParametersData();
        if (nowProcessParametersData != null && nowProcessParametersData.getMaterialType() != null) {
            commonUseConsumableViewModel.addUpdateCommonUseConsumableNumer(
                    nowProcessParametersData.getMaterialType(), requireContext());
        }
        ModbusManagerRtu.get().writeRegistersCall(
                ModbusFiledBuilder.createDeviceControlSwitchData(deviceControlData),
                new ModbusManagerRtu.WriteCallback() {
                    @Override
                    public void onSuccess() {
                        MemoryCacheManager.getInstance().putSerializableNoNotice(
                                CacheKey.LAST_END_WORK_MODEL_QUICK_KEY,
                                Integer.valueOf(deviceControlData.getModel()));
                        handler.post(() -> {
                            if (binding != null) {
                                binding.setDeviceControlData(deviceControlData);
                                switchBlurStatus();
                            }
                            saveWorkTime();
                            LaserEnableStateHolder.setActive(false, deviceControlData.getModel());
                            GpioLedHandler.refresh();
                            onClosed.run();
                        });
                    }

                    @Override
                    public void onFailure() {
                        LaserEnableStateHolder.setActive(false, deviceControlData.getModel());
                        GpioLedHandler.refresh();
                        handler.post(onClosed);
                    }
                });
    }

    /**
     * 发送高级设置数据
     */
    public void sendAdvanceSettingData() {
        if (processParametersDataViewModel == null) {
            return;
        }
        ProcessParametersData dataProxy = findNowProcessParametersData();
        Integer laserPower = dataProxy != null ? dataProxy.getLaserPower() : null;
        processParametersDataViewModel.sendAdvanceSettingForLaserEnable(laserPower);
    }
    /**
     * 保存工作时长
     */
    private void saveWorkTime() {
        if (startLaserTime == null) {
            return;
        }
        long between = DateUtil.between(startLaserTime, new Date(), DateUnit.SECOND);
        Double feedSpeed = 0d;
        ProcessParametersData nowProcessParametersData = findNowProcessParametersData();
        if (nowProcessParametersData != null && nowProcessParametersData.getWireFeedSpeed() != null) {
            feedSpeed = nowProcessParametersData.getWireFeedSpeed();
        }
        staticDataViewModel.weldStopProxy(deviceControlData.getModel(), (int) between, feedSpeed.longValue(), getContext());
    }

    /**
     * 切换模糊状态
     */
    public void switchBlurStatus() {
        if (deviceControlData.getLaserStatus() == 1) {
            BlurUtils.showBlurView(getResources(), binding.leftBottomBtnGroup, binding.rightBottomBtnGroup, binding.materialsWheelViewContent);
            binding.materialsWheelView.setVisibility(View.INVISIBLE);
        } else {
            BlurUtils.hideBlurView(binding.leftBottomBtnGroup, binding.rightBottomBtnGroup, binding.materialsWheelViewContent);
            binding.materialsWheelView.setVisibility(View.VISIBLE);
        }
        if (this.context instanceof BlurMaskControl blurMaskControl) {
            if (Objects.equals(deviceControlData.getLaserStatus(), 1)) {
                blurMaskControl.showBlurMask();
            } else {
                blurMaskControl.hideBlurMask();
            }

        }
    }

    /**
     * 初始化事件
     */
    public void initClickEvent() {
        binding.setIsContinuousFeed(Boolean.FALSE);
        binding.setIsContinuousRetract(Boolean.FALSE);
        binding.setStartFeedClick(Boolean.FALSE);
        binding.setStartRetractClick(Boolean.FALSE);
        binding.moreParametersBtn.setOnClickListener(v -> {
            if (getActivity() instanceof QuickModeActivity activity) {
                activity.onMoreParametersClick();
            }
        });
        binding.laserProgress.setDeviceLogoBtnClickListener(v ->
                MachineStatusOverlay.show(requireContext(), true));
        laserEnableTouchHelper = new QuickModeLaserEnableLongPressTouchHelper(
                binding.btnLaserEnable, createLaserEnableTouchHost());
        laserEnableTouchHelper.attach();
        wireButtonTouchHelper = new ManualWireButtonTouchHelper(binding.btnFeed, createWireButtonHost());
        wireButtonTouchHelper.attachFeedButton(binding.btnFeed);
        wireButtonTouchHelper.attachRetractButton(binding.btnRetract);
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
                        requireContext(), deviceStatus);
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
            public Handler getHandler() {
                return handler;
            }

            @Override
            public boolean isContinuousFeed() {
                return Objects.equals(binding.getIsContinuousFeed(), Boolean.TRUE);
            }

            @Override
            public void setContinuousFeed(boolean continuous) {
                binding.setIsContinuousFeed(continuous);
            }

            @Override
            public void setStartFeedClick(boolean start) {
                binding.setStartFeedClick(start);
            }

            @Override
            public boolean isContinuousRetract() {
                return Objects.equals(binding.getIsContinuousRetract(), Boolean.TRUE);
            }

            @Override
            public void setContinuousRetract(boolean continuous) {
                binding.setIsContinuousRetract(continuous);
            }

            @Override
            public void setStartRetractClick(boolean start) {
                binding.setStartRetractClick(start);
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
                GeneralOperationsFragment.this.openFeed(callback);
            }

            @Override
            public void closeFeedOrBack(ModbusManagerRtu.WriteCallback callback) {
                GeneralOperationsFragment.this.closeFeedOrBack(callback);
            }

            @Override
            public boolean openBackFeed(ModbusManagerRtu.WriteCallback callback) {
                return GeneralOperationsFragment.this.openBackFeed(callback);
            }

            @Override
            public void onContinuousFeedEntered() {
                ToastUtils.showShort(R.string.feed_ongoing_text);
            }

            @Override
            public void onContinuousFeedStopped() {
                ToastUtils.showShort(R.string.end_feed);
            }

            @Override
            public void onContinuousRetractEntered() {
                ToastUtils.showShort(R.string.retreat_ongoing_text);
            }

            @Override
            public void onContinuousRetractStopped() {
                ToastUtils.showShort(R.string.retreat_ends);
            }

            @Override
            public void onFeedPulseSuccess() {
                ToastUtils.showShort(R.string.feed_successful);
            }

            @Override
            public void onFeedPulseFailure() {
                ToastUtils.showShort(R.string.operation_failed_text);
            }

            @Override
            public void onRetractPulseSuccess() {
                ToastUtils.showShort(R.string.feed_success_text);
            }

            @Override
            public void onFeedHoldReleased() {
                ToastUtils.showShort(R.string.feed_successful);
            }

            @Override
            public void onRetractHoldReleased() {
                ToastUtils.showShort(R.string.feed_end_text);
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
            }

            @Override
            public void beforeRetractAction() {
                closeContinuousFeed();
                closeContinuousRetract();
            }
        };
    }

    /**
     * 开始送丝
     */
    public boolean openFeed(ModbusManagerRtu.WriteCallback callback) {
//        if (deviceControlData.getWireFeedEnable()==0){
//            ToastUtils.showShort("请先打开送丝使能");
//            return false;
//        }
        if (isDebug) Log.d(TAG, "下发送丝=====>");
        DeviceControlData openFeedConfig = DeviceControlUtils.createOpenFeedConfig(deviceControlData);
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlSwitchData(openFeedConfig),callback);
        return true;
    }

    /**
     * 结束送丝或者退丝
     */
    public void closeFeedOrBack(ModbusManagerRtu.WriteCallback callback) {
        if (isDebug) Log.d(TAG, "下结束退丝=====>");
        DeviceControlData openFeedConfig = DeviceControlUtils.createCloseFeedOrBackConfig(deviceControlData);
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlSwitchData(openFeedConfig), callback);
    }

    /**
     * 开启退丝
     */
    public boolean openBackFeed(ModbusManagerRtu.WriteCallback callback) {
//        if (deviceControlData.getWireFeedEnable()==0){
//            ToastUtils.showShort("请先打开送丝使能");
//            return false;
//        }
        if (isDebug) Log.d(TAG, "下发送退丝=====>");
        DeviceControlData openFeedConfig = DeviceControlUtils.createBackFeedConfig(deviceControlData);
        ModbusManagerRtu.get().writeRegistersCall(ModbusFiledBuilder.createDeviceControlSwitchData(openFeedConfig),callback);
        return true;
    }

    @Override
    public void onCacheChanged(String key) {
        if (deviceControlData==null||!deviceControlData.isOpenLaser()) {
            // 未开启激光，不管
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
        EngineerModeCheck.checkLaserCurrentStatus(requireActivity());

    }

    /**
     * 设备状态监听
     */
    private void deviceStatusListen() {
        DeviceStatus deviceStatus = MemoryCacheManager.getInstance().getSerializable(CacheKey.DEVICE_STATUS_KEY);
        if (deviceStatus==null){
            return;
        }
        if (!EngineerModeCheck.checkWorkStatus(requireContext(), deviceStatus)) {
            switchLaserEnableStatus(false);
            return;
        }
        if (LaserEnableAlarmGuard.isWorkBlocked(requireContext(), deviceStatus)) {
            switchLaserEnableStatus(false);
            return;
        }
        openWorkStatusDialog(deviceStatus);
        SafetyGroundLockPrompt.maybeShow(requireContext(), deviceStatus, deviceControlData.isOpenLaser());
    }

    /**
     * Open / schedule-close Live Monitor on gun-switch edges (same as Engineer Mode).
     */
    private void openWorkStatusDialog(@NonNull DeviceStatus deviceStatus) {
        if (Objects.equals(lastIsGunSwitchOn, deviceStatus.isGunSwitchOn())) {
            return;
        }
        lastIsGunSwitchOn = deviceStatus.isGunSwitchOn();
        if (deviceStatus.isGunSwitchOn()) {
            WorkStatusDialogBuilder.createShowNoButtonDialog(requireContext());
        } else {
            WorkStatusDialogBuilder.scheduleCloseOnGunOff(requireContext());
        }
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
        switchLaserEnableStatus(false);
    }
}
