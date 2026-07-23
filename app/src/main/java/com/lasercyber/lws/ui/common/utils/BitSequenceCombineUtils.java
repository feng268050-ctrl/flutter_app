package com.lasercyber.lws.ui.common.utils;

import java.math.BigInteger;
import java.util.Arrays;

public class BitSequenceCombineUtils {

    // 每个int默认占用的bit位数（32位，适配标准int范围）
    private static final int DEFAULT_INT_BIT_COUNT = 32;

    /**
     * 按顺序合并多个int为一个数据（自动分配bit位，默认每个int占32位）
     * 总bit数≤64时返回long，否则返回BigInteger
     *
     * @param ints 待合并的int数组（顺序即bit位从低到高的顺序）
     * @return 合并后的结果（Long或BigInteger）
     */
    public static Number combineInts(int... ints) {
        return combineIntsWithBitCount(DEFAULT_INT_BIT_COUNT, ints);
    }

    /**
     * 自定义每个int的bit位数，按顺序合并为一个数据
     * 例：每个int占8位，合并3个int则总bit数=24，返回long
     *
     * @param perIntBitCount 每个int占用的bit位数（需≥1且≤32，避免超出int存储范围）
     * @param ints           待合并的int数组（顺序即bit位从低到高）
     * @return 合并后的结果（Long或BigInteger）
     * @throws IllegalArgumentException 非法参数（bit数超出范围、int值超出bit数表示范围等）
     */
    public static Number combineIntsWithBitCount(int perIntBitCount, int... ints) {
        // 校验参数合法性
        if (perIntBitCount < 1 || perIntBitCount > 32) {
            throw new IllegalArgumentException("每个int的bit位数必须在1~32之间");
        }
        if (ints == null || ints.length == 0) {
            throw new IllegalArgumentException("待合并的int数组不能为空");
        }

        // 计算总bit数，判断使用long还是BigInteger
        long totalBitCount = (long) perIntBitCount * ints.length;
        BigInteger result = BigInteger.ZERO;

        // 按顺序合并每个int：前一个int占低位，后一个int占高位
        for (int i = 0; i < ints.length; i++) {
            int value = ints[i];
            // 校验当前int值是否超出perIntBitCount位所能表示的范围（无符号，范围0~2^bitCount-1）
            long maxValue = (1L << perIntBitCount) - 1;
            if (value < 0 || (long) value > maxValue) {
                throw new IllegalArgumentException(
                        String.format("第%d个int值%d超出%d位无符号范围（0~%d）",
                                i + 1, value, perIntBitCount, maxValue)
                );
            }

            // 计算当前int的bit位偏移量（前i个int占用的总bit数）
            int offset = i * perIntBitCount;
            // 将当前int转换为BigInteger，左移offset位后合并
            result = result.or(BigInteger.valueOf(value).shiftLeft(offset));
        }

        // 总bit数≤64时，返回long（避免BigInteger的冗余），否则返回BigInteger
        if (totalBitCount <= 64) {
            return result.longValue();
        } else {
            return result;
        }
    }

    /**
     * 从合并后的结果中按顺序提取指定索引的int（需与合并时的bit位数一致）
     *
     * @param combinedResult 合并后的结果（Long或BigInteger）
     * @param perIntBitCount 合并时每个int占用的bit位数
     * @param index          要提取的int索引（从0开始，对应合并时的顺序）
     * @return 提取的int值
     * @throws IllegalArgumentException 非法参数（结果类型错误、索引超出范围等）
     */
    public static int extractInt(Number combinedResult, int perIntBitCount, int index) {
        // 校验参数合法性
        if (!(combinedResult instanceof Long) && !(combinedResult instanceof BigInteger)) {
            throw new IllegalArgumentException("合并结果必须是Long或BigInteger类型");
        }
        if (perIntBitCount < 1 || perIntBitCount > 32) {
            throw new IllegalArgumentException("每个int的bit位数必须在1~32之间");
        }
        if (index < 0) {
            throw new IllegalArgumentException("索引不能为负数");
        }

        // 将结果统一转为BigInteger处理
        BigInteger resultBigInt = combinedResult instanceof BigInteger
                ? (BigInteger) combinedResult
                : BigInteger.valueOf(combinedResult.longValue());

        // 计算总int个数，校验索引是否超出范围
        long totalBitCount = resultBigInt.bitLength();
        int totalIntCount = (int) Math.ceil((double) totalBitCount / perIntBitCount);
        if (index >= totalIntCount) {
            throw new IllegalArgumentException(
                    String.format("索引%d超出范围，合并结果共包含%d个int", index, totalIntCount)
            );
        }

        // 计算目标int的bit位偏移量和掩码
        int offset = index * perIntBitCount;
        BigInteger mask = BigInteger.ONE.shiftLeft(perIntBitCount).subtract(BigInteger.ONE);

        // 提取目标int：右移offset位后与掩码按位与
        return resultBigInt.shiftRight(offset).and(mask).intValue();
    }

    /**
     * 从合并后的结果中按顺序提取所有int（需与合并时的bit位数一致）
     *
     * @param combinedResult 合并后的结果（Long或BigInteger）
     * @param perIntBitCount 合并时每个int占用的bit位数
     * @return 提取的int数组（顺序与合并时一致）
     */
    public static int[] extractAllInts(Number combinedResult, int perIntBitCount) {
        // 校验参数合法性
        if (!(combinedResult instanceof Long) && !(combinedResult instanceof BigInteger)) {
            throw new IllegalArgumentException("合并结果必须是Long或BigInteger类型");
        }
        if (perIntBitCount < 1 || perIntBitCount > 32) {
            throw new IllegalArgumentException("每个int的bit位数必须在1~32之间");
        }

        // 将结果统一转为BigInteger处理
        BigInteger resultBigInt = combinedResult instanceof BigInteger
                ? (BigInteger) combinedResult
                : BigInteger.valueOf(combinedResult.longValue());

        // 计算总int个数
        long totalBitCount = resultBigInt.bitLength();
        int totalIntCount = totalBitCount == 0 ? 0 : (int) Math.ceil((double) totalBitCount / perIntBitCount);
        if (totalIntCount == 0) {
            return new int[0];
        }

        // 按顺序提取每个int
        int[] extractedInts = new int[totalIntCount];
        BigInteger mask = BigInteger.ONE.shiftLeft(perIntBitCount).subtract(BigInteger.ONE);
        for (int i = 0; i < totalIntCount; i++) {
            int offset = i * perIntBitCount;
            extractedInts[i] = resultBigInt.shiftRight(offset).and(mask).intValue();
        }
        return extractedInts;
    }

    // 辅助方法：打印合并结果的二进制（便于调试）
    public static String toBinaryString(Number combinedResult) {
        if (combinedResult instanceof Long) {
            return Long.toBinaryString(combinedResult.longValue());
        } else if (combinedResult instanceof BigInteger) {
            return ((BigInteger) combinedResult).toString(2);
        } else {
            throw new IllegalArgumentException("仅支持Long和BigInteger类型");
        }
    }
}