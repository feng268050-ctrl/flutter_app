package com.lasercyber.lws.ui.common.modbus.protocol;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.nio.ByteBuffer;
import java.util.Arrays;

/**
 * Modbus协议解析工具类
 */
public class ModbusProtocol {
    private static final String TAG = LogTAGConstant.ModbusProtocol;
    private static final int MIN_RESPONSE_LENGTH = 3;

    /**
     * 构建Modbus RTU请求帧（CRC自动计算）
     * @param slaveId
     * @param functionCode
     * @param startAddr
     * @param quantity
     * @return
     */
    public static byte[] buildRequest(int slaveId, int functionCode, int startAddr, int quantity) {
        ByteBuffer buffer = ByteBuffer.allocate(8);
        buffer.put((byte) slaveId);
        buffer.put((byte) functionCode);
        buffer.putShort((short) startAddr);
        buffer.putShort((short) quantity);
        byte[] data = buffer.array();
        int crc = calculateCRC(data, 6); // 前6字节计算CRC
        return ByteBuffer.allocate(8)
                .put(data, 0, 6)
                .putShort((short) crc)
                .array();
    }

    // 解析响应帧
    public static ModbusResponse parseResponse(byte[] response) {
        ModbusResponse result = new ModbusResponse();
        if (response == null || response.length < MIN_RESPONSE_LENGTH) {
            result.setSuccess(false);
            result.setErrorMsg("响应数据长度异常");
            return result;
        }

        int slaveId = response[0] & 0xFF;
        int functionCode = response[1] & 0xFF;

        // 正常响应
        result.setSlaveId(slaveId);
        result.setFunctionCode(functionCode);
        result.setData(Arrays.copyOfRange(response, 2, response.length - 2)); // 去掉CRC
        result.setSuccess(true);
        return result;
    }

    // CRC16计算
    private static int calculateCRC(byte[] data, int length) {
        int crc = 0xFFFF;
        for (int i = 0; i < length; i++) {
            crc ^= data[i] & 0xFF;
            for (int j = 0; j < 8; j++) {
                if ((crc & 0x0001) != 0) {
                    crc = (crc >> 1) ^ 0xA001;
                } else {
                    crc >>= 1;
                }
            }
        }
        return crc;
    }

    // CRC校验
    private static boolean verifyCRC(byte[] data) {
        int crc = calculateCRC(data, data.length - 2);
        int responseCrc = ((data[data.length - 2] & 0xFF) | ((data[data.length - 1] & 0xFF) << 8));
        return crc == responseCrc;
    }
}
