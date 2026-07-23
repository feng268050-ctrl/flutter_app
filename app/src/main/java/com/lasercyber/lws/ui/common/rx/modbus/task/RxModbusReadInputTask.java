package com.lasercyber.lws.ui.common.rx.modbus.task;

import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.rx.modbus.ModbusManagerRtu;
import com.lasercyber.lws.ui.common.rx.modbus.call.RxModbusCallBack;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusReadFiled;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;

import java.util.List;

import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.experimental.Accessors;

/**
 * 读取输入寄存器定时任务
 */
@EqualsAndHashCode(callSuper = true)
@Accessors(chain = true)
@Data
public class RxModbusReadInputTask extends AbstractRxModbusTask{
    /**
     * 批量字段
     */
    private List<ModbusReadFiled> modbusFields;
    /**
     * 回调函数
     */
    private RxModbusCallBack callBack;
    @Override
    public void run() {
//        ThreadPoolManager.getExecutor().execute(()->{
//            Log.d(LogTAGConstant.RxModbusTask, "正在执行任务["+getTaskId()+"]");
            ModbusManagerRtu modbusManagerRtu = ModbusManagerRtu.get();
            modbusManagerRtu.readInputRegisters(modbusFields,callBack);
//        });
    }
}
