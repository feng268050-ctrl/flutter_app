package com.lasercyber.lws.ui.common.utils.hex;

import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.common.enums.HexDataBiteType;
import com.lasercyber.lws.ui.common.enums.HexDataFiledType;
import com.lasercyber.lws.ui.common.exception.HexException;

import java.util.Objects;

import cn.hutool.core.convert.Convert;
import cn.hutool.core.util.ObjectUtil;
import lombok.Data;

/**
 * 将十进制数据转为十六进制
 */
@Data
public class SendPointerUpdate {

    /*获取结果，同时转换str格式*/
    public static String descPointerUpdateStr(Object val, int size) {
        String strVal = ProtocolDecimalToHex.convertToHex(ObjectUtil.isEmpty(val) ? null : Convert.toStr(val));
        String compensation = compensation(strVal, size, false);
        return compensation;
    }

    /*转换为int 类型*/
    public static String descPointerUpdateInt(Object val, int size) {
        String i = ProtocolDecimalToHex.transitionIntTo16(ObjectUtil.isEmpty(val) ? null : Convert.toInt(val));
        String compensation = compensation(i, size, true);
        return compensation;
    }

    /*转换为双精数*/
    public static String descPointerUpdateDouble(Object db, int size) {
        String v = ProtocolDecimalToHex.transitionDoubleTo16(ObjectUtil.isEmpty(db) ? null : Convert.toDouble(db));
        String compensation = compensation(v, size, true);
        return compensation;
    }

    /**
     * 转为long
     */
    public static String descPointerUpdateLong(Object val, int size) {
        String s = ProtocolDecimalToHex.transitionLongTo16(ObjectUtil.isEmpty(val) ? null : Convert.toLong(val));
        String compensation = compensation(s, size, true);
        return compensation;
    }

    /**
     * 长度超出或减少
     *
     * @param val
     * @param size
     * @param leftFill true：左边填充0，false：右边填充0
     * @return
     */
    private static String compensation(String val, int size, boolean leftFill) {
        if (size == 0) {
            return "";
        }
        int length = size * 2;
        //如果为空，则纯00
        if (StringUtils.isEmpty(val)) {
            StringBuilder stringBuilder = new StringBuilder();
            for (int i = 0; i < length; i++) {
                stringBuilder.append("0");
            }
            return stringBuilder.toString();
        }
        //字节不够，则补0
        else if (val.length() < length) {
            int sum = length - val.length();
            StringBuilder stringBuilder = new StringBuilder();
            for (int i = 0; i < sum; i++) {
                stringBuilder.append("0");
            }
            if (leftFill) {
                // 左边填充
                return stringBuilder.append(val).toString();
            } else {
                // 右边填充
                return val + stringBuilder.toString();
            }

        } else if (val.length() > length) {
            throw new HexException("参数值:" + val + ",超出长度，重新操作或请连续管理员！");
        } else {
            return val;
        }
    }

    /**
     * 十进制单精度数据转为十六进制
     *
     * @param value
     * @param size
     * @return
     */
    public static String descPointerUpdateFloat(Object value, int size) {
        String s = ProtocolDecimalToHex.transitionFloatTo16(ObjectUtil.isEmpty(value) ? null : Convert.toFloat(value));
        String compensation = compensation(s, size, true);
        return compensation;
    }

    /**
     * 十进制有符号byte转为十六进制
     *
     * @param val
     * @param size
     * @return
     */
    public static String descPointerUpdateSignedByte(Object val, int size) {
        String i = ProtocolDecimalToHex.transitionSignedByteTo16(ObjectUtil.isEmpty(val) ? null : Convert.toInt(val));
        String compensation = compensation(i, size, true);
        return compensation;
    }

    /**
     * 十进制无符号byte转为十六进制
     *
     * @param val
     * @param size
     * @return
     */
    public static String descPointerUpdateUnsignedByte(Object val, int size) {
        String i = ProtocolDecimalToHex.transitionUnsignedByteTo16(ObjectUtil.isEmpty(val) ? null : Convert.toInt(val));
        String compensation = compensation(i, size, true);
        return compensation;
    }

    public static String convertToHexData(HexDataBiteType dataBiteType, int size, Object value) {

        if (dataBiteType == HexDataBiteType.INT_BYTE_TYPE) {
            return SendPointerUpdate.descPointerUpdateInt(value, size);
        } else if (dataBiteType == HexDataBiteType.LONG_BYTE_TYPE) {
            return SendPointerUpdate.descPointerUpdateLong(value, size);
        } else if (dataBiteType == HexDataBiteType.DOUBLE_BYTE_TYPE) {
            return SendPointerUpdate.descPointerUpdateDouble(value, size);
        } else if (dataBiteType == HexDataBiteType.STRING_BYTE_TYPE) {
            return SendPointerUpdate.descPointerUpdateStr(value, size);
        } else if (dataBiteType == HexDataBiteType.FLOAT_BYTE_TYPE) {
            return SendPointerUpdate.descPointerUpdateFloat(value, size);
        } else if (dataBiteType == HexDataBiteType.SIGNED_BYTE_TYPE) {
            return SendPointerUpdate.descPointerUpdateSignedByte(value, size);
        } else if (dataBiteType == HexDataBiteType.UNSIGNED_BYTE_TYPE) {
            return SendPointerUpdate.descPointerUpdateUnsignedByte(value, size);
        }
        //超出当前类别的，则赋空!
        return SendPointerUpdate.descPointerUpdateStr(null, size);
    }
}
