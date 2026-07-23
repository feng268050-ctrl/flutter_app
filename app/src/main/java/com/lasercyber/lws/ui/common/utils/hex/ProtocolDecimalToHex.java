package com.lasercyber.lws.ui.common.utils.hex;

import cn.hutool.core.util.CharsetUtil;
import cn.hutool.core.util.HexUtil;

/**
 * 十进制转为十六进制
 */
public class ProtocolDecimalToHex {
/**
*@description:
*@date 20:12 2023/10/13
*@return pkId需求记录：
 * 1、在下发消息时，将消息ID转换成2个字节的id。同时保存进redis，用SN拼接2字节的6位ID为key, 真实的18位ID为value进行缓存。
 * 2、在设备应答消息时，将5位的id转换成18位的真实id进行存储。
 *
 * 3、数据库：建立消息id序号表，每次获取消息id时，需要进行加锁。获取完成之后，将id进行递增，并解锁。
 * 得到的id进行与65535取余，结果补0  必须为5位数;
 *
 * 注： 系统中整个业务执行时，仍用之前的业务，只有在应答与发送时，才进行转换。
**/


    /* 字符串转16进制*/
    public static String convertToHex(String str) {
        if (null==str){
            return "";
        }
        return HexUtil.encodeHexStr(str, CharsetUtil.CHARSET_GBK);
    }
    /*数字赚16进制*/
    public static String transitionIntTo16(Integer str){
        if (null==str){
            return "";
        }
        String hex = Integer.toHexString(str);
        return hex;
    }

    /*双精数转16进制*/
    public static String transitionDoubleTo16(Double str){
        if (null==str){
            return "";
        }
        long longValue = Double.doubleToRawLongBits(str);
       return Long.toHexString(longValue);
    }
    /*Long类型16进制*/
    public static String transitionLongTo16(Long str){
        if (null==str){
            return "";
        }
        String db = Long.toHexString(str);
        return db;
    }

    /**
     * Float转为16进制
     * @param str
     * @return
     */
    public static String transitionFloatTo16(Float str){
        if (null==str){
            return "";
        }
        String db =Integer.toHexString(Float.floatToIntBits(str));
        return db;
    }

    /**
     * 有符号的byte转为16进制
     * @param str
     * @return
     */
    public static String transitionSignedByteTo16(Integer str){
        if (null==str){
            return "";
        }
        int unsignedInt = str & 0xFF;
        return transitionIntTo16(unsignedInt);
    }

    /**
     * 无符号byte转为16进制
     * @param str
     * @return
     */
    public static String transitionUnsignedByteTo16(Integer str){
        if (null==str){
            return "";
        }
        int unsignedInt = str & 0xFF;
        return transitionIntTo16(unsignedInt);
    }
}
