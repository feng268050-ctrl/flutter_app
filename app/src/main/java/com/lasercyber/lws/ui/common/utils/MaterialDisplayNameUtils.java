package com.lasercyber.lws.ui.common.utils;

import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;

import java.util.Objects;

/**
 * UI-only material display localization. Does not change stored material codes or names.
 */
public final class MaterialDisplayNameUtils {
    private MaterialDisplayNameUtils() {
    }

    public static String getMaterialLabel(Integer materialType) {
        if (Objects.equals(materialType, MaterialTypeEnum.STAINLESS_STEEL.getType())) {
            return Utils.getApp().getString(R.string.stainless_steel_text);
        } else if (Objects.equals(materialType, MaterialTypeEnum.CARBON_STEEL.getType())) {
            return Utils.getApp().getString(R.string.carbon_steel_text);
        } else if (Objects.equals(materialType, MaterialTypeEnum.GALVANIZED_SHEET.getType())) {
            return Utils.getApp().getString(R.string.galvanized_sheet_text);
        } else if (Objects.equals(materialType, MaterialTypeEnum.ALUMINUM_ALLOY.getType())) {
            return Utils.getApp().getString(R.string.aluminum_alloy_text);
        } else if (Objects.equals(materialType, MaterialTypeEnum.BRASS.getType())) {
            return Utils.getApp().getString(R.string.brass_text);
        } else if (Objects.equals(materialType, MaterialTypeEnum.CUSTOMIZE.getType())) {
            return Utils.getApp().getString(R.string.customize_text);
        }
        return null;
    }

    public static String localizeKnownMaterialName(String storedName, Integer materialType) {
        if (StringUtils.isEmpty(storedName)) {
            return "";
        }
        // Keep user-defined custom material names untouched.
        if (Objects.equals(materialType, MaterialTypeEnum.CUSTOMIZE.getType())) {
            return storedName;
        }
        if (isKnownMaterialName(storedName)) {
            String localized = getMaterialLabel(materialType);
            return StringUtils.isEmpty(localized) ? storedName : localized;
        }
        return storedName;
    }

    private static boolean isKnownMaterialName(String name) {
        return Objects.equals(name, "不锈钢")
                || Objects.equals(name, "碳钢")
                || Objects.equals(name, "镀锌板")
                || Objects.equals(name, "铝合金")
                || Objects.equals(name, "铝板")
                || Objects.equals(name, "黄铜")
                || Objects.equals(name, "自定义")
                || Objects.equals(name, "Stainless Steel")
                || Objects.equals(name, "Carbon Steel")
                || Objects.equals(name, "Galvanized Sheet")
                || Objects.equals(name, "Aluminum Alloy")
                || Objects.equals(name, "Aluminum")
                || Objects.equals(name, "Brass")
                || Objects.equals(name, "Custom");
    }
}
