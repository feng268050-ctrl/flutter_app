package com.lasercyber.lws.ui.common.utils.hex;

import cn.hutool.core.convert.Convert;

public class PointerUpdate {
    private int pointer = 0;

    private final String headValue;

    public PointerUpdate(String headValue) {
        this.headValue = headValue;
    }
    /*根据指针顺序获取结果*/
    public String descPointerUpdate(int size){
        String val = this.headValue.substring(this.pointer, this.pointer + size * 2 );
        this.pointer = this.pointer + size * 2;
        return val;
    }
    /*获取结果，同时转换str格式*/
    public String descPointerUpdateStr(int size){
        String val = descPointerUpdate(size);
        String strVal = ProtocolHexToDecimal.transitionToStr(val);
        return strVal;
    }
    /*转换为int 类型*/
    public int descPointerUpdateInt(int size){
        String val = descPointerUpdate(size);
        int i = ProtocolHexToDecimal.transitionToInt(val);
        // log.debug("十六进制数据:【{}】，十进制数据:【{}】", val,i);
        return i;
    }
    /*转换为双精数*/
    public double descPointerUpdateDouble(String str,int size){
        String val = descPointerUpdate(size);
        double v = ProtocolHexToDecimal.transitionToDouble(val);
        return v;
    }

    /**
     * 转为long
     * @param size
     * @return
     */
    public long descPointerUpdateLong(int size){
        String val = descPointerUpdate(size);
        return ProtocolHexToDecimal.transitionToLong(val);
    }

    /**
     * 转为单精度
     * @param size
     * @return
     */
    public float descPointerUpdateFloat(int size){
        String val = descPointerUpdate(size);
        Float v = ProtocolHexToDecimal.transitionToFloat(val);
        if(null == v ||  v == 0 ){
            return 0.0f;
        }
        v = v * 10;
        int round = Math.round(v);
        double ddd = Convert.toDouble(round) / 10;
        return  Convert.toFloat(ddd);
    }

    /**
     * 转为有符号十进制byte
     * @param size
     * @return
     */
    public byte descPointerUpdateSignedByte(int size){
        String val = descPointerUpdate(size);
        return ProtocolHexToDecimal.transitionToSignedByte(val);
    }

    /**
     * 转为无符号十进制byte
     * @param size
     * @return
     */
    public byte descPointerUpdateUnsignedByte(int size){
        String val = descPointerUpdate(size);
        return ProtocolHexToDecimal.transitionToUnsignedByte(val);
    }
}
