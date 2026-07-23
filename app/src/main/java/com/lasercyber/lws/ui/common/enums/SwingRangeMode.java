package com.lasercyber.lws.ui.common.enums;

import com.lasercyber.lws.ui.common.constant.ModelConstant;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 摆动范围模式枚举
 */
@Getter
@AllArgsConstructor
public enum SwingRangeMode {
    welding_7(7, 0, new int[]{ModelConstant.CONTINUOUS_WELDING, ModelConstant.POINT_WELDING, ModelConstant.CNC_CUT}, 1),
    wash_8(8,0,new int[]{ModelConstant.WELD_CLEAN,ModelConstant.WIDTH_CLEAN},1),
    wash_9(9,0,new int[]{ModelConstant.WELD_CLEAN,ModelConstant.WIDTH_CLEAN},1),
    wash_10(10,0,new int[]{ModelConstant.WELD_CLEAN,ModelConstant.WIDTH_CLEAN},1),
    ;
    /**
     * 摆动范围模式值
     */
    private int swingMode;
    /**
     * 焊枪型号,1:31f TODO 后续需要适配枪头类型
     */
    private int gunType;
    /**
     * 模式
     * {@link ModelConstant}
     */
    private int[] modelArr;
    /**
     * 驱动类型
     * 1:I型
     */
    private int driveType;
    public static SwingRangeMode find(int model, int gunType){
        for (SwingRangeMode value : values()) {
            if(value.gunType != gunType){
                continue;
            }
            for (int itemModel : value.modelArr) {
                if(itemModel == model){
                    return value;
                }
            }
        }
        return null;
    }
}
