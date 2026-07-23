package com.lasercyber.lws.ui.common.utils;

public class ByteCombineUtils {
    /**
     * 将两个int合并为一个short，高8位存第一个值，低8位存第二个值
     * @param highInt 高8位的int值（范围0~255）
     * @param lowInt 低8位的int值（范围0~255）
     * @return 合并后的short值
     * @throws IllegalArgumentException 若输入值超出0~255范围
     */
    public static short combineToShort(int highInt, int lowInt) {
        // 验证输入范围
//        if (highInt < 0 || highInt > 255) {
//            throw new IllegalArgumentException("高8位值必须在0~255范围内，当前值：" + highInt);
//        }
//        if (lowInt < 0 || lowInt > 255) {
//            throw new IllegalArgumentException("低8位值必须在0~255范围内，当前值：" + lowInt);
//        }

        // 高8位左移8位，合并低8位
        return (short) ((highInt << 8) | lowInt);
    }

    /**
     * 从合并后的short中提取高8位的int值
     * @param combinedShort 合并后的short值
     * @return 高8位对应的int值（范围0~255）
     */
    public static int extractHighInt(short combinedShort) {
        // 右移8位后，通过&0xFF确保只保留低8位（避免符号扩展影响）
        return (combinedShort >> 8) & 0xFF;
    }

    /**
     * 从合并后的short中提取低8位的int值
     * @param combinedShort 合并后的short值
     * @return 低8位对应的int值（范围0~255）
     */
    public static int extractLowInt(short combinedShort) {
        // 直接通过&0xFF提取低8位
        return combinedShort & 0xFF;
    }
    /**
     * 拆分long为高32位（int）和低32位（int）
     * @param num 原始long数值
     * @return 数组：[0] = 高32位，[1] = 低32位
     */
    public static int[] splitLongToHighLowInt(long num) {
        int[] result = new int[2];
        // 高16位：右移16位，再与0xFFFF按位与（确保仅保留16位，避免符号位干扰）
        result[0] = (int) ((num >> 16) & 0xFFFF);
        // 低16位：与0xFFFF按位与（直接保留低16位）
        result[1] = (int) (num & 0xFFFF);
        return result;
    }

    /**
     * 从高32位和低32位还原为long
     * @param high 高32位（int）
     * @param low 低32位（int）
     * @return 还原后的long
     */
    public static long combineIntToLong(int high, int low) {
        // 先将high转为long并左移32位，再与low的无符号值合并（避免符号位扩展）
        return ((long) high << 32) | (low & 0xFFFFFFFFL);
    }
}
