package com.lasercyber.lws.ui.common.utils;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * 工艺参数面板展示格式化。
 */
public final class ProcessParameterDisplayFormat {

    private ProcessParameterDisplayFormat() {
    }

    public static String asInteger(Number value) {
        if (value == null) {
            return "";
        }
        return BigDecimal.valueOf(value.doubleValue())
                .setScale(0, RoundingMode.HALF_UP)
                .toPlainString();
    }

    public static String asDecimal(Number value) {
        if (value == null) {
            return "";
        }
        return BigDecimal.valueOf(value.doubleValue())
                .setScale(1, RoundingMode.HALF_UP)
                .stripTrailingZeros()
                .toPlainString();
    }
}
