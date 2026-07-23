package com.lasercyber.lws.ui.common.utils;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.CommonSettings;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.ui.LabelValueListItem;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;
import com.lasercyber.lws.ui.common.enums.UnitSystem;
import com.lasercyber.lws.ui.common.utils.convert.EngineerWashConvert;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

/**
 * Builds read-only process-parameter rows for dialogs, mirroring visible Engineer Mode fields
 * per {@code processType}. See {@code fragment_engineer_welding.xml},
 * {@code fragment_engineer_wash.xml}, and {@code fragment_engineer_cutting.xml}.
 */
public final class ProcessParameterDisplayRows {

    private ProcessParameterDisplayRows() {
    }

    @NonNull
    public static List<LabelValueListItem> build(
            @NonNull ProcessParametersData data,
            boolean useMMUnit) {
        return build(data, useMMUnit, Utils.getApp());
    }

    @NonNull
    public static List<LabelValueListItem> build(
            @NonNull ProcessParametersData data,
            boolean useMMUnit,
            @NonNull Context context) {
        if (data.getProcessType() == null) {
            return List.of(
                    nameRow(context, data),
                    processTypeRow(context, data));
        }
        return switch (data.getProcessType()) {
            case ModelConstant.CONTINUOUS_WELDING -> weldingRows(context, data, useMMUnit, false);
            case ModelConstant.POINT_WELDING -> weldingRows(context, data, useMMUnit, true);
            case ModelConstant.WELD_CLEAN, ModelConstant.WIDTH_CLEAN -> washRows(context, data, useMMUnit);
            case ModelConstant.HAND_CUT, ModelConstant.CNC_CUT -> cuttingRows(context, data, useMMUnit);
            default -> List.of(
                    nameRow(context, data),
                    processTypeRow(context, data));
        };
    }

    /** Reads {@link CommonSettings}; must not be called on the main thread. */
    public static boolean resolveUseMMUnit() {
        CommonSettings settings = AppDatabase.getInstance(Utils.getApp()).commonSettingsDao().selectOne();
        return settings == null
                || settings.getUnit() == null
                || UnitSystem.fromWireValue(settings.getUnit()) == UnitSystem.METRIC;
    }

    @NonNull
    private static List<LabelValueListItem> weldingRows(
            @NonNull Context context,
            @NonNull ProcessParametersData data,
            boolean useMMUnit,
            boolean pointWelding) {
        ArrayList<LabelValueListItem> rows = new ArrayList<>();
        addNameAndProcessTypeRows(rows, context, data);
        rows.add(row(context, R.string.welding_materials_text, materialLabel(data), null));
        rows.add(lengthRow(context, R.string.welding_thickness_text, data.getThickness(), useMMUnit));
        if (pointWelding) {
            rows.add(intRow(context, R.string.spot_welding_interval_t1_text, data.getPointWeldingInterval(), R.string.ms_unit));
            rows.add(intRow(context, R.string.continuous_spot_welding_t2_text, data.getPointWeldingDuration(), R.string.ms_unit));
        }
        rows.add(intRow(context, R.string.blow_delay_text, data.getBlowDelay(), R.string.ms_unit));
        if (!pointWelding) {
            rows.add(intRow(context, R.string.power_ramp_up_text, data.getPowerRampUp(), R.string.ms_unit));
        }
        rows.add(intRow(context, R.string.laser_power_text, data.getLaserPower(), R.string.percentage_unit));
        if (!pointWelding) {
            rows.add(intRow(context, R.string.power_ramp_down_text, data.getPowerRampDown(), R.string.ms_unit));
        }
        rows.add(intRow(context, R.string.air_shut_off_delay_text, data.getCloseAirDelay(), R.string.ms_unit));
        rows.add(intRow(context, R.string.swing_frequency_text, data.getSwingFrequency(), R.string.hz_unit));
        rows.add(lengthRow(context, R.string.welding_width_text, data.getSwingWidth(), useMMUnit));
        if (!pointWelding) {
            rows.add(speedRow(context, R.string.wire_feed_speed_text, data.getWireFeedSpeed(), useMMUnit));
            rows.add(intRow(context, R.string.off_light_delay_text, data.getCloseLightDelay(), R.string.ms_unit));
            rows.add(lengthRow(context, R.string.retract_length_text, data.getRetractLength(), useMMUnit));
            rows.add(speedRow(context, R.string.retract_speed_text, data.getRetractSpeed(), useMMUnit));
            rows.add(lengthRow(context, R.string.fill_length_text, data.getFillLength(), useMMUnit));
            rows.add(intRow(context, R.string.fill_delay_text, data.getFillDelay(), R.string.ms_unit));
        } else {
            rows.add(intRow(context, R.string.off_light_delay_text, data.getCloseLightDelay(), R.string.ms_unit));
        }
        return rows;
    }

    @NonNull
    private static List<LabelValueListItem> washRows(
            @NonNull Context context,
            @NonNull ProcessParametersData data,
            boolean useMMUnit) {
        int materialLabelRes = data.getProcessType() == ModelConstant.WIDTH_CLEAN
                ? R.string.cleaning_materials_text
                : R.string.cleaning_materials_text;
        int widthLabelRes = data.getProcessType() == ModelConstant.WIDTH_CLEAN
                ? R.string.swing_width_text
                : R.string.swing_width_text;
        ArrayList<LabelValueListItem> rows = new ArrayList<>();
        addNameAndProcessTypeRows(rows, context, data);
        rows.add(row(context, materialLabelRes, materialLabel(data), null));
        rows.add(intRow(context, R.string.laser_power_text, data.getLaserPower(), R.string.percentage_unit));
        rows.add(intRow(context, R.string.swing_frequency_text, data.getSwingFrequency(), R.string.hz_unit));
        rows.add(lengthRow(context, widthLabelRes, data.getSwingWidth(), useMMUnit));
        rows.add(intRow(context, R.string.blow_delay_text, data.getBlowDelay(), R.string.ms_unit));
        rows.add(intRow(context, R.string.air_shut_off_delay_text, data.getCloseAirDelay(), R.string.ms_unit));
        rows.add(intRow(context, R.string.slow_rise_duration_text, data.getPowerRampUp(), R.string.ms_unit));
        rows.add(intRow(context, R.string.slow_descent_duration_text, data.getPowerRampDown(), R.string.ms_unit));
        return rows;
    }

    @NonNull
    private static List<LabelValueListItem> cuttingRows(
            @NonNull Context context,
            @NonNull ProcessParametersData data,
            boolean useMMUnit) {
        ArrayList<LabelValueListItem> rows = new ArrayList<>();
        addNameAndProcessTypeRows(rows, context, data);
        rows.add(row(context, R.string.cutting_materials_text, materialLabel(data), null));
        rows.add(lengthRow(context, R.string.cutting_thickness_text, data.getThickness(), useMMUnit));
        rows.add(intRow(context, R.string.laser_power_text, data.getLaserPower(), R.string.percentage_unit));
        rows.add(intRow(context, R.string.blow_delay_text, data.getBlowDelay(), R.string.ms_unit));
        rows.add(intRow(context, R.string.air_shut_off_delay_text, data.getCloseAirDelay(), R.string.ms_unit));
        rows.add(intRow(context, R.string.slow_rise_duration_text, data.getPowerRampUp(), R.string.ms_unit));
        rows.add(intRow(context, R.string.slow_descent_duration_text, data.getPowerRampDown(), R.string.ms_unit));
        return rows;
    }

    @NonNull
    private static LabelValueListItem processTypeRow(
            @NonNull Context context,
            @NonNull ProcessParametersData data) {
        return row(
                context,
                R.string.ai_vision_process_type_text,
                ModelConstant.convertToText(data.getProcessType()),
                null);
    }

    private static void addNameAndProcessTypeRows(
            @NonNull ArrayList<LabelValueListItem> rows,
            @NonNull Context context,
            @NonNull ProcessParametersData data) {
        rows.add(nameRow(context, data));
        rows.add(processTypeRow(context, data));
    }

    @NonNull
    private static LabelValueListItem nameRow(@NonNull Context context, @NonNull ProcessParametersData data) {
        String name = data.getName() == null
                ? ""
                : MaterialDisplayNameUtils.localizeKnownMaterialName(data.getName(), data.getMaterialType());
        return row(context, R.string.process_parameter_name, name, null);
    }

    @NonNull
    private static LabelValueListItem row(
            @NonNull Context context,
            int labelRes,
            @Nullable String value,
            @Nullable String unit) {
        return new LabelValueListItem(
                context.getString(labelRes),
                value == null ? "" : value,
                unit);
    }

    @NonNull
    private static LabelValueListItem intRow(
            @NonNull Context context,
            int labelRes,
            @Nullable Integer value,
            int unitRes) {
        return row(
                context,
                labelRes,
                value == null ? "" : ProcessParameterDisplayFormat.asInteger(value),
                context.getString(unitRes));
    }

    @NonNull
    private static LabelValueListItem lengthRow(
            @NonNull Context context,
            int labelRes,
            @Nullable Double valueMm,
            boolean useMMUnit) {
        if (valueMm == null) {
            return row(context, labelRes, "", useMMUnit ? context.getString(R.string.mm_unit) : context.getString(R.string.in_unit));
        }
        String formatted = useMMUnit
                ? ProcessParameterDisplayFormat.asDecimal(valueMm)
                : InchMillimeterUtils.mmToInStr(valueMm);
        String unit = useMMUnit ? context.getString(R.string.mm_unit) : context.getString(R.string.in_unit);
        return row(context, labelRes, formatted, unit);
    }

    @NonNull
    private static LabelValueListItem speedRow(
            @NonNull Context context,
            int labelRes,
            @Nullable Double valueMmPerSecond,
            boolean useMMUnit) {
        if (valueMmPerSecond == null) {
            return row(
                    context,
                    labelRes,
                    "",
                    useMMUnit ? context.getString(R.string.mm_s_unit) : context.getString(R.string.in_s_unit));
        }
        String formatted = useMMUnit
                ? ProcessParameterDisplayFormat.asInteger(valueMmPerSecond)
                : ProcessParameterDisplayFormat.asDecimal(
                        InchMillimeterUtils.mmToInPerSecond(valueMmPerSecond));
        String unit = useMMUnit ? context.getString(R.string.mm_s_unit) : context.getString(R.string.in_s_unit);
        return row(context, labelRes, formatted, unit);
    }

    @NonNull
    private static String materialLabel(@NonNull ProcessParametersData data) {
        if (data.getMaterialType() == null) {
            return "";
        }
        if (Objects.equals(data.getMaterialType(), MaterialTypeEnum.CUSTOMIZE.getType())
                && !StringUtils.isEmpty(data.getMaterialName())) {
            return data.getMaterialName();
        }
        String text = EngineerWashConvert.convertCleaningMaterialsText(data.getMaterialType());
        return StringUtils.isEmpty(text) ? "" : text;
    }

    @VisibleForTesting
    static int rowCountForProcessType(int processType, boolean pointWelding) {
        return switch (processType) {
            case ModelConstant.CONTINUOUS_WELDING -> 17;
            case ModelConstant.POINT_WELDING -> 12;
            case ModelConstant.WELD_CLEAN, ModelConstant.WIDTH_CLEAN -> 10;
            case ModelConstant.HAND_CUT, ModelConstant.CNC_CUT -> 9;
            default -> 1;
        };
    }

    @VisibleForTesting
    @Nullable
    static String formatThickness(@Nullable Double thicknessMm, boolean useMMUnit) {
        if (thicknessMm == null) {
            return "";
        }
        return useMMUnit
                ? ProcessParameterDisplayFormat.asDecimal(thicknessMm)
                : InchMillimeterUtils.mmToInStr(thicknessMm);
    }

    @VisibleForTesting
    @Nullable
    static String formatSwingWidth(@Nullable Double swingWidthMm, boolean useMMUnit) {
        if (swingWidthMm == null) {
            return "";
        }
        return useMMUnit
                ? ProcessParameterDisplayFormat.asDecimal(swingWidthMm)
                : InchMillimeterUtils.mmToInStr(swingWidthMm);
    }
}
