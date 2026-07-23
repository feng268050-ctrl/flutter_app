package com.lasercyber.lws.ui.activitys.engineer.mode.fragment;

import android.text.Editable;
import android.util.Log;

import androidx.fragment.app.Fragment;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.ViewModelProvider;

import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.engineer.mode.EngineerModeActivity;
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
import com.lasercyber.lws.ui.common.utils.convert.EngineerWeldingConvert;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.databinding.FragmentEngineerWashBinding;

import java.util.List;
import java.util.Objects;

import lombok.Setter;

/**
 * A simple {@link Fragment} subclass.
 * Use the {@link EngineerWashFragment#newInstance} factory method to
 * create an instance of this fragment.
 * 清洗模式Fragment
 */
public class EngineerWashFragment extends BaseFragment<FragmentEngineerWashBinding> implements SendProcessParametersDataListener {
    private static final String TAG = LogTAGConstant.EngineerWashFragment;
    private ProcessParametersDataViewModel processParametersDataViewModel;
    /**
     * 焊接类型
     * {@link ModelConstant}
     */
    private Integer type;
    /**
     * 页面激活监听
     */
    @Setter
    private EngineerPageActiveListener engineerPageActiveListener;

    public EngineerWashFragment() {
        // Required empty public constructor
    }

    public EngineerWashFragment(Integer type) {
        this.type = type;
    }

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_engineer_wash;
    }

    @Override
    protected void initView() {
        binding.setOpenMoreCommon(Boolean.FALSE);
        binding.moreCommon.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            // 加载数据
            List<ProcessParametersNameData> parametersDataList = processParametersDataViewModel.getAllDataByType();
            if (parametersDataList == null || parametersDataList.isEmpty()) {
                ToastUtils.showShort(R.string.there_are_no_more_common_specs_available);
                return;
            }
//            processParametersDataViewModel.listAllDataName((parametersDataList)->{
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
                        binding.cleaningMaterialsInput.setText(inputData);
                        sendDataProxy();
                    });
                } else {
                    processParametersDataViewModel.setMaterialTypeFromLabel(dataListPopupItem.getName());
                    binding.materialsIcon.setImageResource(dataListPopupItem.getIconRes());
                    binding.cleaningMaterialsInput.setText(dataListPopupItem.getName());
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
        // 焊接宽度
        binding.swingWidth.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.weldWidthBuilder(
                            processParametersDataViewModel,
                            inputData -> {
                                // 绑定ViewModel并更新图表
                                updateProcessParamsDataAndSend();
                            }
                    );
                }
        );
        // 激光功率
        binding.laserPower.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.weldingPowerBuilder(
                            processParametersDataViewModel,
                            inputData -> {
                                // 绑定ViewModel并更新图表
                                updateProcessParamsDataAndSend();
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
                            inputData -> {
                                updateProcessParamsDataAndSend();
                            }
                    );
                }
        );
        // 功率缓升
        binding.powerRampUp.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.powerRampUpBuilder(
                            processParametersDataViewModel,
                            inputData -> {
                                // 绑定ViewModel并更新图表
                                updateProcessParamsDataAndSend();
                            }
                    );
                }
        );

        // 功率缓降
        binding.powerRampDown.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.powerDescentBuilder(
                            processParametersDataViewModel,
                            inputData -> {
                                // 绑定ViewModel并更新图表
                                updateProcessParamsDataAndSend();
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
                                // 绑定ViewModel并更新图表
                                updateProcessParamsDataAndSend();
                            }
                    );
                }
        );
        // 吹气延时
        binding.blowDelay.setOnClickListener(v ->
                {
                    GlobalSoundManager.playClickSound();
                    InputDialogBuilder.airOffDelayBuilder(
                            processParametersDataViewModel,
                            inputData -> {
                                // 绑定ViewModel并更新图表
                                updateProcessParamsDataAndSend();
                            }
                    );
                }
        );
//        // 激光占空比
//        binding.laserDutyCycle.setOnClickListener(v ->
//                InputDialogBuilder.laserDutyCycleBuilder(
//                        processParametersDataViewModel,
//                        inputData -> binding.setProcessParametersDataViewModel(processParametersDataViewModel)
//                ));
    }

    @Override
    protected void initData() {
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
            if (advancedSetting != null) {
                refreshProcessParameterUi();
                processParametersDataViewModel.getAdvancedSettingLiveData().removeObservers(EngineerWashFragment.this);
                Log.d(TAG, "onChanged: 高级配置加载成功，移除监听");
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
            refreshProcessParameterUi();
            if (processParametersDataViewModel.getDataProxy() != null
                    && processParametersDataViewModel.getDataProxy().getMaterialType() != null) {
                Integer icon = EngineerWeldingConvert.convertMaterialsIcon(
                        processParametersDataViewModel.getDataProxy().getMaterialType());
                binding.materialsIcon.setImageResource(icon);
            }
        } catch (Exception exception) {
            Log.d(TAG, "applySessionToUi: 初始化参数异常", exception);
        }
    }

    /**
     * 开启数据监听
     */
    private void observeProcessParamsData() {
        processParametersDataViewModel.getLiveData().removeObservers(getViewLifecycleOwner());
        processParametersDataViewModel.startInit();
        processParametersDataViewModel.getLiveData().observe(getViewLifecycleOwner(), processParametersData -> {
            Log.d(TAG, "initData: 获取数据成功:" + processParametersData);
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

    @Override
    protected void bindViewModel() {
        super.bindViewModel();
        binding.setEngineerWashFragment(this);
    }

    /**
     * 重置为默认数据
     */
    public void resetDefaultData() {
        Log.d(TAG, "resetDefaultData: 重置");
        processParametersDataViewModel.resetDefaultData(dataLiveData -> applySessionFromLiveData());
    }

    /**
     * 设为常用参数
     */
    public void setCommonlyUsedParameter() {
        InputDialogBuilder.commonlyUsedParameterBuilder(processParametersDataViewModel, dataLiveData -> applySessionFromLiveData());
    }

    public void changeTextValue(Editable value, String filedName) {
        Log.d(TAG, "changeTextValue: 字段名：" + filedName);
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
    public void sendData() {
        if (processParametersDataViewModel==null){
            return;
        }
        processParametersDataViewModel.publishCurrentProcessParametersSnapshot();
        ModbusManagerRtu.get().writeRegisters(ModbusFiledBuilder.createProcessParametersData(processParametersDataViewModel.getDataProxy()));
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
        return EngineerDataCheck.checkWashSendProcessParametersData(processParametersDataViewModel);
    }
    @Override
    public ProcessParametersData getProcessParametersData() {
        if (processParametersDataViewModel==null){
            return null;
        }
        return processParametersDataViewModel.getData();
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

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        if (processParametersDataViewModel != null) {
            Log.d(TAG, "onDestroyView: 正在销毁监听");
            processParametersDataViewModel.destroyAllLiveData(getViewLifecycleOwner());
        }
    }
}