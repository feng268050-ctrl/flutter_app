package com.lasercyber.lws.ui.common.enums;

import lombok.Getter;

/**
 * 材质类型
 */
@Getter
public enum MaterialTypeEnum {
    /**
     * 不锈钢
     */
    STAINLESS_STEEL(1),
    /**
     * 碳钢
     */
    CARBON_STEEL(2),
    /**
     * 镀锌板
     */
    GALVANIZED_SHEET(3),
    /**
     * 铝合金
     */
    ALUMINUM_ALLOY(4),
    /**
     * 黄铜
     */
    BRASS(5),
    /**
     * 自定义
     */
    CUSTOMIZE(6);
    /**
     * 对应的类型数值
     */
    public final int type;
    MaterialTypeEnum(int type) {
        this.type = type;
    }

    /** @return true when {@code type} matches a defined material code (1–6). */
    public static boolean isDefinedType(Integer type) {
        if (type == null) {
            return false;
        }
        for (MaterialTypeEnum e : values()) {
            if (e.type == type) {
                return true;
            }
        }
        return false;
    }
}
