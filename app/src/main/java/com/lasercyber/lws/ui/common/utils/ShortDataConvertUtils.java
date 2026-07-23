package com.lasercyber.lws.ui.common.utils;

public class ShortDataConvertUtils {
    public static short convertWithBitOperation(long longValue) {
        // 先通过 & 0xFFFF 保留低 16 位，再强制转换为 short（保留符号）
        return (short) (longValue & 0xFFFFL);
    }
}
