package com.lasercyber.lws.ui.common.utils.modbus;

import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusReadFiled;
import com.lasercyber.lws.ui.common.utils.hex.ByteUtil;

import java.util.List;

/**
 * 数据转换工具类
 */
public class DataConvert {

    private DataConvert() {
    }

    /**
     * 转换并填充数据；响应字节不足时停止解析，未覆盖字段保持 {@code valuePresent=false}。
     *
     * @return 成功填充的字段数量
     */
    public static int convertAndFillValue(List<ModbusReadFiled> list, byte[] data) {
        for (ModbusReadFiled field : list) {
            field.setValuePresent(false);
        }
        if (list.isEmpty()) {
            return 0;
        }
        byte[] payload = data != null ? data : new byte[0];
        String hexStr = ByteUtil.bytes2HexStr(payload);
        int startIndex = 0;
        int filled = 0;
        for (ModbusReadFiled modbusReadFiled : list) {
            int endIndex = startIndex + modbusReadFiled.getHexLength() * 2;
            if (endIndex > hexStr.length()) {
                break;
            }
            long value = ByteUtil.hexStr2decimal(hexStr.substring(startIndex, endIndex));
            modbusReadFiled.setValue(value);
            modbusReadFiled.setValuePresent(true);
            startIndex = endIndex;
            filled++;
        }
        return filled;
    }

    public static boolean isTruncatedResponse(List<ModbusReadFiled> list) {
        if (list == null || list.isEmpty()) {
            return false;
        }
        for (ModbusReadFiled field : list) {
            if (!field.isValuePresent()) {
                return true;
            }
        }
        return false;
    }
}
