package com.lasercyber.lws.ui.common.utils.convert;

import android.content.Context;
import android.text.TextUtils;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.EngineerCutting;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.vo.EngineerCuttingVo;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;

public class EngineerCuttingConvert {

    /**
     * 转换焊接材料
     *
     * @param cuttingMaterials
     * @param context
     * @return
     */
    @Deprecated
    public static String convertCleaningMaterialsText(Integer cuttingMaterials, Context context) {
        if (cuttingMaterials == null) {
            return null;
        }
        if (context == null) {
            return String.valueOf(cuttingMaterials);
        }
        return switch (cuttingMaterials) {
            case 1 -> context.getString(R.string.stainless_steel_text);
            case 2 -> context.getString(R.string.carbon_steel_text);
            case 3 -> context.getString(R.string.galvanized_sheet_text);
            case 4 -> context.getString(R.string.aluminum_alloy_text);
            case 5 -> context.getString(R.string.brass_text);
            case 6 -> context.getString(R.string.customize_text);
            default -> String.valueOf(cuttingMaterials);
        };
    }

    /**
     * 反转 convertCleaningMaterialsText 方法：根据材料文本获取对应的编码
     *
     * @param cuttingMaterialsText 材料文本（如"不锈钢"、"碳钢"，或直接传入资源ID对应的字符串）
     * @param context              上下文（用于获取资源字符串，非必须，若文本已明确可传null）
     * @return 对应的编码（1=不锈钢，2=碳钢...6=自定义，无匹配时返回null或默认值）
     */
    public static Integer reverseConvertCleaningMaterials(String cuttingMaterialsText, Context context) {
        // 1. 处理空值：文本为空直接返回null
        if (TextUtils.isEmpty(cuttingMaterialsText)) {
            return null;
        }

        // 2. 优先通过 Context 匹配资源字符串（推荐，适配多语言）
        if (context != null) {
            String stainlessSteel = context.getString(R.string.stainless_steel_text);
            String carbonSteel = context.getString(R.string.carbon_steel_text);
            String galvanizedSheet = context.getString(R.string.galvanized_sheet_text);
            String aluminumAlloy = context.getString(R.string.aluminum_alloy_text);
            String brass = context.getString(R.string.brass_text);
            String customize = context.getString(R.string.customize_text);

            // 用 if-else 匹配动态资源字符串（避免 switch 的常量要求）
            if (stainlessSteel.equals(cuttingMaterialsText)) {
                return 1;
            } else if (carbonSteel.equals(cuttingMaterialsText)) {
                return 2;
            } else if (galvanizedSheet.equals(cuttingMaterialsText)) {
                return 3;
            } else if (aluminumAlloy.equals(cuttingMaterialsText)) {
                return 4;
            } else if (brass.equals(cuttingMaterialsText)) {
                return 5;
            } else if (customize.equals(cuttingMaterialsText)) {
                return 6;
            } else {
                // 无匹配时，尝试解析为数字（适配原方法的 default 逻辑）
                return tryParseDefault(cuttingMaterialsText);
            }
        }
        return tryParseDefault(cuttingMaterialsText);
    }

    /**
     * 辅助方法：默认情况下尝试将文本解析为Integer（适配原方法的 default 逻辑）
     *
     * @param text 待解析文本
     * @return 解析后的Integer，失败返回null
     */
    private static Integer tryParseDefault(String text) {
        try {
            return Integer.parseInt(text.trim());
        } catch (NumberFormatException e) {
            return null; // 无法解析为数字时返回null（可根据业务改为返回默认值，如-1）
        }
    }

    /**
     * 将 EngineerCutting 转换为 EngineerCuttingVo
     * @param entity 数据库实体类
     * @return 视图对象
     */
    public static EngineerCuttingVo toVo(EngineerCutting entity,Context context) {
        if (entity == null) {
            return null;
        }
        EngineerCuttingVo vo = new EngineerCuttingVo();
        vo.setId(entity.getId());
        vo.setCuttingMaterials(convertCleaningMaterialsText(entity.getCuttingMaterials(),context) );
        vo.setCuttingThickness(entity.getCuttingThickness() != null ? entity.getCuttingThickness().toString() : "");
        vo.setLaserPower(entity.getLaserPower() != null ? entity.getLaserPower().toString() : "");
        vo.setLaserFrequency(entity.getLaserFrequency() != null ? entity.getLaserFrequency().toString() : "");
        vo.setLaserDutyCycle(entity.getLaserDutyCycle() != null ? entity.getLaserDutyCycle().toString() : "");
        vo.setBlowDelay(entity.getBlowDelay() != null ? entity.getBlowDelay().toString() : "");
        vo.setCloseAirDelay(entity.getCloseAirDelay() != null ? entity.getCloseAirDelay().toString() : "");
        vo.setSlowRiseDuration(entity.getSlowRiseDuration() != null ? entity.getSlowRiseDuration().toString() : "");
        vo.setSlowDescentDuration(entity.getSlowDescentDuration() != null ? entity.getSlowDescentDuration().toString() : "");
        vo.setPerforationFrequency(entity.getPerforationFrequency() != null ? entity.getPerforationFrequency().toString() : "");
        vo.setPerforationDuration(entity.getPerforationDuration() != null ? entity.getPerforationDuration().toString() : "");
        return vo;
    }

    /**
     * 将 EngineerCuttingVo 转换为 EngineerCutting
     * @param vo 视图对象
     * @return 数据库实体类
     */
    public static EngineerCutting toEntity(EngineerCuttingVo vo,Context context) {
        if (vo == null) {
            return null;
        }
        EngineerCutting entity = new EngineerCutting();
        entity.setId(vo.getId());
        entity.setCuttingMaterials(reverseConvertCleaningMaterials(vo.getCuttingMaterials(),context));
        entity.setCuttingThickness(parseInteger(vo.getCuttingThickness()));
        entity.setLaserPower(parseInteger(vo.getLaserPower()));
        entity.setLaserFrequency(parseInteger(vo.getLaserFrequency()));
        entity.setLaserDutyCycle(parseInteger(vo.getLaserDutyCycle()));
        entity.setBlowDelay(parseInteger(vo.getBlowDelay()));
        entity.setCloseAirDelay(parseInteger(vo.getCloseAirDelay()));
        entity.setSlowRiseDuration(parseInteger(vo.getSlowRiseDuration()));
        entity.setSlowDescentDuration(parseInteger(vo.getSlowDescentDuration()));
        entity.setPerforationFrequency(parseInteger(vo.getPerforationFrequency()));
        entity.setPerforationDuration(parseDouble(vo.getPerforationDuration()));
        return entity;
    }

    /**
     * 字符串转Integer工具方法
     * @param str 待转换字符串
     * @return 转换后的Integer，转换失败返回null
     */
    private static Integer parseInteger(String str) {
        if (str == null || str.trim().isEmpty()) {
            return null;
        }
        try {
            return Integer.parseInt(str.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /**
     * 字符串转Double工具方法
     * @param str 待转换字符串
     * @return 转换后的Double，转换失败返回null
     */
    private static Double parseDouble(String str) {
        if (str == null || str.trim().isEmpty()) {
            return null;
        }
        try {
            return Double.parseDouble(str.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
    /**
     * 将EngineerCutting对象的属性合并到ProcessParametersData中
     * @param cutting 切割参数对象
     * @param data 要合并到的工艺参数数据对象
     */
    public static ProcessParametersData mergeCuttingToProcessData(EngineerCutting cutting, ProcessParametersData data) {
        if (cutting == null) {
            return data;
        }
        if (data==null){
            // 创建默认的工艺参数数据对象
            data= DefaultValueUtils.createDefaultProcessParametersData();
        }
        data.setLaserPower(cutting.getLaserPower());
        data.setLaserFrequency(cutting.getLaserFrequency());
        data.setLaserDutyCycle(cutting.getLaserDutyCycle());
        data.setBlowDelay(cutting.getBlowDelay());
        data.setCloseAirDelay(cutting.getCloseAirDelay());
        data.setPerforationFrequency(cutting.getPerforationFrequency());
        data.setPerforationDuration(cutting.getPerforationDuration());
        return data;
    }
}
