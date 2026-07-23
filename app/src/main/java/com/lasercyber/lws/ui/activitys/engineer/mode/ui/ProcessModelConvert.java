package com.lasercyber.lws.ui.activitys.engineer.mode.ui;

import com.lasercyber.lws.ui.common.constant.ModelConstant;

public class ProcessModelConvert {
    /**
     * model转为页面的index
     *
     * @param modelConstant
     * @return
     */
    public static int modelConstantConvertToPageIndex(int modelConstant) {
        return switch (modelConstant) {
            case ModelConstant.CONTINUOUS_WELDING -> 0;
            case ModelConstant.POINT_WELDING -> 1;
            case ModelConstant.WELD_CLEAN -> 2;
            case ModelConstant.WIDTH_CLEAN -> 3;
            case ModelConstant.HAND_CUT -> 4;
            default -> 0;
        };
    }

    /**
     * 页面的index转为model
     *
     * @param pageIndex
     * @return
     */
    public static int pageIndexConvertToModelConstant(int pageIndex) {
        return switch (pageIndex) {
            case 0 -> ModelConstant.CONTINUOUS_WELDING;
            case 1 -> ModelConstant.POINT_WELDING;
            case 2 -> ModelConstant.WELD_CLEAN;
            case 3 -> ModelConstant.WIDTH_CLEAN;
            case 4 -> ModelConstant.HAND_CUT;
            default -> ModelConstant.CONTINUOUS_WELDING;
        };
    }
}
