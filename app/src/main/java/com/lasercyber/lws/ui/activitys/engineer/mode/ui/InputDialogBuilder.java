package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.lifecycle.LiveData;

import com.blankj.utilcode.util.ActivityUtils;
import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.ProcessParametersDataViewModel;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.ui.DataCheckResult;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.EngineerCommonlyUsedParameterNaming;
import com.lasercyber.lws.ui.common.utils.InchMillimeterUtils;
import com.lasercyber.lws.ui.component.dialog.FrostNumericInputDialog;
import com.lasercyber.lws.ui.component.dialog.FrostTextInputDialog;

import java.util.Objects;
import java.util.function.Consumer;

public class InputDialogBuilder {
    private static final String TAG = LogTAGConstant.InputDialogBuilder;

    private static int lengthUnitRes(boolean useMMUnit) {
        return useMMUnit ? R.string.mm_unit : R.string.in_unit;
    }

    private static int speedUnitRes(boolean useMMUnit) {
        return useMMUnit ? R.string.mm_s_unit : R.string.in_s_unit;
    }

    private static Context dialogContext() {
        Activity top = ActivityUtils.getTopActivity();
        return top != null ? top : Utils.getApp();
    }

    private static boolean isWeldingProcess(ProcessParametersDataViewModel processParametersDataViewModel) {
        return Objects.equals(processParametersDataViewModel.getType(), ModelConstant.CONTINUOUS_WELDING)
                || Objects.equals(processParametersDataViewModel.getType(), ModelConstant.POINT_WELDING);
    }

    private static int materialTitleRes(ProcessParametersDataViewModel processParametersDataViewModel) {
        if (Objects.equals(processParametersDataViewModel.getType(), ModelConstant.WELD_CLEAN)
                || Objects.equals(processParametersDataViewModel.getType(), ModelConstant.WIDTH_CLEAN)) {
            return R.string.cleaning_materials_text;
        }
        if (Objects.equals(processParametersDataViewModel.getType(), ModelConstant.HAND_CUT)
                || Objects.equals(processParametersDataViewModel.getType(), ModelConstant.CNC_CUT)) {
            return R.string.cutting_materials_text;
        }
        return R.string.welding_materials_text;
    }

    private static int thicknessTitleRes(ProcessParametersDataViewModel processParametersDataViewModel) {
        return Objects.equals(processParametersDataViewModel.getType(), ModelConstant.HAND_CUT)
                || Objects.equals(processParametersDataViewModel.getType(), ModelConstant.CNC_CUT)
                ? R.string.cutting_thickness_text
                : R.string.welding_thickness_text;
    }

    private static int swingWidthTitleRes(ProcessParametersDataViewModel processParametersDataViewModel) {
        return isWeldingProcess(processParametersDataViewModel)
                ? R.string.welding_width_text
                : R.string.swing_width_text;
    }

    private static int powerRampUpTitleRes(ProcessParametersDataViewModel processParametersDataViewModel) {
        return isWeldingProcess(processParametersDataViewModel)
                ? R.string.power_ramp_up_text
                : R.string.slow_rise_duration_text;
    }

    private static int powerRampDownTitleRes(ProcessParametersDataViewModel processParametersDataViewModel) {
        return isWeldingProcess(processParametersDataViewModel)
                ? R.string.power_ramp_down_text
                : R.string.slow_descent_duration_text;
    }

    private static void showIntegerWithUnit(
            int titleRes,
            int unitRes,
            @Nullable String defaultInput,
            @Nullable String descText,
            FrostNumericInputDialog.OnInputConfirmedListener listener) {
        showIntegerWithUnit(titleRes, unitRes, defaultInput, descText, 0, Integer.MAX_VALUE, listener);
    }

    private static void showIntegerWithUnit(
            int titleRes,
            int unitRes,
            @Nullable String defaultInput,
            @Nullable String descText,
            int minValue,
            int maxValue,
            FrostNumericInputDialog.OnInputConfirmedListener listener) {
        FrostNumericInputDialog.Config.Builder builder = FrostNumericInputDialog.Config
                .builder(Utils.getApp().getString(titleRes))
                .titleUnit(dialogContext(), unitRes)
                .integerNumberInput()
                .defaultInput(defaultInput)
                .minValue(minValue)
                .maxValue(maxValue);
        if (!StringUtils.isEmpty(descText)) {
            builder.descText(descText);
        }
        FrostNumericInputDialog.show(dialogContext(), builder.build(), listener);
    }

    private static void showDecimalWithUnit(
            int titleRes,
            int unitRes,
            @Nullable String defaultInput,
            @Nullable String descText,
            FrostNumericInputDialog.OnInputConfirmedListener listener) {
        showDecimalWithUnit(titleRes, unitRes, defaultInput, descText, 0, Integer.MAX_VALUE, listener);
    }

    private static void showDecimalWithUnit(
            int titleRes,
            int unitRes,
            @Nullable String defaultInput,
            @Nullable String descText,
            int minValue,
            int maxValue,
            FrostNumericInputDialog.OnInputConfirmedListener listener) {
        FrostNumericInputDialog.Config.Builder builder = FrostNumericInputDialog.Config
                .builder(Utils.getApp().getString(titleRes))
                .titleUnit(dialogContext(), unitRes)
                .decimalNumberInput()
                .defaultInput(defaultInput)
                .minValue(minValue)
                .maxValue(maxValue);
        if (!StringUtils.isEmpty(descText)) {
            builder.descText(descText);
        }
        FrostNumericInputDialog.show(dialogContext(), builder.build(), listener);
    }

    private static void showLengthDecimalWithUnit(
            int titleRes,
            boolean useMMUnit,
            @Nullable String defaultInput,
            @Nullable String descText,
            FrostNumericInputDialog.OnInputConfirmedListener listener) {
        showLengthDecimalWithUnit(
                titleRes, useMMUnit, defaultInput, descText, 0, Integer.MAX_VALUE, listener);
    }

    private static void showLengthDecimalWithUnit(
            int titleRes,
            boolean useMMUnit,
            @Nullable String defaultInput,
            @Nullable String descText,
            int minValue,
            int maxValue,
            FrostNumericInputDialog.OnInputConfirmedListener listener) {
        FrostNumericInputDialog.Config.Builder builder = FrostNumericInputDialog.Config
                .builder(Utils.getApp().getString(titleRes))
                .titleUnit(dialogContext(), lengthUnitRes(useMMUnit))
                .defaultInput(defaultInput)
                .minValue(minValue)
                .maxValue(maxValue);
        if (useMMUnit) {
            builder.decimalNumberInput();
        } else {
            builder.imperialDecimalNumberInput();
        }
        if (!StringUtils.isEmpty(descText)) {
            builder.descText(descText);
        }
        FrostNumericInputDialog.show(dialogContext(), builder.build(), listener);
    }

    public static void commonlyUsedParameterBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<LiveData<ProcessParametersData>> callBack) {
        Log.d(TAG, "commonlyUsedParameterBuilder: "
                + processParametersDataViewModel.getSuggestedCommonlyUsedParameterName());
        FrostTextInputDialog.show(dialogContext(), R.string.process_parameter_name,
                processParametersDataViewModel.getSuggestedCommonlyUsedParameterName(),
                inputData -> {
                    if (StringUtils.isEmpty(inputData)) {
                        ToastUtils.showShort(R.string.params_name_cannot_be_empty);
                        return false;
                    }
                    if (inputData.length() > EngineerCommonlyUsedParameterNaming.MAX_NAME_LENGTH) {
                        ToastUtils.showShort(R.string.the_process_parameter_name_max_length);
                        return false;
                    }
                    processParametersDataViewModel.getDataProxy().setName(inputData);
                    processParametersDataViewModel.saveCommonlyUsedParameter(callBack);
                    return true;
                });
    }

    public static void materialBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        String defaultText = !StringUtils.isEmpty(processParametersDataViewModel.getDataProxy().getMaterialName())
                ? processParametersDataViewModel.getDataProxy().getMaterialName() : "";
        FrostTextInputDialog.show(dialogContext(), materialTitleRes(processParametersDataViewModel),
                defaultText,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.materialCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setMaterialTypeFromLabel(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void thicknessBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        boolean useMMUnit = Boolean.TRUE.equals(processParametersDataViewModel.useMMUnit());
        showLengthDecimalWithUnit(
                thicknessTitleRes(processParametersDataViewModel),
                useMMUnit,
                processParametersDataViewModel.getThickness(),
                null,
                EngineerInputRangeText.metricStepperMin(useMMUnit, 1),
                EngineerInputRangeText.metricStepperMax(useMMUnit, 8),
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.thicknessCheck(
                            inputData, processParametersDataViewModel.useMMUnit());
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setThickness(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void pointWeldingIntervalBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showIntegerWithUnit(
                R.string.spot_welding_interval_t1_text,
                R.string.ms_unit,
                processParametersDataViewModel.getPointWeldingInterval(),
                Utils.getApp().getString(R.string.spot_welding_interval_t1_desc),
                0,
                10_000,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.pointWeldingIntervalCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setPointWeldingInterval(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void pointWeldingDurationBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showIntegerWithUnit(
                R.string.continuous_spot_welding_t2_text,
                R.string.ms_unit,
                processParametersDataViewModel.getPointWeldingDuration(),
                Utils.getApp().getString(R.string.continuous_spot_welding_t2_desc),
                0,
                10_000,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.pointWeldingDurationCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setPointWeldingDuration(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void weldingPowerBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showIntegerWithUnit(
                R.string.laser_power_text,
                R.string.percentage_unit,
                processParametersDataViewModel.getLaserPower(),
                Utils.getApp().getString(R.string.laser_power_desc_text),
                0,
                100,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.weldingPowerCheck(
                            inputData, processParametersDataViewModel.getStartPower());
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setLaserPower(dataCheckResult.getData());
                    int laserPower = Integer.parseInt(dataCheckResult.getData());
                    ThreadPoolManager.getExecutor().execute(() ->
                            processParametersDataViewModel.syncAndSendLaserTerminationPower(laserPower));
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void swingFrequencyBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        int processType = processParametersDataViewModel.getType() != null
                ? processParametersDataViewModel.getType()
                : ModelConstant.CONTINUOUS_WELDING;
        int minHz = processType == ModelConstant.POINT_WELDING ? 0 : 20;
        String desc = EngineerInputRangeText.frequencyRangeDesc(20, 220);
        showIntegerWithUnit(
                R.string.swing_frequency_text,
                R.string.hz_unit,
                processParametersDataViewModel.getSwingFrequency(),
                desc,
                minHz,
                220,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.swingFrequencyCheck(
                            inputData, processParametersDataViewModel.getType());
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setSwingFrequency(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void weldWidthBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        int processType = processParametersDataViewModel.getType() != null
                ? processParametersDataViewModel.getType()
                : ModelConstant.CONTINUOUS_WELDING;
        double maxMm = EngineerDataCheck.swingWidthMaxMm(processType);
        boolean useMMUnit = Boolean.TRUE.equals(processParametersDataViewModel.useMMUnit());
        String unit = Utils.getApp().getString(useMMUnit ? R.string.mm_unit : R.string.in_unit);
        String maxStr = useMMUnit
                ? String.valueOf((int) maxMm)
                : InchMillimeterUtils.mmToInStr(maxMm);
        String descText = Utils.getApp().getString(R.string.weld_width_desc, "0", maxStr, unit);
        int stepperMax = useMMUnit ? (int) maxMm : Integer.MAX_VALUE;
        showLengthDecimalWithUnit(
                swingWidthTitleRes(processParametersDataViewModel),
                useMMUnit,
                processParametersDataViewModel.getSwingWidth(),
                descText,
                0,
                stepperMax,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.swingWidthCheck(
                            inputData, processParametersDataViewModel.useMMUnit(), processType);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setSwingWidth(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void closeLightDelayBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showIntegerWithUnit(
                R.string.off_light_delay_text,
                R.string.ms_unit,
                processParametersDataViewModel.getCloseLightDelay(),
                Utils.getApp().getString(R.string.shutdown_delay_desc),
                0,
                1_000,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.closeLightDelayCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setCloseLightDelay(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void airOffDelayBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showIntegerWithUnit(
                R.string.blow_delay_text,
                R.string.ms_unit,
                processParametersDataViewModel.getBlowDelay(),
                Utils.getApp().getString(R.string.blow_delay_desc),
                0,
                10_000,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.blowDelayCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setBlowDelay(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void closeAirDelayBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showIntegerWithUnit(
                R.string.air_shut_off_delay_text,
                R.string.ms_unit,
                processParametersDataViewModel.getCloseAirDelay(),
                Utils.getApp().getString(R.string.air_shut_off_delay_desc),
                0,
                10_000,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.closeAirDelayCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setCloseAirDelay(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void pullbackLengthBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        boolean useMMUnit = Boolean.TRUE.equals(processParametersDataViewModel.useMMUnit());
        String descText = EngineerInputRangeText.lengthRangeDesc(
                R.string.pullback_length_desc, useMMUnit, 0, 35);
        showLengthDecimalWithUnit(
                R.string.retract_length_text,
                useMMUnit,
                processParametersDataViewModel.getRetractLength(),
                descText,
                0,
                EngineerInputRangeText.metricStepperMax(useMMUnit, 35),
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.retractLengthCheck(
                            inputData, processParametersDataViewModel.useMMUnit());
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setRetractLength(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void pullbackSpeedBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        boolean useMMUnit = Boolean.TRUE.equals(processParametersDataViewModel.useMMUnit());
        String descText = EngineerInputRangeText.speedRangeDesc(
                R.string.pullback_speed_desc, useMMUnit, 3, 100);
        showIntegerWithUnit(
                R.string.retract_speed_text,
                speedUnitRes(useMMUnit),
                processParametersDataViewModel.getRetractSpeed(),
                descText,
                EngineerInputRangeText.metricStepperMin(useMMUnit, 3),
                EngineerInputRangeText.metricStepperMax(useMMUnit, 100),
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.retractSpeedCheck(
                            inputData, processParametersDataViewModel.useMMUnit());
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setRetractSpeed(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void wireLengthBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        boolean useMMUnit = Boolean.TRUE.equals(processParametersDataViewModel.useMMUnit());
        String descText = EngineerInputRangeText.lengthRangeDesc(
                R.string.wire_length_desc, useMMUnit, 0, 35);
        showLengthDecimalWithUnit(
                R.string.fill_length_text,
                useMMUnit,
                processParametersDataViewModel.getFillLength(),
                descText,
                0,
                EngineerInputRangeText.metricStepperMax(useMMUnit, 35),
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.fillLengthCheck(
                            inputData, processParametersDataViewModel.useMMUnit());
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setFillLength(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void repairWireDelayBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showIntegerWithUnit(
                R.string.fill_delay_text,
                R.string.ms_unit,
                processParametersDataViewModel.getFillDelay(),
                Utils.getApp().getString(R.string.repair_wire_delay_desc),
                0,
                1_000,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.fillDelayCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setFillDelay(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void powerRampUpBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showIntegerWithUnit(
                powerRampUpTitleRes(processParametersDataViewModel),
                R.string.ms_unit,
                processParametersDataViewModel.getPowerRampUp(),
                Utils.getApp().getString(R.string.power_ramp_up_desc),
                0,
                1_000,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.powerRampUpCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setPowerRampUp(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void powerDescentBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showIntegerWithUnit(
                powerRampDownTitleRes(processParametersDataViewModel),
                R.string.ms_unit,
                processParametersDataViewModel.getPowerRampDown(),
                Utils.getApp().getString(R.string.power_descent_desc),
                0,
                1_000,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.powerRampDownCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setPowerRampDown(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void wireFeedingSpeedBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        boolean useMMUnit = Boolean.TRUE.equals(processParametersDataViewModel.useMMUnit());
        String descText = EngineerInputRangeText.speedRangeDesc(
                R.string.wire_feeding_speed_desc, useMMUnit, 0, 50);
        showIntegerWithUnit(
                R.string.wire_feed_speed_text,
                speedUnitRes(useMMUnit),
                processParametersDataViewModel.getWireFeedSpeed(),
                descText,
                0,
                EngineerInputRangeText.metricStepperMax(useMMUnit, 50),
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.wireFeedSpeedCheck(
                            inputData, processParametersDataViewModel.useMMUnit());
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setWireFeedSpeed(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void laserFrequencyBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        String descText = "";
        if (Objects.equals(processParametersDataViewModel.getType(), ModelConstant.HAND_CUT)) {
            descText = Utils.getApp().getString(R.string.laser_frequency_cut_desc);
        }
        showIntegerWithUnit(
                R.string.laser_frequency_text,
                R.string.hz_unit,
                processParametersDataViewModel.getLaserFrequency(),
                descText,
                1,
                5_000,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.laserFrequencyCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setLaserFrequency(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void laserDutyCycleBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        String descText = "";
        if (Objects.equals(processParametersDataViewModel.getType(), ModelConstant.HAND_CUT)) {
            descText = Utils.getApp().getString(R.string.laser_duty_cycle_cut_desc);
        }
        showIntegerWithUnit(
                R.string.laser_duty_cycle_text,
                R.string.percentage_unit,
                processParametersDataViewModel.getLaserDutyCycle(),
                descText,
                1,
                100,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.laserDutyCycleCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setLaserDutyCycle(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void perforationFrequencyBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showIntegerWithUnit(
                R.string.perforation_frequency_text,
                R.string.hz_unit,
                processParametersDataViewModel.getPerforationFrequency(),
                Utils.getApp().getString(R.string.perforation_frequency_desc),
                0,
                2_000,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.perforationFrequencyCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setPerforationFrequency(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void perforationDurationBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showDecimalWithUnit(
                R.string.perforation_duration_text,
                R.string.s_unit,
                processParametersDataViewModel.getPerforationDuration(),
                Utils.getApp().getString(R.string.perforation_duration_desc),
                0,
                2,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.perforationDurationCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setPerforationDuration(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void perforationPowerBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showIntegerWithUnit(
                R.string.perforation_power_text,
                R.string.percentage_unit,
                processParametersDataViewModel.getPerforationPower(),
                null,
                0,
                100,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.perforationPowerCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setPerforationPower(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }

    public static void perforationDutyCycleBuilder(
            ProcessParametersDataViewModel processParametersDataViewModel,
            Consumer<String> callBack) {
        showIntegerWithUnit(
                R.string.perforation_duty_cycle_text,
                R.string.percentage_unit,
                processParametersDataViewModel.getPerforationDutyCycle(),
                Utils.getApp().getString(R.string.perforation_duty_cycle_desc),
                0,
                100,
                inputData -> {
                    DataCheckResult dataCheckResult = EngineerDataCheck.perforationDutyCycleCheck(inputData);
                    if (!dataCheckResult.isSuccess()) {
                        return false;
                    }
                    processParametersDataViewModel.setPerforationDutyCycle(dataCheckResult.getData());
                    callBack.accept(inputData);
                    return true;
                });
    }
}
