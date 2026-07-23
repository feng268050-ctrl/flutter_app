package com.lasercyber.lws.ui.common.utils.convert;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.constant.ProcessDataType;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;

import java.util.Objects;

/**
 * 工艺参数的枚举值转换工具类
 */
public class ProcessDataExcelConvert {
    /**
     * 转换材质的枚举值
     *
     * @param value
     * @return
     */
    public static Integer convertMaterials(String value) {
        return switch (value) {
            case "Stainless Steel" -> MaterialTypeEnum.STAINLESS_STEEL.getType();
            case "Carbon Steel" -> MaterialTypeEnum.CARBON_STEEL.getType();
            case "Galvanized Sheet" -> MaterialTypeEnum.GALVANIZED_SHEET.getType();
            case "Aluminum Alloy" -> MaterialTypeEnum.ALUMINUM_ALLOY.getType();
            case "Brass" -> MaterialTypeEnum.BRASS.getType();
            case "Custom" -> MaterialTypeEnum.CUSTOMIZE.getType();
            default -> MaterialTypeEnum.CUSTOMIZE.getType();
        };
    }

    /**
     * 转换数据类型的枚举值
     *
     * @param value
     * @return
     */
    public static Integer convertProcessDataType(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return switch (trimmed) {
            case "快速模式参数", "快速模式工艺数据" -> ProcessDataType.QUICK_MODE_DATA;
            case "工程师模式常用参数", "工程师模式内置参数", "工程师模式默认数据" ->
                    ProcessDataType.ENGINEER_MODE_DATA;
            case "工程师模式自定义参数", "工程师模式自定义数据" -> ProcessDataType.ENGINEER_MODE_DATA;
            case "视频工艺参数", "视频中的工艺库数据" -> ProcessDataType.VIDEO_PROCESS_DATA;
            default -> null;
        };
    }

    /**
     * 材料对应的英文名称（与工艺库 Excel「材料」列一致）。
     */
    @Nullable
    public static String toEnglishMaterialName(@Nullable Integer materialType, @Nullable String materialName) {
        if (Objects.equals(materialType, MaterialTypeEnum.CUSTOMIZE.getType())) {
            return materialName == null || materialName.isBlank() ? "Custom" : materialName.trim();
        }
        if (materialType == null) {
            return materialName == null || materialName.isBlank() ? null : materialName.trim();
        }
        return switch (materialType) {
            case 1 -> "Stainless Steel";
            case 2 -> "Carbon Steel";
            case 3 -> "Galvanized Sheet";
            case 4 -> "Aluminum Alloy";
            case 5 -> "Brass";
            default -> materialName == null || materialName.isBlank() ? "Custom" : materialName.trim();
        };
    }

    /**
     * 工艺类型对应的英文名称（与工艺库 Excel「工艺类型」列一致）。
     */
    public static String toEnglishProcessTypeName(int processType) {
        return switch (processType) {
            case ModelConstant.CONTINUOUS_WELDING -> "Continuous Weld";
            case ModelConstant.POINT_WELDING -> "Spot Weld";
            case ModelConstant.WELD_CLEAN -> "Weld Path Clean";
            case ModelConstant.WIDTH_CLEAN -> "Ultra-wide Clean";
            case ModelConstant.HAND_CUT -> "Cut";
            case ModelConstant.CNC_CUT -> "CNC Cut";
            default -> "Unknown";
        };
    }

    /**
     * 转换工艺类型的枚举值
     *
     * @param value
     * @return
     */
    public static Integer convertProcessType(String value) {
        return switch (value) {
            case "Continuous Weld" -> ModelConstant.CONTINUOUS_WELDING;
            case "Spot Weld" -> ModelConstant.POINT_WELDING;
            case "Spot welding" -> ModelConstant.POINT_WELDING;
            case "Weld Path Clean" -> ModelConstant.WELD_CLEAN;
            case "Ultra-wide Clean" -> ModelConstant.WIDTH_CLEAN;
            case "Cut" -> ModelConstant.HAND_CUT;
            case "CNC Cut" -> ModelConstant.CNC_CUT;
            default -> null;
        };
    }
}
