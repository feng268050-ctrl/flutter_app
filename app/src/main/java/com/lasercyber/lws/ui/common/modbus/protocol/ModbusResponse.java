package com.lasercyber.lws.ui.common.modbus.protocol;

import lombok.Data;

/**
 * Modbus RTU 协议响应数据模型
 * 封装从串口接收并解析后的完整响应信息，包含设备地址、功能码、业务数据及执行状态，
 * 用于在核心层与UI层之间传递标准化的响应结果，减少UI层协议解析逻辑
 */
@Data
public class ModbusResponse {
    /**
     * 从站地址（Slave ID）
     * 对应Modbus RTU请求帧中的第一个字节，标识当前响应来自哪个从设备（范围：1-247）
     */
    private int slaveId;

    /**
     * 功能码（Function Code）
     * 对应Modbus RTU请求中的功能码，标识当前响应对应的操作类型（如0x03：读保持寄存器，0x06：写单个寄存器）
     * 若为错误响应，功能码最高位会置1（如0x83表示读保持寄存器操作失败）
     */
    private int functionCode;

    /**
     * 业务数据字节数组
     * 解析后的数据内容，格式与功能码对应（如0x03功能码下为寄存器值的字节数组，需根据业务需求转成对应类型）
     * 错误响应时该字段为null
     */
    private byte[] data;

    /**
     * 响应执行状态
     * true：响应正常（CRC校验通过、无协议错误），可正常使用data字段；
     * false：响应异常（CRC校验失败、协议错误、设备无响应等），错误信息通过errorMsg字段获取
     */
    private boolean success;

    /**
     * 错误描述信息
     * success为false时有效，记录具体错误原因（如"CRC校验失败"、"响应数据长度异常"、"Modbus错误码：0x02"）
     * success为true时该字段为null或空字符串
     */
    private String errorMsg;
}
