package com.lasercyber.lws.ui.common.enums;

public enum RxTaskOperationType {
    /**
     * 读取线圈
     */
    ReadCoils,
    /**
     * 读取输入，目前使用这个
     */
    ReadInputRegisters,
    /**
     * 读取保持寄存器
     */
    ReadHoldingRegisters,
    /**
     * 写单个线圈
     */
    WriteSingleCoil,
    /**
     * 写单个寄存器
     */
    WriteSingleRegister,
    /**
     * 写多个线圈
     */
    WriteMultipleCoils,
    /**
     * 写多个寄存器，目前使用这个
     */
    WriteMultipleRegisters,
    /**
     * 读取设备标识
     */
    ReportSlaveId,
    /**
     * 读取设备标识
     */
    ReadDeviceIdentification;

}
