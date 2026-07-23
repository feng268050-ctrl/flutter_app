package com.lasercyber.lws.ui.common.utils.bit;

public class LongBitReaderUtils {
    /**
     * 读取 long 数据指定位置的比特位
     * @param num 目标 long 数据
     * @param bitIndex 比特位索引（0 = 最低位，63 = 最高位）
     * @return 该位的值（0 或 1）
     * @throws IllegalArgumentException 索引越界时抛出异常
     */
    public static int getBitAt(long num, int bitIndex) {
        // 校验索引合法性（long 仅 0-63 位）
        if (bitIndex < 0 || bitIndex > 63) {
            return -1;
        }
        // 生成掩码 + 与运算判断
        long mask = 1L << bitIndex;
        return (num & mask) != 0 ? 1 : 0;
    }
    /**
     * 读取 long 类型的每一个比特位（从最低位第 0 位到最高位第 63 位）
     * @param num 目标 long 数据
     * @return 比特位数组（index 0 = 第 0 位，index 63 = 第 63 位）
     */
    public static int[] readBitsAll(long num) {
        int[] bits = new int[64]; // long 共 64 位
        for (int i = 0; i < 64; i++) {
            // 1. 生成第 i 位的掩码：1L 左移 i 位（仅第 i 位为 1，其余为 0）
            long mask = 1L << i;
            // 2. 与运算判断第 i 位是否为 1
            bits[i] = (num & mask) != 0 ? 1 : 0;
        }
        return bits;
    }
}
