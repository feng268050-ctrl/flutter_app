package com.lasercyber.lws.ui.common.utils.convert;

import android.content.Context;
import android.text.TextUtils;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.EngineerWash;
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;
import com.lasercyber.lws.ui.bean.entity.vo.EngineerWashVo;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils;

import java.util.Objects;

public class EngineerWashConvert {
    /**
     * 转换焊接材料
     *
     * @param weldingMaterials
     * @return
     */
    public static String convertCleaningMaterialsText(Integer weldingMaterials) {
        if (weldingMaterials == null) {
            return null;
        }
        if (Objects.equals(MaterialTypeEnum.STAINLESS_STEEL.getType(),weldingMaterials)){
            return Utils.getApp().getString(R.string.stainless_steel_text);
        } else if (Objects.equals(MaterialTypeEnum.CARBON_STEEL.getType(),weldingMaterials)){
            return Utils.getApp().getString(R.string.carbon_steel_text);
        } else if (Objects.equals(MaterialTypeEnum.GALVANIZED_SHEET.getType(),weldingMaterials)){
            return Utils.getApp().getString(R.string.galvanized_sheet_text);
        } else if (Objects.equals(MaterialTypeEnum.ALUMINUM_ALLOY.getType(),weldingMaterials)){
            return Utils.getApp().getString(R.string.aluminum_alloy_text);
        } else if (Objects.equals(MaterialTypeEnum.BRASS.getType(),weldingMaterials)){
            return Utils.getApp().getString(R.string.brass_text);
        } else if (Objects.equals(MaterialTypeEnum.CUSTOMIZE.getType(),weldingMaterials)){
            return Utils.getApp().getString(R.string.customize_text);
        }
        return Utils.getApp().getString(R.string.customize_text);
    }

    /**
     * 反转 convertCleaningMaterialsText 方法：根据材料文本获取对应的编码
     *
     * @param weldingMaterialsText 材料文本（如"不锈钢"、"碳钢"，或直接传入资源ID对应的字符串）
     * @return 对应的编码（1=不锈钢，2=碳钢...6=自定义，无匹配时返回null或默认值）
     */
    public static Integer reverseConvertCleaningMaterials(String weldingMaterialsText) {
        // 1. 处理空值：文本为空直接返回null
        if (TextUtils.isEmpty(weldingMaterialsText)) {
            return null;
        }

        // 2. 优先通过 Context 匹配资源字符串（推荐，适配多语言）
        String stainlessSteel = Utils.getApp().getString(R.string.stainless_steel_text);
        String carbonSteel = Utils.getApp().getString(R.string.carbon_steel_text);
        String galvanizedSheet = Utils.getApp().getString(R.string.galvanized_sheet_text);
        String aluminumAlloy = Utils.getApp().getString(R.string.aluminum_alloy_text);
        String brass = Utils.getApp().getString(R.string.brass_text);
        String customize = Utils.getApp().getString(R.string.customize_text);

        // 用 if-else 匹配动态资源字符串（避免 switch 的常量要求）
        if (stainlessSteel.equals(weldingMaterialsText)) {
            return MaterialTypeEnum.STAINLESS_STEEL.getType();
        } else if (carbonSteel.equals(weldingMaterialsText)) {
            return MaterialTypeEnum.CARBON_STEEL.getType();
        } else if (galvanizedSheet.equals(weldingMaterialsText)) {
            return MaterialTypeEnum.GALVANIZED_SHEET.getType();
        } else if (aluminumAlloy.equals(weldingMaterialsText)) {
            return MaterialTypeEnum.ALUMINUM_ALLOY.getType();
        } else if (brass.equals(weldingMaterialsText)) {
            return MaterialTypeEnum.BRASS.getType();
        } else if (customize.equals(weldingMaterialsText)) {
            return MaterialTypeEnum.CUSTOMIZE.getType();
        }
        return MaterialTypeEnum.CUSTOMIZE.getType();
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
     * 将EngineerWash转换为EngineerWashVo
     *
     * @param engineerWash 原始实体类对象
     * @return 转换后的VO对象
     */
    public static EngineerWashVo toVo(EngineerWash engineerWash, Context context) {
        if (engineerWash == null) {
            return null;
        }
        EngineerWashVo vo = new EngineerWashVo();
        vo.setId(engineerWash.getId());
        // Integer转String，空值处理
        vo.setCleaningMaterials(convertCleaningMaterialsText(engineerWash.getCleaningMaterials()));
        vo.setSwingWidth(engineerWash.getSwingWidth() != null ?
                engineerWash.getSwingWidth().toString() : "");
        vo.setLaserPower(engineerWash.getLaserPower() != null ?
                engineerWash.getLaserPower().toString() : "");
        vo.setSwingFrequency(engineerWash.getSwingFrequency() != null ?
                engineerWash.getSwingFrequency().toString() : "");
        vo.setBlowDelay(engineerWash.getBlowDelay() != null ?
                engineerWash.getBlowDelay().toString() : "");
        vo.setCloseAirDelay(engineerWash.getCloseAirDelay() != null ?
                engineerWash.getCloseAirDelay().toString() : "");
        vo.setSlowRiseDuration(engineerWash.getSlowRiseDuration() != null ?
                engineerWash.getSlowRiseDuration().toString() : "");
        vo.setSlowDescentDuration(engineerWash.getSlowDescentDuration() != null ?
                engineerWash.getSlowDescentDuration().toString() : "");
        vo.setType(engineerWash.getType());
        return vo;
    }

    /**
     * 将EngineerWashVo转换为EngineerWash
     *
     * @param vo 原始VO对象
     * @return 转换后的实体类对象
     */
    public static EngineerWash toEntity(EngineerWashVo vo, Context context) {
        if (vo == null) {
            return null;
        }
        EngineerWash engineerWash = new EngineerWash();
        engineerWash.setId(vo.getId());
        // String转Integer，空值和非数字处理
        engineerWash.setCleaningMaterials(reverseConvertCleaningMaterials(vo.getCleaningMaterials()));
        engineerWash.setSwingWidth(parseInt(vo.getSwingWidth()));
        engineerWash.setLaserPower(parseInt(vo.getLaserPower()));
        engineerWash.setSwingFrequency(parseInt(vo.getSwingFrequency()));
        engineerWash.setBlowDelay(parseInt(vo.getBlowDelay()));
        engineerWash.setCloseAirDelay(parseInt(vo.getCloseAirDelay()));
        engineerWash.setSlowRiseDuration(parseInt(vo.getSlowRiseDuration()));
        engineerWash.setSlowDescentDuration(parseInt(vo.getSlowDescentDuration()));
        engineerWash.setType(vo.getType());
        return engineerWash;
    }

    /**
     * 字符串转Integer工具方法
     *
     * @param str 待转换的字符串
     * @return 转换后的Integer，转换失败返回null
     */
    private static Integer parseInt(String str) {
        if (str == null || str.trim().isEmpty()) {
            return null;
        }
        try {
            return Integer.parseInt(str.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
