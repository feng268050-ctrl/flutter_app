package com.lasercyber.lws.ui.common.utils.hex;

import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.common.enums.HexDataBiteType;

import cn.hutool.core.util.CharsetUtil;
import cn.hutool.core.util.HexUtil;

import java.math.BigInteger;
import java.util.Objects;

/**
 * 十六进制转为十进制
 */
public class ProtocolHexToDecimal {

    /*16进制转字符*/
   public static String transitionToStr(String s){
       if (s == null || s.isEmpty()) {
           return null;
       }
       s = s.replace(" ", "");
       String fillStr="00";
       while (s.startsWith(fillStr)) {
           // 去掉前面补零
           int fillIndex = s.indexOf(fillStr);
           s=s.substring(0,fillIndex);
       }
       while (s.endsWith(fillStr)){
           // 去掉后面补零
           int lastFill = s.lastIndexOf(fillStr);
           s=s.substring(0,lastFill);
       }
       return HexUtil.decodeHexStr(s, CharsetUtil.CHARSET_GBK);
   }
    /*16进制转字数字*/
    public static int transitionToInt(String str){
        long decimal = Long.parseLong(str, 16);
        return (int) decimal;
    }

    /*16进制转双精数*/
    public static double transitionToDouble(String str){
        int index = str.indexOf("0x");
        if (index>=0){
            // 去除头部补零
            str=str.substring(index);
        }
        return Double.parseDouble(str);
    }

    /**
     * 16进制转单精度
     * @param hexData 16进制单精度
     * @return 10进制单精度
     */
    public static float transitionToFloat(String hexData){
        if (StringUtils.isEmpty(hexData)){
            return Float.NaN;
        }
        try{
            return Float.intBitsToFloat(Integer.parseInt(hexData,16));
        }catch (NumberFormatException numberFormatException){
            return Float.intBitsToFloat(new BigInteger(hexData, 16).intValue());
        }
    }
    /**
     * 16进制转long
     * @param str
     * @return
     */
    public static long transitionToLong(String str){
        long decimal = Long.parseLong(str, 16);
        return decimal;
    }

    /**
     * 转为无符号的byte
     * @param str
     * @return
     */
    public static byte transitionToUnsignedByte(String str){
        int data = transitionToInt(str);
        return (byte) data;
    }

    /**
     * 转为有符号的byte
     * @param str
     * @return
     */
    public static byte transitionToSignedByte(String str){
        int data = transitionToInt(str);
        if (data > 127) {
            return (byte) (data - 256);
        }
        return (byte) data;
    }

    /**
     * 将16进制转为十进制
     * @param pointerUpdate
     * @param dataBiteType
     * @param size
     * @return
     */
    public static Object convertToObject(PointerUpdate pointerUpdate,HexDataBiteType dataBiteType,int size){
        if (dataBiteType == HexDataBiteType.INT_BYTE_TYPE) {
            return pointerUpdate.descPointerUpdateInt(size);
        } else if (dataBiteType == HexDataBiteType.LONG_BYTE_TYPE) {
            return pointerUpdate.descPointerUpdateLong(size);
        } else if (dataBiteType == HexDataBiteType.DOUBLE_BYTE_TYPE) {
            return pointerUpdate.descPointerUpdateDouble(null,size);
        } else if (dataBiteType == HexDataBiteType.STRING_BYTE_TYPE) {
            return pointerUpdate.descPointerUpdateStr(size);
        } else if (dataBiteType == HexDataBiteType.FLOAT_BYTE_TYPE) {
            return pointerUpdate.descPointerUpdateFloat(size);
        } else if (dataBiteType == HexDataBiteType.SIGNED_BYTE_TYPE) {
            return pointerUpdate.descPointerUpdateSignedByte(size);
        } else if (dataBiteType == HexDataBiteType.UNSIGNED_BYTE_TYPE) {
            return pointerUpdate.descPointerUpdateUnsignedByte(size);
        }
        return null;
    }

}
