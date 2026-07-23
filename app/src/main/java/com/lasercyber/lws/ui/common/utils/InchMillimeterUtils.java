package com.lasercyber.lws.ui.common.utils;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.text.DecimalFormat;

/**
 * 英寸、毫米单位转换工具
 */
public class InchMillimeterUtils {
    // 固定换算系数：1英寸=25.4毫米
    private static final double MM_PER_INCH = 25;
    private static final int SCALE=3;
    // 初始化格式化器：最多3位小数，自动去除末尾0
    private static final DecimalFormat DECIMAL_FORMAT = new DecimalFormat("#.###");
    /**
     * 毫米转英寸（默认保留4位小数）
     * @param mm 毫米值
     * @return 英寸值
     */
    public static double mmToIn(double mm){
        BigDecimal bd = new BigDecimal(mm / MM_PER_INCH);
        return bd.setScale(SCALE, RoundingMode.HALF_UP).doubleValue();
    }

    /**
     * 毫米转英寸（默认保留3位小数）
     *
     * @param mm
     * @return
     */
    public static String mmToInStr(double mm) {
        if (!Double.isFinite(mm)) {
            return "0";
        }
        // 直接格式化，无需额外处理
        return DECIMAL_FORMAT.format(mmToIn(mm));
    }
    /**
     * 英寸转毫米
     * @param in 英寸值
     * @return 毫米值
     */
    public static double inToMm(double in) {
        return in * MM_PER_INCH;
    }

    /**
     * 英寸转毫米 默认保留3位小数
     *
     * @param in
     * @return
     */
    public static String inToMmStr(double in) {
        if (!Double.isFinite(in)) {
            return "0";
        }
        // 直接格式化，无需额外处理
        return DECIMAL_FORMAT.format(in * MM_PER_INCH);
    }
    /**
     * mm/s 转 in/s（自定义小数精度）
     * @param mmPerSecond 毫米/秒
     * @return 英寸/秒
     */
    public static double mmToInPerSecond(double mmPerSecond) {
        BigDecimal bd = new BigDecimal(mmPerSecond / MM_PER_INCH);
        return bd.setScale(SCALE, RoundingMode.HALF_UP).doubleValue();
    }
    /**
     * in/s 转 mm/s（自定义小数精度）
     * @param inPerSecond 英寸/秒
     * @return 毫米/秒
     */
    public static double inToMmPerSecond(double inPerSecond) {
        // 使用BigDecimal避免浮点精度丢失（如 0.3*25.4 这类运算的误差）
        BigDecimal bd = new BigDecimal(inPerSecond * MM_PER_INCH);
        return bd.setScale(SCALE, RoundingMode.HALF_UP).doubleValue();
    }
}
