package com.lasercyber.lws.ui.common.constant;

import com.blankj.utilcode.util.Utils;
import com.lasercyber.lws.ui.R;

/**
 * 工艺类型枚举值
 */
public class ModelConstant {
    /**
     * 连续焊接
     */
    public static final int CONTINUOUS_WELDING = 0;
    /**
     * 点焊接
     */
    public static final int POINT_WELDING = 1;
    /**
     * 焊道清洗
     */
    public static final int WELD_CLEAN = 2;
    /**
     * 宽幅清洗
     */
    public static final int WIDTH_CLEAN = 3;
    /**
     * 手持切割
     */
    public static final int HAND_CUT = 4;
    /**
     * CNC切割
     */
    public static final int CNC_CUT = 5;

    /**
     * 转换文本（数据库或 VO 中 {@code processType} 可能为 null，禁止直接传入 {@link Integer} 给 {@link #convertToText(int)} 以免拆箱 NPE）。
     */
    public static String convertToText(Integer modelType) {
        if (modelType == null) {
            return Utils.getApp().getString(R.string.unknown_text);
        }
        return convertToText(modelType.intValue());
    }

    /**
     * 转换文本
     *
     * @param modelType
     * @return
     */
    public static String convertToText(int modelType) {
        return switch (modelType) {
            case CONTINUOUS_WELDING -> Utils.getApp().getString(R.string.continuous_welding_text);
            case POINT_WELDING -> Utils.getApp().getString(R.string.point_welding_text);
            case WELD_CLEAN -> Utils.getApp().getString(R.string.weld_cleaning_text);
            case WIDTH_CLEAN -> Utils.getApp().getString(R.string.width_cleaning_text);
            case HAND_CUT -> Utils.getApp().getString(R.string.hand_cutting_text);
            case CNC_CUT -> Utils.getApp().getString(R.string.cnc_cutting_text);
            default -> Utils.getApp().getString(R.string.unknown_text);
        };
    }
}
