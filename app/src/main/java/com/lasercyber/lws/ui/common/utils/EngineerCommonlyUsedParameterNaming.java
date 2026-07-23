package com.lasercyber.lws.ui.common.utils;

import androidx.annotation.Nullable;

import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.utils.convert.ProcessDataExcelConvert;

import java.util.Objects;

/**
 * Default engineer-mode common-preset names (Save as Common dialog and bootstrap import).
 */
public final class EngineerCommonlyUsedParameterNaming {

    public static final int MAX_NAME_LENGTH = 32;

    private EngineerCommonlyUsedParameterNaming() {
    }

    /**
     * Save as Common dialog default: localized material label, thickness + unit for non-clean modes.
     */
    public static String forSaveAsCommon(
            @Nullable String materialLabel,
            @Nullable ProcessParametersData data,
            boolean useMmUnit
    ) {
        if (StringUtils.isEmpty(materialLabel) || data == null) {
            return "";
        }
        Integer processType = data.getProcessType();
        if (isCleanProcessType(processType)) {
            return truncate(materialLabel);
        }
        return buildWithDimension(materialLabel, processType, data.getThickness(), data.getSwingWidth(), useMmUnit);
    }

    /**
     * Bootstrap preset name: English material label, thickness or swing width + unit.
     */
    public static String forBootstrapPreset(@Nullable ProcessParametersData data, boolean useMmUnit) {
        if (data == null) {
            return "";
        }
        String materialLabel = ProcessDataExcelConvert.toEnglishMaterialName(
                data.getMaterialType(),
                data.getMaterialName()
        );
        if (StringUtils.isEmpty(materialLabel)) {
            return "";
        }
        return buildWithDimension(
                materialLabel,
                data.getProcessType(),
                data.getThickness(),
                data.getSwingWidth(),
                useMmUnit
        );
    }

    private static String buildWithDimension(
            String materialLabel,
            @Nullable Integer processType,
            @Nullable Double thicknessMm,
            @Nullable Double swingWidthMm,
            boolean useMmUnit
    ) {
        String dimensionLabel = isCleanProcessType(processType)
                ? formatSwingWidth(swingWidthMm, useMmUnit)
                : formatThickness(thicknessMm, useMmUnit);
        if (StringUtils.isEmpty(dimensionLabel)) {
            return truncate(materialLabel);
        }
        return truncate(materialLabel + "-" + dimensionLabel + unitLabel(useMmUnit));
    }

    private static String unitLabel(boolean useMmUnit) {
        return useMmUnit ? "mm" : "in";
    }

    private static boolean isCleanProcessType(@Nullable Integer processType) {
        return Objects.equals(processType, ModelConstant.WELD_CLEAN)
                || Objects.equals(processType, ModelConstant.WIDTH_CLEAN);
    }

    @Nullable
    private static String formatThickness(@Nullable Double thicknessMm, boolean useMmUnit) {
        if (thicknessMm == null) {
            return null;
        }
        return useMmUnit
                ? ProcessParameterDisplayFormat.asDecimal(thicknessMm)
                : InchMillimeterUtils.mmToInStr(thicknessMm);
    }

    @Nullable
    private static String formatSwingWidth(@Nullable Double swingWidthMm, boolean useMmUnit) {
        if (swingWidthMm == null) {
            return null;
        }
        return useMmUnit
                ? ProcessParameterDisplayFormat.asDecimal(swingWidthMm)
                : InchMillimeterUtils.mmToInStr(swingWidthMm);
    }

    private static String truncate(String value) {
        if (value == null) {
            return "";
        }
        return value.length() > MAX_NAME_LENGTH ? value.substring(0, MAX_NAME_LENGTH) : value;
    }
}
