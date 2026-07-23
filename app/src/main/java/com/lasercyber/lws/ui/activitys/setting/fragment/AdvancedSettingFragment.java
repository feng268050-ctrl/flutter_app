package com.lasercyber.lws.ui.activitys.setting.fragment;

import android.content.Context;
import android.text.Editable;
import android.util.Log;
import com.lasercyber.lws.frostui.control.interop.FrostSliderView;
import android.widget.SeekBar;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentActivity;
import androidx.lifecycle.ViewModelProvider;

import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ai.zeropoint.ZeroPointManualAutoCoordinator;
import com.lasercyber.lws.ai.zeropoint.ZeroPointPendingCorrectionStore;
import com.lasercyber.lws.ai.zeropoint.ZeroPointPendingJsonLoader;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.setting.model.AdvancedSettingViewModel;
import com.lasercyber.lws.ui.activitys.setting.ui.SettingInputDialogBuilder;
import com.lasercyber.lws.ui.bean.entity.vo.AdvancedSettingVo;
import com.lasercyber.lws.ui.common.config.AdvancedConfigUtil;
import com.lasercyber.lws.ui.common.settings.AiAssistanceSettings;
import com.lasercyber.lws.ui.common.handler.GpioLedHandler;
import com.lasercyber.lws.ui.common.settings.DangerousOperationsSettings;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusFiledBuilder;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusHexData;
import com.lasercyber.lws.ui.common.utils.TemperatureUnitConvertUtil;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.component.dialog.FrostDialog;
import com.lasercyber.lws.ui.component.dialog.ZeroPointAutoProgressDialog;
import com.lasercyber.lws.ui.databinding.FragmentAdvancedSettingBinding;

import java.util.List;

import cn.hutool.core.convert.Convert;

/**
 * A simple {@link Fragment} subclass.
 * create an instance of this fragment.
 * 高级设置
 */
public class AdvancedSettingFragment extends BaseFragment<FragmentAdvancedSettingBinding> {
    private static final String TAG = LogTAGConstant.AdvancedSettingFragment;
    @Nullable
    private ZeroPointAutoProgressDialog zeroPointAutoProgressDialog;

    /**
     * 数据模型
     */
    private AdvancedSettingViewModel advancedSettingViewModel;
    private boolean suppressAiAssistanceCallbacks;
    private boolean suppressDangerousOpsCallbacks;

    @Override
    protected int getLayoutId() {
        return R.layout.fragment_advanced_setting;
    }

    @Override
    protected void initView() {
        binding.setAdvancedSettingFragment(this);
        /*拖拽事件*/
        bindSeek();
        clickInput();
        bindAiAssistance();
        bindDangerousOperations();
    }

    @Override
    protected void initData() {
        advancedSettingViewModel = new ViewModelProvider(this).get(AdvancedSettingViewModel.class);
        advancedSettingViewModel.init(getContext());
        advancedSettingViewModel.observeCommonSettings(this);
        advancedSettingViewModel.getLiveData().observe(this, advancedSettingVo -> {
            Log.d(TAG, "initData: 监听到数据变化：" + advancedSettingVo);
            this.initInputData(advancedSettingVo);
        });
        binding.setAdvancedSettingViewModel(advancedSettingViewModel);
    }

    /*初始化赋值*/
    private void initInputData(AdvancedSettingVo vo) {
        refreshTemperatureDisplays();
        renderAiAssistanceSwitches(vo);
        renderDangerousOperationsSwitches(vo);
    }

    private void bindAiAssistance() {
        binding.lensContaminationDetectionSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressAiAssistanceCallbacks) {
                return;
            }
            GlobalSoundManager.playClickSound();
            Context context = getContext();
            if (context == null) {
                return;
            }
            AiAssistanceSettings.setLensContaminationDetectionEnabled(context, isChecked);
            AdvancedSettingVo vo = advancedSettingViewModel.getData();
            if (vo != null) {
                vo.setLensContaminationDetectionEnabled(isChecked);
            }
        });
        binding.zeroPointOffsetDetectionSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressAiAssistanceCallbacks) {
                return;
            }
            GlobalSoundManager.playClickSound();
            Context context = getContext();
            if (context == null) {
                return;
            }
            AiAssistanceSettings.setZeroPointOffsetDetectionEnabled(context, isChecked);
            AdvancedSettingVo vo = advancedSettingViewModel.getData();
            if (vo != null) {
                vo.setZeroPointOffsetDetectionEnabled(isChecked);
            }
        });
    }

    private void renderAiAssistanceSwitches(@Nullable AdvancedSettingVo vo) {
        if (binding == null || vo == null) {
            return;
        }
        suppressAiAssistanceCallbacks = true;
        binding.lensContaminationDetectionSwitch.setChecked(
                vo.getLensContaminationDetectionEnabled() == null || vo.getLensContaminationDetectionEnabled());
        binding.zeroPointOffsetDetectionSwitch.setChecked(
                vo.getZeroPointOffsetDetectionEnabled() == null || vo.getZeroPointOffsetDetectionEnabled());
        suppressAiAssistanceCallbacks = false;
    }

    private void bindDangerousOperations() {
        binding.keepLaserOnWhileAlarmedSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressDangerousOpsCallbacks) {
                return;
            }
            GlobalSoundManager.playClickSound();
            Context context = getContext();
            if (context == null) {
                return;
            }
            DangerousOperationsSettings.setKeepLaserOnWhileAlarmed(context, isChecked);
            AdvancedSettingVo vo = advancedSettingViewModel.getData();
            if (vo != null) {
                vo.setKeepLaserOnWhileAlarmed(isChecked);
            }
        });
        binding.allowWorkAfterCameraAlarmSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressDangerousOpsCallbacks) {
                return;
            }
            GlobalSoundManager.playClickSound();
            Context context = getContext();
            if (context == null) {
                return;
            }
            DangerousOperationsSettings.setAllowWorkAfterCameraAlarm(context, isChecked);
            AdvancedSettingVo vo = advancedSettingViewModel.getData();
            if (vo != null) {
                vo.setAllowWorkAfterCameraAlarm(isChecked);
            }
            GpioLedHandler.refresh();
        });
        binding.allowWorkAfterGasAlarmSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressDangerousOpsCallbacks) {
                return;
            }
            GlobalSoundManager.playClickSound();
            Context context = getContext();
            if (context == null) {
                return;
            }
            DangerousOperationsSettings.setAllowWorkAfterGasAlarm(context, isChecked);
            AdvancedSettingVo vo = advancedSettingViewModel.getData();
            if (vo != null) {
                vo.setAllowWorkAfterGasAlarm(isChecked);
            }
            GpioLedHandler.refresh();
        });
        binding.allowWorkAfterLensContaminationSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressDangerousOpsCallbacks) {
                return;
            }
            GlobalSoundManager.playClickSound();
            Context context = getContext();
            if (context == null) {
                return;
            }
            DangerousOperationsSettings.setAllowWorkAfterLensContamination(context, isChecked);
            AdvancedSettingVo vo = advancedSettingViewModel.getData();
            if (vo != null) {
                vo.setAllowWorkAfterLensContamination(isChecked);
            }
            GpioLedHandler.refresh();
        });
        binding.allowWorkAfterFeederAlarmSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (suppressDangerousOpsCallbacks) {
                return;
            }
            GlobalSoundManager.playClickSound();
            Context context = getContext();
            if (context == null) {
                return;
            }
            DangerousOperationsSettings.setAllowWorkAfterFeederAlarm(context, isChecked);
            AdvancedSettingVo vo = advancedSettingViewModel.getData();
            if (vo != null) {
                vo.setAllowWorkAfterFeederAlarm(isChecked);
            }
            GpioLedHandler.refresh();
        });
    }

    private void renderDangerousOperationsSwitches(@Nullable AdvancedSettingVo vo) {
        if (binding == null || vo == null) {
            return;
        }
        suppressDangerousOpsCallbacks = true;
        binding.keepLaserOnWhileAlarmedSwitch.setChecked(
                Boolean.TRUE.equals(vo.getKeepLaserOnWhileAlarmed()));
        binding.allowWorkAfterCameraAlarmSwitch.setChecked(
                Boolean.TRUE.equals(vo.getAllowWorkAfterCameraAlarm()));
        binding.allowWorkAfterGasAlarmSwitch.setChecked(
                Boolean.TRUE.equals(vo.getAllowWorkAfterGasAlarm()));
        binding.allowWorkAfterLensContaminationSwitch.setChecked(
                Boolean.TRUE.equals(vo.getAllowWorkAfterLensContamination()));
        binding.allowWorkAfterFeederAlarmSwitch.setChecked(
                Boolean.TRUE.equals(vo.getAllowWorkAfterFeederAlarm()));
        suppressDangerousOpsCallbacks = false;
    }

    private void refreshTemperatureDisplays() {
        AdvancedSettingVo vo = advancedSettingViewModel.getData();
        if (vo == null) {
            return;
        }
        Boolean unitSetting = vo.getUnitSetting();
        String celsiusUnit = getString(R.string.celsius_unit);
        String fahrenheitUnit = getString(R.string.fahrenheit_unit);

        binding.driverTemperatureAlarmThresholdText.setText(vo.getDriverTemperatureAlarmThresholdDisplay());
        binding.protectiveLensTemperatureAlarmThresholdText.setText(vo.getProtectiveLensTemperatureAlarmThresholdDisplay());
        binding.collimatingLensTemperatureAlarmThresholdText.setText(vo.getCollimatingLensTemperatureAlarmThresholdDisplay());
        binding.motorTemperatureAlarmThresholdText.setText(vo.getMotorTemperatureAlarmThresholdDisplay());
        binding.temperatureAlarmRecoveryIntervalText.setText(vo.getTemperatureAlarmRecoveryIntervalDisplay());

        setSliderScaleLabels(binding.temperatureAlarmRecoveryInterval, 0, 20, unitSetting, celsiusUnit, fahrenheitUnit);
        setSliderScaleLabels(binding.protectiveLensTemperatureAlarmThreshold, 0, 85, unitSetting, celsiusUnit, fahrenheitUnit);
        setSliderScaleLabels(binding.collimatingLensTemperatureAlarmThreshold, 0, 85, unitSetting, celsiusUnit, fahrenheitUnit);
        setSliderScaleLabels(binding.motorTemperatureAlarmThreshold, 0, 80, unitSetting, celsiusUnit, fahrenheitUnit);
        setSliderScaleLabels(binding.driverTemperatureAlarmThreshold, 0, 80, unitSetting, celsiusUnit, fahrenheitUnit);
    }

    private void setSliderScaleLabels(FrostSliderView slider, int minValue, int maxValue,
                                      Boolean unitSetting, String celsiusUnit, String fahrenheitUnit) {
        if (slider == null) {
            return;
        }
        slider.setScaleMinText(TemperatureUnitConvertUtil.formatScaleLabel(minValue, unitSetting, celsiusUnit, fahrenheitUnit));
        slider.setScaleMaxText(TemperatureUnitConvertUtil.formatScaleLabel(maxValue, unitSetting, celsiusUnit, fahrenheitUnit));
    }

    @Override
    protected void bindViewModel() {
        super.bindViewModel();
    }

    /*点击输入框的反馈音*/
    private void clickInput() {
        FragmentActivity activity = getActivity();
        if (activity == null) {
            Log.e(TAG, "clickInput: 初始化高级设置页面异常，FragmentActivity为空");
            return;
        }
        binding.blowPressureThresholdText.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            SettingInputDialogBuilder.GasPressureThresholdBuilder(advancedSettingViewModel, s -> {
                // 更新到数据库并下发
                updateAndSendData();
                sendSeek(s, "blowPressureThreshold");
                upInput(s, "blowPressureThreshold");
            });
        });
        binding.zeroPointCorrection.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            SettingInputDialogBuilder.zeroPointCorrectionBuilder(advancedSettingViewModel, s -> {
                // 更新到数据库并下发
                updateAndSendData();
                sendSeek(s, "zeroPointCorrection");
                upInput(s, "zeroPointCorrection");
            });
        });
        binding.zeroPointAuto.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            startZeroPointAutoWithTeaching();
        });
        binding.layoutScanWidthOffset.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            SettingInputDialogBuilder.laserTerminationPowerBuilder(advancedSettingViewModel, s -> {
                // 更新到数据库并下发
                updateAndSendData();
                sendSeek(s, "laserEndPower");
                upInput(s, "laserEndPower");
            });
        });
        binding.laserStartPowerText.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            SettingInputDialogBuilder.laserStartingPowerBuilder(advancedSettingViewModel, s -> {
                // 更新到数据库并下发
                updateAndSendData();
                sendSeek(s, "laserStartPower");
                upInput(s, "laserStartPower");
            });
        });
        binding.properSwingWidthText.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            SettingInputDialogBuilder.scanWidthCorrectionBuilder(advancedSettingViewModel, s -> {
                // 更新到数据库并下发
                updateAndSendData();
                sendSeek(s, "properSwingWidth");
                upInput(s, "properSwingWidth");
            });
        });
        binding.driverTemperatureAlarmThresholdText.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            SettingInputDialogBuilder.driverTemperatureAlarmThresholdBuilder(advancedSettingViewModel, s -> {
                updateAndSendData();
                sendSeek(s, "driverTemperatureAlarmThreshold");
                upInput(s, "driverTemperatureAlarmThreshold");
            });
        });
        binding.protectiveLensTemperatureAlarmThresholdText.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            SettingInputDialogBuilder.protectiveLensTemperatureAlarmThresholdBuilder(advancedSettingViewModel, s -> {
                updateAndSendData();
                sendSeek(s, "protectiveLensTemperatureAlarmThreshold");
                upInput(s, "protectiveLensTemperatureAlarmThreshold");
            });
        });
        binding.collimatingLensTemperatureAlarmThresholdText.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            SettingInputDialogBuilder.collimatingLensTemperatureAlarmThresholdBuilder(advancedSettingViewModel, s -> {
                updateAndSendData();
                sendSeek(s, "collimatingLensTemperatureAlarmThreshold");
                upInput(s, "collimatingLensTemperatureAlarmThreshold");
            });
        });
        binding.motorTemperatureAlarmThresholdText.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            SettingInputDialogBuilder.motorTemperatureAlarmThresholdBuilder(advancedSettingViewModel, s -> {
                updateAndSendData();
                sendSeek(s, "motorTemperatureAlarmThreshold");
                upInput(s, "motorTemperatureAlarmThreshold");
            });
        });
        binding.temperatureAlarmRecoveryIntervalText.setOnClickListener(v ->
        {
            GlobalSoundManager.playClickSound();
            SettingInputDialogBuilder.temperatureAlarmRecoveryIntervalBuilder(advancedSettingViewModel, s -> {
                updateAndSendData();
                sendSeek(s, "temperatureAlarmRecoveryInterval");
                upInput(s, "temperatureAlarmRecoveryInterval");
            });
        });
    }

    private void startZeroPointAutoWithTeaching() {
        Context context = getContext();
        if (context == null) {
            return;
        }
        if (ZeroPointManualAutoCoordinator.getInstance().isRunning()) {
            ToastUtils.showShort(R.string.zero_point_auto_busy);
            return;
        }
        if (!ZeroPointPendingCorrectionStore.getInstance().hasFreshPending()) {
            ZeroPointPendingJsonLoader.tryHydratePendingFromFile();
        }
        if (ZeroPointPendingCorrectionStore.getInstance().hasFreshPending()) {
            beginZeroPointAuto();
            return;
        }
        FrostDialog.prompt(context)
                .title(R.string.zero_point_auto_title)
                .message(R.string.zero_point_auto_teaching_message)
                .confirmText(R.string.confirm_text)
                .cancelText(R.string.cancel_text)
                .onConfirm(this::beginZeroPointAuto)
                .show();
    }

    private void beginZeroPointAuto() {
        Context context = getContext();
        if (context == null) {
            return;
        }
        dismissZeroPointAutoProgress();
        binding.zeroPointAuto.setEnabled(false);
        zeroPointAutoProgressDialog = ZeroPointAutoProgressDialog.show(
                context,
                getString(R.string.zero_point_auto_title),
                () -> ZeroPointManualAutoCoordinator.getInstance().cancel());
        if (zeroPointAutoProgressDialog == null) {
            binding.zeroPointAuto.setEnabled(true);
            ToastUtils.showShort(R.string.zero_point_auto_busy);
            return;
        }
        boolean started = ZeroPointManualAutoCoordinator.getInstance().start(
                context,
                new ZeroPointManualAutoCoordinator.Callback() {
                    @Override
                    public void onProgress(int percent, @NonNull String message) {
                        if (zeroPointAutoProgressDialog != null) {
                            zeroPointAutoProgressDialog.updateProgress(percent, message);
                        }
                    }

                    @Override
                    public void onComplete(@NonNull ZeroPointManualAutoCoordinator.CompletionResult result) {
                        dismissZeroPointAutoProgress();
                        if (binding != null) {
                            binding.zeroPointAuto.setEnabled(true);
                            String value = String.valueOf(result.newUi);
                            upInput(value, "zeroPointCorrection");
                            sendSeek(value, "zeroPointCorrection");
                            AdvancedSettingVo data = advancedSettingViewModel.getData();
                            if (data != null) {
                                advancedSettingViewModel.updateLiveData(data);
                            }
                        }
                    }

                    @Override
                    public void onFailure(@NonNull String message) {
                        dismissZeroPointAutoProgress();
                        if (binding != null) {
                            binding.zeroPointAuto.setEnabled(true);
                        }
                        ToastUtils.showShort(message);
                    }

                    @Override
                    public void onCancelled() {
                        dismissZeroPointAutoProgress();
                        if (binding != null) {
                            binding.zeroPointAuto.setEnabled(true);
                        }
                    }
                });
        if (!started) {
            dismissZeroPointAutoProgress();
            binding.zeroPointAuto.setEnabled(true);
            ToastUtils.showShort(R.string.zero_point_auto_busy);
        }
    }

    private void dismissZeroPointAutoProgress() {
        if (zeroPointAutoProgressDialog != null) {
            zeroPointAutoProgressDialog.dismiss();
            zeroPointAutoProgressDialog = null;
        }
    }

    private void updateAndSendData() {
        advancedSettingViewModel.updateDataToDb();
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        List<ModbusHexData> writeDeviceSetting = ModbusFiledBuilder.createWriteDeviceSetting(data);
        ModbusManagerRtu.get().writeRegisters(writeDeviceSetting);
    }

    /*绑定拖拽事件*/
    public void bindSeek() {
        bindSeekBarListener(binding.zeroPointCorrectionSeek, "zeroPointCorrection");
        bindSeekBarListener(binding.properSwingWidth, "properSwingWidth");
        bindSeekBarListener(binding.laserStartPower, "laserStartPower");
        bindSeekBarListener(binding.layoutScanOffset, "laserEndPower");
        bindSeekBarListener(binding.blowPressureThreshold, "blowPressureThreshold");
        bindSeekBarListener(binding.driverTemperatureAlarmThreshold, "driverTemperatureAlarmThreshold");
        bindSeekBarListener(binding.protectiveLensTemperatureAlarmThreshold, "protectiveLensTemperatureAlarmThreshold");
        bindSeekBarListener(binding.collimatingLensTemperatureAlarmThreshold, "collimatingLensTemperatureAlarmThreshold");
        bindSeekBarListener(binding.motorTemperatureAlarmThreshold, "motorTemperatureAlarmThreshold");
        bindSeekBarListener(binding.temperatureAlarmRecoveryInterval, "temperatureAlarmRecoveryInterval");
    }

    private void bindSeekBarListener(FrostSliderView seekBar, String fieldName) {
        final boolean[] userDragging = {false};
        final boolean[] pendingCommit = {false};
        seekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar s, int progress, boolean fromUser) {
                if (fromUser) {
                    upInput(String.valueOf(progress), fieldName);
                    pendingCommit[0] = true;
                } else if (userDragging[0]) {
                    previewInput(String.valueOf(progress), fieldName);
                }
            }

            @Override
            public void onStartTrackingTouch(SeekBar s) {
                userDragging[0] = true;
                pendingCommit[0] = false;
                GlobalSoundManager.playClickSound();
            }

            @Override
            public void onStopTrackingTouch(SeekBar s) {
                if (userDragging[0]) {
                    userDragging[0] = false;
                    if (pendingCommit[0]) {
                        pendingCommit[0] = false;
                        updateAndSendData();
                    }
                }
            }
        });
    }


    /**
     * 刷新数据到库
     *
     * @param value
     * @param filedName
     */
    public void changeTextValue(Editable value, String filedName, Integer min, Integer max) {

        if (min == null || max == null || StringUtils.isEmpty(value) || StringUtils.equals("-", value)) {
            return;
        }

        if (super.task != null) {
            handler.removeCallbacks(super.task);
        }

        //1、如果超出限制，则还原并返回。
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        Boolean bl = AdvancedConfigUtil.verifyData(filedName, data, min, max);
        if (!bl) {
            //1、提示超出范围
            ToastUtils.showShort(" out of range ， value rollback ！");
            //2、将参数退回一位,如果低于最小值，则设置为最小值
            outInput(value.toString(), filedName, min);
            return;
        }

        //2、更新数据
        super.task = () -> {
            advancedSettingViewModel.updateDataToDb();
            List<ModbusHexData> writeDeviceSetting = ModbusFiledBuilder.createWriteDeviceSetting(data);
            ModbusManagerRtu.get().writeRegisters(writeDeviceSetting);
            //同步字段到seek
            sendSeek(value.toString(), filedName);
        };
        handler.postDelayed(super.task, delayMillis);
    }

    /* 输入框的参数退回一位 */
    private void outInput(String value, String filedName, Integer min) {

        if (!StringUtils.isEmpty(value)) {
            value = value.substring(0, value.length() - 1);
        } else if (StringUtils.isEmpty(value)) {
            value = "0";
        } else {
            value = min + "";
        }
        upInput(value, filedName);
    }

    private void previewInput(String value, String filedName) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        if (data == null) {
            return;
        }

        if (filedName.equals("zeroPointCorrection")) {
            binding.zeroPointCorrection.setText(value);
        }
        if (filedName.equals("properSwingWidth")) {
            binding.properSwingWidthText.setText(value);
        }
        if (filedName.equals("laserStartPower")) {
            binding.laserStartPowerText.setText(value);
        }
        if (filedName.equals("laserEndPower")) {
            binding.layoutScanWidthOffset.setText(value);
        }
        if (filedName.equals("blowPressureThreshold")) {
            binding.blowPressureThresholdText.setText(value);
        }
        if (filedName.equals("driverTemperatureAlarmThreshold")) {
            previewInputTemperature(value, data, binding.driverTemperatureAlarmThresholdText::setText);
        }
        if (filedName.equals("protectiveLensTemperatureAlarmThreshold")) {
            previewInputTemperature(value, data, binding.protectiveLensTemperatureAlarmThresholdText::setText);
        }
        if (filedName.equals("collimatingLensTemperatureAlarmThreshold")) {
            previewInputTemperature(value, data, binding.collimatingLensTemperatureAlarmThresholdText::setText);
        }
        if (filedName.equals("motorTemperatureAlarmThreshold")) {
            previewInputTemperature(value, data, binding.motorTemperatureAlarmThresholdText::setText);
        }
        if (filedName.equals("temperatureAlarmRecoveryInterval")) {
            previewInputTemperature(value, data, binding.temperatureAlarmRecoveryIntervalText::setText);
        }
    }

    private void previewInputTemperature(
            String celsiusValue,
            AdvancedSettingVo data,
            java.util.function.Consumer<String> textSetter
    ) {
        int celsius = Convert.toInt(celsiusValue, 0);
        textSetter.accept(TemperatureUnitConvertUtil.toDisplay(celsius, data.getUnitSetting()));
    }

    private void upInput(String value, String filedName) {
        AdvancedSettingVo data = advancedSettingViewModel.getData();
        if (data == null) {
            return;
        }

        if (filedName.equals("zeroPointCorrection")) {
            binding.zeroPointCorrection.setText(value);
            data.setZeroPointCorrection(value);
        }
        if (filedName.equals("properSwingWidth")) {
            binding.properSwingWidthText.setText(value);
            data.setProperSwingWidth(value);
        }
        if (filedName.equals("laserStartPower")) {
            binding.laserStartPowerText.setText(value);
            data.setLaserStartPower(value);
        }
        if (filedName.equals("laserEndPower")) {
            binding.layoutScanWidthOffset.setText(value);
            data.setLaserEndPower(value);
        }
        if (filedName.equals("blowPressureThreshold")) {
            binding.blowPressureThresholdText.setText(value);
            data.setBlowPressureThreshold(value);
        }
        if (filedName.equals("driverTemperatureAlarmThreshold")) {
            upInputTemperature(value, data, binding.driverTemperatureAlarmThresholdText::setText,
                    data::setDriverTemperatureAlarmThreshold);
        }
        if (filedName.equals("protectiveLensTemperatureAlarmThreshold")) {
            upInputTemperature(value, data, binding.protectiveLensTemperatureAlarmThresholdText::setText,
                    data::setProtectiveLensTemperatureAlarmThreshold);
        }
        if (filedName.equals("collimatingLensTemperatureAlarmThreshold")) {
            upInputTemperature(value, data, binding.collimatingLensTemperatureAlarmThresholdText::setText,
                    data::setCollimatingLensTemperatureAlarmThreshold);
        }
        if (filedName.equals("motorTemperatureAlarmThreshold")) {
            upInputTemperature(value, data, binding.motorTemperatureAlarmThresholdText::setText,
                    data::setMotorTemperatureAlarmThreshold);
        }
        if (filedName.equals("temperatureAlarmRecoveryInterval")) {
            upInputTemperature(value, data, binding.temperatureAlarmRecoveryIntervalText::setText,
                    data::setTemperatureAlarmRecoveryInterval);
        }
    }

    private void upInputTemperature(
            String celsiusValue,
            AdvancedSettingVo data,
            java.util.function.Consumer<String> textSetter,
            java.util.function.Consumer<String> fieldSetter
    ) {
        fieldSetter.accept(celsiusValue);
        int celsius = Convert.toInt(celsiusValue, 0);
        textSetter.accept(TemperatureUnitConvertUtil.toDisplay(celsius, data.getUnitSetting()));
    }

    /*输入框内容联动进度条*/
    private void sendSeek(String value, String filedName) {
        Integer anInt = Convert.toInt(value);
        if (null == anInt) {
            anInt = 0;
        }
        if (filedName.equals("zeroPointCorrection"))
            binding.zeroPointCorrectionSeek.setProgress(anInt);
        if (filedName.equals("properSwingWidth")) binding.properSwingWidth.setProgress(anInt);
        if (filedName.equals("laserStartPower")) binding.laserStartPower.setProgress(anInt);
        if (filedName.equals("laserEndPower")) binding.layoutScanOffset.setProgress(anInt);
        if (filedName.equals("blowPressureThreshold"))
            binding.blowPressureThreshold.setProgress(anInt);
        if (filedName.equals("driverTemperatureAlarmThreshold"))
            binding.driverTemperatureAlarmThreshold.setProgress(anInt);
        if (filedName.equals("protectiveLensTemperatureAlarmThreshold"))
            binding.protectiveLensTemperatureAlarmThreshold.setProgress(anInt);
        if (filedName.equals("collimatingLensTemperatureAlarmThreshold"))
            binding.collimatingLensTemperatureAlarmThreshold.setProgress(anInt);
        if (filedName.equals("motorTemperatureAlarmThreshold"))
            binding.motorTemperatureAlarmThreshold.setProgress(anInt);
        if (filedName.equals("temperatureAlarmRecoveryInterval"))
            binding.temperatureAlarmRecoveryInterval.setProgress(anInt);
    }

    @Override
    public void onDestroyView() {
        ZeroPointManualAutoCoordinator.getInstance().cancel();
        dismissZeroPointAutoProgress();
        super.onDestroyView();
    }
}
