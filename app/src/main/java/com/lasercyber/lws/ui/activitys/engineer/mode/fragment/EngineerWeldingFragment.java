package com.lasercyber.lws.ui.activitys.engineer.mode.fragment;


import android.util.Log;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.ViewModelProvider;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.engineer.mode.EngineerModeActivity;
import com.lasercyber.lws.ui.activitys.engineer.mode.component.ContinuousWeldingLineChart;
import com.lasercyber.lws.ui.activitys.engineer.mode.component.SpotWeldingLineChart;
import com.lasercyber.lws.ui.activitys.engineer.mode.component.WeldingChart;
import com.lasercyber.lws.ui.activitys.engineer.mode.listener.EngineerPageActiveListener;
import com.lasercyber.lws.ui.activitys.engineer.mode.listener.SendProcessParametersDataListener;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.ProcessParametersDataViewModel;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.DataPopupBuilder;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.EngineerDataCheck;
import com.lasercyber.lws.ui.activitys.engineer.mode.ui.InputDialogBuilder;
import com.lasercyber.lws.ui.bean.entity.AdvancedSettings;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersNameData;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.convert.EngineerWeldingConvert;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.databinding.EngineerRampChartAccordionBinding;
import com.lasercyber.lws.ui.databinding.FragmentEngineerWeldingBinding;

import java.util.List;
import java.util.Objects;

import lombok.Setter;

/**
 * A simple {@link Fragment} subclass.
 * Use the {@link EngineerWeldingFragment#newInstance} factory method to
 * create an instance of this fragment.
 * 焊接模式Fragment
 */
public class EngineerWeldingFragment extends BaseFragment<FragmentEngineerWeldingBinding> implements SendProcessParametersDataListener{
    private static final String TAG = LogTAGConstant.EngineerWeldingFragment;
    /**
     * 数据模型
     */
    private ProcessParametersDataViewModel processParametersDataViewModel;
    /**
     * 焊接类型
     * {@link ModelConstant}
     */
    private Integer type;
    private WeldingChart weldingChart;
    private boolean openRampChart;
    /**
     * 页面激活监听
     */
    @Setter
    private EngineerPageActiveListener engineerPageActiveListener;

    public EngineerWeldingFragment() {
        super();
    }

    public EngineerWeldingFragment(Integer type) {
        this.type = type;
    }

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_engineer_welding;
    }

    @Override
    protected void initView() {
        binding.setOpenMoreCommon(Boolean.FALSE);
        binding.moreCommon.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            // 加载数据
//            Log.d(TAG, "initView: ============>点击了");
            List<ProcessParametersNameData> parametersDataList = processParametersDataViewModel.getAllDataByType();
            Log.d(TAG, "initView:===>getAllDataByType " + parametersDataList);
            if (parametersDataList == null || parametersDataList.isEmpty()) {
                ToastUtils.showShort(R.string.there_are_no_more_common_specs_available);
                return;
            }
//            processParametersDataViewModel.listAllDataName((parametersDataList) -> {
            // 数据加载完成，执行回调
            binding.setOpenMoreCommon(!binding.getOpenMoreCommon());
            if (binding.getOpenMoreCommon()) {
                DataPopupBuilder.moreCommonBuilder(processParametersDataViewModel.getName(), parametersDataList, getContext(), type, (dataListPopup, bean) -> {
                    if (bean == null) {
                        binding.setOpenMoreCommon(Boolean.FALSE);
                        return;
                    }
                    // 切换工艺参数
                    processParametersDataViewModel.switchProcessParametersData(bean.getId(), (switchProcess) -> {
                        // 选中后的逻辑（例如更新按钮文本）
                        dataListPopup.dismiss();
                        applySessionFromLiveData();
                        binding.setOpenMoreCommon(Boolean.FALSE);
                    });
                }).show(v);
            }
//            });
        });
        binding.materialsBox.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            // 初始化弹窗
            DataPopupBuilder.materialsBuilder(processParametersDataViewModel.getMaterialTypeLabel(), getContext(), type, (dataListPopup, dataListPopupItem) -> {
                // 选中后的逻辑（例如更新按钮文本）
                dataListPopup.dismiss();
                if (Objects.equals(dataListPopupItem.getIconRes(), R.mipmap.customize_icon)) {
                    // 当前为自定义
                    InputDialogBuilder.materialBuilder(processParametersDataViewModel, inputData -> {
                        binding.materialsIcon.setImageResource(dataListPopupItem.getIconRes());
                        binding.weldingMaterialsInput.setText(inputData);
                        sendDataProxy();
                    });
                } else {
                    processParametersDataViewModel.setMaterialTypeFromLabel(dataListPopupItem.getName());
                    binding.materialsIcon.setImageResource(dataListPopupItem.getIconRes());
                    binding.weldingMaterialsInput.setText(dataListPopupItem.getName());
                    sendDataProxy();
                }
            }).show(v);
        });
        initLister();
    }

    /**
     * 设置监听
     */
    public void initLister() {
        // 厚度
        binding.thickness.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.thicknessBuilder(
                            processParametersDataViewModel,
                            inputData -> updateProcessParamsDataAndSend()
                    );
                }
        );
        // 点焊间隔
        binding.pointWeldingInterval.setOnClickListener(v -> {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.pointWeldingIntervalBuilder(
                            processParametersDataViewModel,
                            inputData -> {
                                updateProcessParamsDataAndSend();
                                // 更新chart
                                updateWeldingChart();
                            }
                    );
                }
        );
        // 点焊持续
        binding.pointWeldingDuration.setOnClickListener(v -> {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.pointWeldingDurationBuilder(
                            processParametersDataViewModel,
                            inputData -> {
                                updateProcessParamsDataAndSend();
                                // 更新chart
                                updateWeldingChart();
                            }
                    );
                }
        );
        // 焊接功率
        binding.weldingPower.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.weldingPowerBuilder(
                            processParametersDataViewModel,
                            inputData -> {
                                updateProcessParamsDataAndSend();
                                // 更新chart
                                updateWeldingChart();
                            }
                    );
                }
        );
        // 摆动频率
        binding.swingFrequency.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.swingFrequencyBuilder(
                            processParametersDataViewModel,
                            inputData -> updateProcessParamsDataAndSend()
                    );
                }
        );
        // 焊接宽度
        binding.weldWidth.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.weldWidthBuilder(
                            processParametersDataViewModel,
                            inputData -> updateProcessParamsDataAndSend()
                    );
                }
        );
        // 关光延时
        binding.closeLightDelay.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            InputDialogBuilder.closeLightDelayBuilder(
                    processParametersDataViewModel,
                    inputData -> updateProcessParamsDataAndSend()
            );
        });
        // 吹气延时
        binding.airOffDelay.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.airOffDelayBuilder(
                            processParametersDataViewModel,
                            inputData -> {
                                updateProcessParamsDataAndSend();
                                // 更新chart
                                updateWeldingChart();
                            }
                    );
                }
        );
        // 关气延时
        binding.closeAirDelay.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.closeAirDelayBuilder(
                            processParametersDataViewModel,
                            inputData -> {
                                updateProcessParamsDataAndSend();
                                // 更新chart
                                updateWeldingChart();
                            }
                    );
                }
        );
        // 回抽长度
        binding.pullbackLength.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.pullbackLengthBuilder(
                            processParametersDataViewModel,
                            inputData -> updateProcessParamsDataAndSend()
                    );
                }
        );
        // 回抽速度
        binding.pullbackSpeed.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.pullbackSpeedBuilder(
                            processParametersDataViewModel,
                            inputData -> updateProcessParamsDataAndSend()
                    );
                }
        );
        // 补丝长度
        binding.wireLength.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.wireLengthBuilder(
                            processParametersDataViewModel,
                            inputData -> updateProcessParamsDataAndSend()
                    );
                }
        );
        // 补丝延时
        binding.repairWireDelay.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            InputDialogBuilder.repairWireDelayBuilder(
                    processParametersDataViewModel,
                    inputData -> updateProcessParamsDataAndSend()
            );
        });
        // 功率缓升
        binding.powerRampUp.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.powerRampUpBuilder(
                            processParametersDataViewModel,
                            inputData -> {
                                updateProcessParamsDataAndSend();
                                // 更新chart
                                updateWeldingChart();
                            }
                    );
                }
        );
        // 功率缓降
        binding.powerDescent.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.powerDescentBuilder(
                            processParametersDataViewModel,
                            inputData -> {
                                updateProcessParamsDataAndSend();
                                // 更新chart
                                updateWeldingChart();
                            }
                    );
                }
        );
        // 送丝速度
        binding.wireFeedingSpeed.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            InputDialogBuilder.wireFeedingSpeedBuilder(
                    processParametersDataViewModel,
                    inputData -> updateProcessParamsDataAndSend()
            );
        });
//        // 激光频率
//        binding.laserFrequency.setOnClickListener(v ->
//                InputDialogBuilder.laserFrequencyBuilder(
//                        processParametersDataViewModel,
//                        inputData -> binding.setProcessParametersDataViewModel(processParametersDataViewModel)
//                ));
//        // 激光占空比
//        binding.laserDutyCycle.setOnClickListener(v ->
//                InputDialogBuilder.laserDutyCycleBuilder(
//                        processParametersDataViewModel,
//                        inputData -> binding.setProcessParametersDataViewModel(processParametersDataViewModel)
//                ));
    }

    @Override
    protected void initData() {
        binding.setType(type);
        if (type != null && binding.continuousDeviceControls != null) {
            binding.continuousDeviceControls.setShowRampAccordion(
                    type == ModelConstant.CONTINUOUS_WELDING || type == ModelConstant.POINT_WELDING);
            binding.continuousDeviceControls.setWireControlsEnabled(
                    type == ModelConstant.CONTINUOUS_WELDING);
        }
        initChartView();
        if (type != null
                && binding.continuousDeviceControls != null
                && getActivity() instanceof EngineerModeActivity engineerModeActivity) {
            engineerModeActivity.attachDeviceControls(type, binding.continuousDeviceControls);
        }
        processParametersDataViewModel = new ViewModelProvider(this).get(ProcessParametersDataViewModel.class);
        ProcessParametersData quickEntry = null;
        if (getActivity() instanceof EngineerModeActivity engineerModeActivity) {
            quickEntry = engineerModeActivity.consumeQuickModeEntryFor(type);
        }
        processParametersDataViewModel.init(
                getContext().getApplicationContext(),
                this.type,
                true
        );
        processParametersDataViewModel.observeUnitDisplay(
                getViewLifecycleOwner(),
                () -> refreshProcessParameterUi());
        observeProcessParamsData();
        if (quickEntry != null) {
            processParametersDataViewModel.applyQuickModeEntry(quickEntry, null);
        } else {
            processParametersDataViewModel.loadInitialSessionIfNeeded();
        }
        processParametersDataViewModel.getAdvancedSettingLiveData().observe(getViewLifecycleOwner(), advancedSetting -> {
            try {
                refreshProcessParameterUi();
                updateWeldingChart();
            } catch (Exception exception) {
                Log.e(TAG, "initData: ", exception);
            }
        });
        processParametersDataViewModel.getListLiveData().observe(getViewLifecycleOwner(), processParametersData -> {
            Log.d(TAG, "onChanged: 数据变化[" + type + "]:" + processParametersData);
        });
    }

    /**
     * 工艺参数变更后刷新表单；ViewModel 实例不变时 DataBinding 不会自动重算 getter。
     */
    private void refreshProcessParameterUi() {
        if (processParametersDataViewModel == null || binding == null) {
            return;
        }
        Runnable refresh = () -> {
            if (processParametersDataViewModel == null || binding == null) {
                return;
            }
            binding.setProcessParametersDataViewModel(null);
            binding.setProcessParametersDataViewModel(processParametersDataViewModel);
            binding.executePendingBindings();
            binding.invalidateAll();
        };
        if (binding.getRoot().isAttachedToWindow()) {
            binding.getRoot().post(refresh);
        } else {
            refresh.run();
        }
    }

    private void applySessionFromLiveData() {
        applySessionToUi(processParametersDataViewModel != null
                ? processParametersDataViewModel.getData()
                : null);
    }

    private void applySessionToUi(ProcessParametersData processParametersData) {
        if (processParametersData == null || binding == null || processParametersDataViewModel == null) {
            return;
        }
        try {
            if (weldingChart != null) {
                weldingChart.initData(
                        processParametersData,
                        processParametersDataViewModel.getStartPower(),
                        processParametersDataViewModel.getEndPower());
            }
            refreshProcessParameterUi();
            if (processParametersDataViewModel.getDataProxy() != null
                    && processParametersDataViewModel.getDataProxy().getMaterialType() != null) {
                Integer icon = EngineerWeldingConvert.convertMaterialsIcon(
                        processParametersDataViewModel.getData().getMaterialType());
                binding.materialsIcon.setImageResource(icon);
            }
        } catch (Exception exception) {
            Log.e(TAG, "applySessionToUi: 初始化参数异常", exception);
        }
    }

    /**
     * 开启数据监听
     */
    private void observeProcessParamsData() {
        processParametersDataViewModel.getLiveData().removeObservers(getViewLifecycleOwner());
        processParametersDataViewModel.startInit();
        processParametersDataViewModel.getLiveData().observe(getViewLifecycleOwner(), processParametersData -> {
            Log.d(TAG, "onChanged: 数据变化:" + processParametersData);
            if (processParametersData == null) {
                return;
            }
            applySessionToUi(processParametersData);
            if (processParametersDataViewModel.isInit()) {
                processParametersDataViewModel.endInit();
                return;
            }
            if (engineerPageActiveListener == null || engineerPageActiveListener.isActivePage(type)) {
                sendDataProxy();
            } else {
                Log.d(TAG, "observeProcessParamsData: 当前页面未激活，不发送数据[" + type + "]");
            }
        });
        applySessionFromLiveData();
    }

    @Override
    public void onEngineerPageActivated() {
        if (binding == null) {
            return;
        }
        binding.getRoot().post(() -> {
            if (processParametersDataViewModel == null) {
                return;
            }
            if (processParametersDataViewModel.getData() != null) {
                applySessionFromLiveData();
            } else {
                processParametersDataViewModel.loadInitialSessionIfNeeded();
            }
        });
    }

    @Override
    public long fragmentId() {
        return type != null ? type : super.fragmentId();
    }

    public void initChartView() {
        if (type == null) {
            Log.e(TAG, "initChartView: 缺失工艺类型");
            return;
        }
        FrameLayout chartHost = resolveChartContent();
        EngineerRampChartAccordionBinding accordion = resolveRampAccordion();
        if (chartHost == null || accordion == null) {
            weldingChart = null;
            return;
        }
        if (type == ModelConstant.CONTINUOUS_WELDING) {
            weldingChart = new ContinuousWeldingLineChart(getContext());
        } else if (type == ModelConstant.POINT_WELDING) {
            weldingChart = new SpotWeldingLineChart(getContext());
        } else {
            weldingChart = null;
            return;
        }
        weldingChart.initChart();
        chartHost.removeAllViews();
        chartHost.addView(weldingChart.getView());
        bindRampAccordion(accordion);
        publishOpenRampChart(false);
    }

    @Nullable
    private FrameLayout resolveChartContent() {
        if (binding == null || binding.continuousDeviceControls == null) {
            return null;
        }
        if (type != null && (type == ModelConstant.CONTINUOUS_WELDING || type == ModelConstant.POINT_WELDING)) {
            return binding.continuousDeviceControls.chartContent;
        }
        return null;
    }

    @Nullable
    private EngineerRampChartAccordionBinding resolveRampAccordion() {
        if (binding == null || binding.continuousDeviceControls == null) {
            return null;
        }
        if (type != null && (type == ModelConstant.CONTINUOUS_WELDING || type == ModelConstant.POINT_WELDING)) {
            return binding.continuousDeviceControls.rampAccordion;
        }
        return null;
    }

    private void bindRampAccordion(@NonNull EngineerRampChartAccordionBinding accordion) {
        accordion.rampAccordionHeader.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            publishOpenRampChart(!openRampChart);
        });
    }

    private void publishOpenRampChart(boolean open) {
        openRampChart = open;
        if (binding == null || binding.continuousDeviceControls == null) {
            return;
        }
        binding.continuousDeviceControls.setOpenRampChart(open);
        if (binding.continuousDeviceControls.rampAccordion != null) {
            binding.continuousDeviceControls.rampAccordion.setOpenRampChart(open);
        }
    }

    private void updateWeldingChart() {
        if (weldingChart == null || processParametersDataViewModel == null) {
            return;
        }
        weldingChart.initData(
                processParametersDataViewModel.getData(),
                processParametersDataViewModel.getStartPower(),
                processParametersDataViewModel.getEndPower());
    }


    @Override
    protected void bindViewModel() {
        super.bindViewModel();
        // 使用DataBing+LiveData双向绑定
        binding.setEngineerWeldingFragment(this);
    }

    /**
     * 重置为默认数据
     */
    public void resetDefaultData() {
        GlobalSoundManager.playClickSound();
        processParametersDataViewModel.resetDefaultData((dataLiveData) -> applySessionFromLiveData());
        Log.d(TAG, "resetDefaultData: 重置");
    }

    /**
     * 设为常用参数
     */
    public void setCommonlyUsedParameter() {
        GlobalSoundManager.playClickSound();
        InputDialogBuilder.commonlyUsedParameterBuilder(processParametersDataViewModel, dataLiveData -> applySessionFromLiveData());
    }

    @Override
    public void sendData() {
        ThreadPoolManager.getExecutor().execute(() -> {
            if (processParametersDataViewModel==null){
                return;
            }
            processParametersDataViewModel.publishCurrentProcessParametersSnapshot();
            ModbusManagerRtu.get().writeRegisters(ModbusFiledBuilder.createProcessParametersData(processParametersDataViewModel.getDataProxy()));
        });
    }

    @Override
    public Double wireFeedSpeed() {
        if (processParametersDataViewModel == null) {
            return 0d;
        }
        LiveData<ProcessParametersData> liveData =
                processParametersDataViewModel.getLiveData();
        if (liveData == null || liveData.getValue() == null || liveData.getValue().getWireFeedSpeed() == null) {
            return 0d;
        }
        return liveData.getValue().getWireFeedSpeed();
    }

    /**
     * 参数校验
     * @return
     */
    @Override
    public boolean paramsCheck() {
        if (processParametersDataViewModel==null){
            return false;
        }
        return EngineerDataCheck.checkWeldingSendProcessParametersData(processParametersDataViewModel);
    }

    @Override
    public ProcessParametersData getProcessParametersData() {
        if (processParametersDataViewModel==null){
            return null;
        }
        return processParametersDataViewModel.getData();
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        if (weldingChart != null) {
            weldingChart.destroy();
            weldingChart = null;
        }
        if (processParametersDataViewModel != null) {
            Log.d(TAG, "onDestroyView: 正在销毁监听");
            processParametersDataViewModel.destroyAllLiveData(getViewLifecycleOwner());
        }
    }
    @Override
    public void updateProcessParamsDataAndSend() {
        refreshProcessParameterUi();
        sendDataProxy();
    }

    @Override
    public void sendDataProxy() {
        if (super.task != null) {
            handler.removeCallbacks(task);
        }
        super.task = this::sendData;
        handler.postDelayed(task, delayMillis);
    }
    @Override
    public void sendAdvanceSettingData() {
        if (processParametersDataViewModel == null) {
            return;
        }
        ProcessParametersData dataProxy = processParametersDataViewModel.getDataProxy();
        Integer laserPower = dataProxy != null ? dataProxy.getLaserPower() : null;
        processParametersDataViewModel.syncAndSendLaserTerminationPower(laserPower);
    }
}