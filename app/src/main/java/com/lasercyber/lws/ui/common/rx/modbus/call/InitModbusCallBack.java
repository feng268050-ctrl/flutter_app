package com.lasercyber.lws.ui.common.rx.modbus.call;

import android.util.Log;

import androidx.annotation.Nullable;

import com.licheedev.modbus4android.ModbusCallback;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.serotonin.modbus4j.ModbusMaster;

/**
 * 初始化modbus回调
 */
public class InitModbusCallBack implements ModbusCallback<ModbusMaster> {
    private static final String TAG = LogTAGConstant.InitModbusCallBack;

    @Nullable
    private final Runnable onReady;

    public InitModbusCallBack() {
        this(null);
    }

    public InitModbusCallBack(@Nullable Runnable onReady) {
        this.onReady = onReady;
    }

    @Override
    public void onSuccess(ModbusMaster modbusMaster) {
        Log.d(TAG, "串口打开成功");
        if (onReady != null) {
            onReady.run();
        }
    }

    @Override
    public void onFailure(Throwable tr) {
        Log.e(TAG, "串口打开失败", tr);
    }

    @Override
    public void onFinally() {

    }
}
