package com.lasercyber.lws.ui.common.constant;

/**
 * modbus的工艺参数类型
 */
public class ModbusProcessType {
    public static final int CONTINUOUS_WELDING = 0; // 连续焊接
    public static final int SPOT_WELDING = 1;       // 点焊
    public static final int CLEANING = 2;           // 清洗
    public static final int CUTTING = 3;            // 切割
    public static final int CNC = 4; // CNC切割

    /**
     * 转换为modbus类型
     * @param type
     * @return
     */
    public static int convertToModbusType(int type) {
        return switch (type) {
            case ModelConstant.CONTINUOUS_WELDING -> CONTINUOUS_WELDING;
            case ModelConstant.POINT_WELDING -> SPOT_WELDING;
            case ModelConstant.WELD_CLEAN, ModelConstant.WIDTH_CLEAN -> CLEANING;
            case ModelConstant.HAND_CUT -> CUTTING;
            case ModelConstant.CNC_CUT -> CNC;
            default -> -1;
        };
    }
}
