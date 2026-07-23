package com.lasercyber.lws.ui.common.utils.convert;

import android.content.Context;
import android.text.TextUtils;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.EngineerWelding;
import com.lasercyber.lws.ui.bean.entity.vo.EngineerWeldingVo;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;

import java.util.Objects;

public class EngineerWeldingConvert {
    /**
     * 转换材质的图标
     * @param materials
     * @return
     */
    public static Integer convertMaterialsIcon(Integer materials) {
        if (materials==null){
            return null;
        }
        if (Objects.equals(materials, MaterialTypeEnum.STAINLESS_STEEL.getType())){
            return R.mipmap.stainless_steel_icon;
        } else if (Objects.equals(materials, MaterialTypeEnum.CARBON_STEEL.getType())){
            return R.mipmap.carbon_steel_icon;
        } else if (Objects.equals(materials, MaterialTypeEnum.GALVANIZED_SHEET.getType())){
            return R.mipmap.galvanized_sheet_icon;
        } else if (Objects.equals(materials, MaterialTypeEnum.ALUMINUM_ALLOY.getType())){
            return R.mipmap.aluminum_alloy_icon;
        } else if (Objects.equals(materials, MaterialTypeEnum.BRASS.getType())){
            return R.mipmap.brass_icon;
        } else if (Objects.equals(materials, MaterialTypeEnum.CUSTOMIZE.getType())){
            return R.mipmap.customize_icon;
        }
        return R.mipmap.customize_icon;
    }
    /**
     * 转换焊接材料
     *
     * @param weldingMaterials
     * @param context
     * @return
     */
    @Deprecated
    public static String convertWeldingMaterialsText(Integer weldingMaterials, Context context) {
        if (weldingMaterials==null){
            return null;
        }
        if (context == null) {
            return String.valueOf(weldingMaterials);
        }
        return switch (weldingMaterials) {
            case 1 -> context.getString(R.string.stainless_steel_text);
            case 2 -> context.getString(R.string.carbon_steel_text);
            case 3 -> context.getString(R.string.galvanized_sheet_text);
            case 4 -> context.getString(R.string.aluminum_alloy_text);
            case 5 -> context.getString(R.string.brass_text);
            case 6 -> context.getString(R.string.customize_text);
            default -> String.valueOf(weldingMaterials);
        };
    }

    /**
     * 反转 convertWeldingMaterialsText 方法：根据材料文本获取对应的编码
     *
     * @param weldingMaterialsText 材料文本（如"不锈钢"、"碳钢"，或直接传入资源ID对应的字符串）
     * @param context              上下文（用于获取资源字符串，非必须，若文本已明确可传null）
     * @return 对应的编码（1=不锈钢，2=碳钢...6=自定义，无匹配时返回null或默认值）
     */
    public static Integer reverseConvertWeldingMaterials(String weldingMaterialsText, Context context) {
        // 1. 处理空值：文本为空直接返回null
        if (TextUtils.isEmpty(weldingMaterialsText)) {
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
            if (stainlessSteel.equals(weldingMaterialsText)) {
                return 1;
            } else if (carbonSteel.equals(weldingMaterialsText)) {
                return 2;
            } else if (galvanizedSheet.equals(weldingMaterialsText)) {
                return 3;
            } else if (aluminumAlloy.equals(weldingMaterialsText)) {
                return 4;
            } else if (brass.equals(weldingMaterialsText)) {
                return 5;
            } else if (customize.equals(weldingMaterialsText)) {
                return 6;
            } else {
                // 无匹配时，尝试解析为数字（适配原方法的 default 逻辑）
                return tryParseDefault(weldingMaterialsText);
            }
        }
        return tryParseDefault(weldingMaterialsText);
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
     * 将EngineerWelding转换为EngineerWeldingVo
     *
     * @param engineerWelding 实体类对象
     * @return 对应的VO对象
     */
    public static EngineerWeldingVo convertToVo(EngineerWelding engineerWelding, Context context) {
        if (engineerWelding == null) {
            return null;
        }
        EngineerWeldingVo vo = new EngineerWeldingVo();
        vo.setId(engineerWelding.getId());
        vo.setWeldingMaterials(convertWeldingMaterialsText(engineerWelding.getWeldingMaterials(), context));
        vo.setWeldingThickness(convertToString(engineerWelding.getWeldingThickness()));
        vo.setPointWeldingInterval(convertToString(engineerWelding.getPointWeldingInterval()));
        vo.setPointWeldingDuration(convertToString(engineerWelding.getPointWeldingDuration()));
        vo.setWeldingPower(convertToString(engineerWelding.getWeldingPower()));
        vo.setSwingFrequency(convertToString(engineerWelding.getSwingFrequency()));
        vo.setWeldingWidth(convertToString(engineerWelding.getWeldingWidth()));
        vo.setCloseLightDelay(convertToString(engineerWelding.getCloseLightDelay()));
        vo.setBlowDelay(convertToString(engineerWelding.getBlowDelay()));
        vo.setCloseAirDelay(convertToString(engineerWelding.getCloseAirDelay()));
        vo.setType(engineerWelding.getType());
        return vo;
    }

    /**
     * 将EngineerWeldingVo转换为EngineerWelding
     *
     * @param vo VO对象
     * @return 对应的实体类对象
     */
    public static EngineerWelding convertToEntity(EngineerWeldingVo vo, Context context) {
        if (vo == null) {
            return null;
        }
        EngineerWelding entity = new EngineerWelding();
        entity.setId(vo.getId());
        entity.setWeldingMaterials(reverseConvertWeldingMaterials(vo.getWeldingMaterials(), context));
        entity.setWeldingThickness(convertToDouble(vo.getWeldingThickness()));
        entity.setPointWeldingInterval(convertToInteger(vo.getPointWeldingInterval()));

        entity.setPointWeldingDuration(convertToInteger(vo.getPointWeldingDuration()));
        entity.setWeldingPower(convertToInteger(vo.getWeldingPower()));
        entity.setSwingFrequency(convertToInteger(vo.getSwingFrequency()));
        entity.setWeldingWidth(convertToInteger(vo.getWeldingWidth()));
        entity.setCloseLightDelay(convertToInteger(vo.getCloseLightDelay()));
        entity.setBlowDelay(convertToInteger(vo.getBlowDelay()));
        entity.setCloseAirDelay(convertToInteger(vo.getCloseAirDelay()));
        // 注意：VO中没有type字段，实体类的type需要根据实际业务场景设置默认值或其他处理
        entity.setType(vo.getType()); // 可根据实际需求修改
        return entity;
    }

    /**
     * 将对象转换为字符串，null时返回空字符串
     */
    private static String convertToString(Object obj) {
        return obj != null ? obj.toString() : "";
    }

    /**
     * 将字符串转换为Integer，空字符串或转换失败时返回null
     */
    private static Integer convertToInteger(String str) {
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
     * 将字符串转换为Double，空字符串或转换失败时返回null
     */
    private static Double convertToDouble(String str) {
        if (str == null || str.trim().isEmpty()) {
            return null;
        }
        try {
            return Double.parseDouble(str.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
