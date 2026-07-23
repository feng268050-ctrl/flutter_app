package com.lasercyber.lws.ui.common.rx.modbus;


import android.annotation.SuppressLint;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.blankj.utilcode.util.GsonUtils;
import com.licheedev.modbus4android.ModbusCallback;
import com.licheedev.modbus4android.param.SerialParam;
import com.lasercyber.lws.ui.common.config.ModbusConfig;
import com.lasercyber.lws.ui.common.config.SerialPortConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.rx.modbus.call.RxModbusCallBack;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusHexData;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusMockReadValues;
import com.lasercyber.lws.ui.common.rx.modbus.protocol.ModbusReadFiled;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.modbus.DataConvert;
import com.serotonin.modbus4j.Modbus;
import com.serotonin.modbus4j.ModbusMaster;
import com.serotonin.modbus4j.exception.ModbusTransportException;
import com.serotonin.modbus4j.msg.ReadInputRegistersResponse;
import com.serotonin.modbus4j.msg.WriteRegistersResponse;
import com.serotonin.modbus4j.sero.messaging.TimeoutException;

import java.util.Arrays;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.stream.Collectors;

import io.reactivex.rxjava3.annotations.NonNull;
import io.reactivex.rxjava3.core.Observable;
import io.reactivex.rxjava3.core.ObservableOnSubscribe;
import io.reactivex.rxjava3.core.ObservableSource;
import io.reactivex.rxjava3.core.Observer;
import io.reactivex.rxjava3.disposables.Disposable;
import io.reactivex.rxjava3.schedulers.Schedulers;

public class ModbusManagerRtu extends RxModbusWorker {
    private static final String TAG = LogTAGConstant.ModbusManagerRtu;
    private static volatile ModbusManagerRtu sInstance;
    private final ScheduledExecutorService serialSendExecutor =
            Executors.newSingleThreadScheduledExecutor(r -> {
                Thread thread = new Thread(r, "modbus-serial-send");
                thread.setDaemon(true);
                return thread;
            });
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ModbusSerialGate serialGate = ModbusSerialGate.getInstance();
    private static final boolean debugLog = true;

    /**
     * 获取实例
     *
     * @return
     */
    public static ModbusManagerRtu get() {
        ModbusManagerRtu manager = sInstance;
        if (manager == null) {
            synchronized (ModbusManagerRtu.class) {
                manager = sInstance;
                if (manager == null) {
                    if (debugLog) Log.d(TAG, "正在创建modbus管理器====>");
                    manager = new ModbusManagerRtu();
                    sInstance = manager;
                }
            }
        }
        return manager;
    }

    private ModbusManagerRtu() {
    }

    /**
     * 释放整个ModbusManager，单例会被置null
     */
    public synchronized void release() {
        serialSendExecutor.shutdown();
        super.release();
        sInstance = null;
    }

    /**
     * Serial Modbus command executor; all subscribeOn for RTU I/O should use this.
     */
    @NonNull
    ScheduledExecutorService serialSendExecutor() {
        return serialSendExecutor;
    }

    /**
     * 打开串口
     */
    public ModbusManagerRtu openSerialPort(ModbusCallback callback) {
        try {
            super.setSendIntervalTime(0);
            SerialParam serialParam = SerialParam.create(
                            SerialPortConfig.DEVICE_PATH, SerialPortConfig.BAUD_RATE
                    )
                    .setDataBits(SerialPortConfig.DATA_BITS)
                    .setParity(SerialPortConfig.PARITY)
                    .setStopBits(SerialPortConfig.STOP_BITS)
                    .setTimeout(SerialPortConfig.TIME_OUT)
                    .setRetries(SerialPortConfig.RETRIES);
            serialSendExecutor.execute(() -> {
                try {
                    // callableInit destroys any existing master on mRequestExecutor (same queue as I/O).
                    ModbusMaster modbusMaster = syncInit(serialParam);
                    ModbusStartupState.markAvailable();
                    if (debugLog) Log.d(TAG, "modbus链接成功");
                    dispatchCallbackSuccess(callback, modbusMaster);
                } catch (Throwable tr) {
                    ModbusStartupState.markUnavailable(
                            ModbusStartupState.REASON_INIT_FAILED, "Modbus init failed", tr);
                    Log.e(TAG, "modelBus连接失败", tr);
                    dispatchCallbackFailure(callback, tr);
                }
            });
        } catch (Throwable throwable) {
            ModbusStartupState.markUnavailable(
                    ModbusStartupState.REASON_UNEXPECTED_ERROR, "Modbus init threw fatal throwable", throwable);
            dispatchCallbackFailure(callback, throwable);
        }
        return this;
    }

    private void dispatchCallbackSuccess(@NonNull ModbusCallback<ModbusMaster> callback,
                                         @NonNull ModbusMaster modbusMaster) {
        mainHandler.post(() -> {
            try {
                callback.onSuccess(modbusMaster);
            } finally {
                try {
                    callback.onFinally();
                } catch (Exception e) {
                    Log.w(TAG, "Modbus init onFinally failed", e);
                }
            }
        });
    }

    private void dispatchCallbackFailure(ModbusCallback<?> callback, Throwable tr) {
        mainHandler.post(() -> {
            try {
                callback.onFailure(tr);
            } finally {
                try {
                    callback.onFinally();
                } catch (Exception e) {
                    Log.w(TAG, "Modbus init onFinally failed", e);
                }
            }
        });
    }

    /**
     * 读取输入寄存器
     * 默认的从机地址为1，读取完成后，自动转为10进制数据，并填充到字段的value中
     *
     * @param modbusReadFields
     * @param rxModbusCallBack
     */
    public void readInputRegistersSort(List<ModbusReadFiled> modbusReadFileds, RxModbusCallBack rxModbusCallBack) {
        readInputRegistersSort(modbusReadFileds, rxModbusCallBack, ModbusTraffic.READ);
    }

    /**
     * Read {@code otaUpgradeCmd} during OTA await-confirm phase (allowed under exclusive session).
     */
    public void readInputRegistersOtaConfirm(List<ModbusReadFiled> modbusReadFileds,
                                             RxModbusCallBack rxModbusCallBack) {
        readInputRegistersSort(modbusReadFileds, rxModbusCallBack, ModbusTraffic.OTA_STATUS_READ);
    }

    private void readInputRegistersSort(List<ModbusReadFiled> modbusReadFileds,
                                        RxModbusCallBack rxModbusCallBack,
                                        ModbusTraffic traffic) {
        if (!ModbusConfig.isMock() && !isCanSendData()) {
            rxModbusCallBack.onFailure(notReadyError());
            return;
        }
        List<ModbusReadFiled> list = modbusReadFileds.stream().sorted().collect(Collectors.toList());
        readInputRegisters(list, rxModbusCallBack, traffic);
    }

    public void readInputRegisters(List<ModbusReadFiled> modbusReadFields, RxModbusCallBack rxModbusCallBack) {
        readInputRegisters(modbusReadFields, rxModbusCallBack, ModbusTraffic.READ);
    }

    private void readInputRegisters(List<ModbusReadFiled> modbusReadFields,
                                    RxModbusCallBack rxModbusCallBack,
                                    ModbusTraffic traffic) {
        if (!ModbusConfig.isMock() && !isCanSendData()) {
            rxModbusCallBack.onFailure(notReadyError());
            return;
        }
        IllegalStateException blocked = ModbusOtaExclusiveSession.checkBlocked(traffic);
        if (blocked != null) {
            rxModbusCallBack.onFailure(blocked);
            return;
        }
        if (modbusReadFields.size() > Modbus.DEFAULT_MAX_READ_REGISTER_COUNT) {
            Log.w(TAG, "读取输入寄存器数量超过 Modbus 上限 "
                    + Modbus.DEFAULT_MAX_READ_REGISTER_COUNT + ": " + modbusReadFields.size());
        }
        if (ModbusConfig.isMock()) {
            ModbusMockReadValues.apply(modbusReadFields);
            if (debugLog) Log.d(TAG, "doWriteRegisters: 模拟读取数据：");
            Observable.just(modbusReadFields).subscribe(
                    data -> rxModbusCallBack.onSuccess(data),
                    error -> rxModbusCallBack.onFailure(error),
                    () -> {});
            return;
        }
        withSerialGate(
                traffic,
                super.rxReadInputRegisters(
                        ModbusConfig.SLAVE_DEVICE_ADDRESS,
                        modbusReadFields.get(0).getAddress(),
                        modbusReadFields.size()))
                .observeOn(Schedulers.from(ThreadPoolManager.getExecutor()))
                .subscribe(new Observer<ReadInputRegistersResponse>() {
                    @Override
                    public void onSubscribe(@NonNull Disposable d) {
                    }

                    @Override
                    public void onNext(@NonNull ReadInputRegistersResponse readInputRegistersResponse) {
                        int filled = DataConvert.convertAndFillValue(
                                modbusReadFields, readInputRegistersResponse.getData());
                        if (filled < modbusReadFields.size()) {
                            Log.w(TAG, "Truncated Modbus input register response: filled="
                                    + filled + " expected=" + modbusReadFields.size()
                                    + " startAddress=0x"
                                    + Integer.toHexString(modbusReadFields.get(0).getAddress()));
                        }
                        rxModbusCallBack.onSuccess(modbusReadFields);
                    }

                    @Override
                    public void onError(@NonNull Throwable e) {
                        errorHandler(e);
                        rxModbusCallBack.onFailure(e);
                    }

                    @Override
                    public void onComplete() {
                    }
                });
    }

    /**
     * 下发批量写
     *
     * @param modbusHexDatas
     */
    @SuppressLint("CheckResult")
    public void writeRegisters(List<ModbusHexData> modbusHexDatas) {
        if (!ModbusConfig.isMock() && !isCanSendData()) {
            Log.w(TAG, "writeRegisters skipped: modbus not ready");
            return;
        }
        subscribeWrite(ModbusTraffic.WRITE, modbusHexDatas, null);
    }

    public void writeRegistersOta(List<ModbusHexData> modbusHexDatas, WriteCallback writeCallback) {
        if (!ModbusConfig.isMock() && !isCanSendData()) {
            if (writeCallback != null) {
                writeCallback.onFailure();
            }
            return;
        }
        subscribeWrite(ModbusTraffic.OTA_WRITE, modbusHexDatas, writeCallback);
    }

    public @NonNull Observable<WriteRegistersResponse> doWriteRegisters(List<ModbusHexData> modbusHexDatas) {
        return doWriteRegistersInternal(modbusHexDatas);
    }

    private @NonNull Observable<WriteRegistersResponse> doWriteRegistersInternal(List<ModbusHexData> modbusHexDatas) {
        if (!ModbusConfig.isMock() && !isCanSendData()) {
            return Observable.error(new Throwable("未连接"));
        }
        short[] values = new short[modbusHexDatas.size()];
        for (int i = 0; i < modbusHexDatas.size(); i++) {
            values[i] = (short) modbusHexDatas.get(i).getValue();
        }
        if (debugLog) {
            Log.d(TAG, "批量下发数据：" + modbusHexDatas.get(0).getAddress() + "==>" + Arrays.toString(values));
        }
        if (ModbusConfig.isMock()) {
            return Observable.create((ObservableOnSubscribe<WriteRegistersResponse>) emitter -> {
                if (debugLog) {
                    Log.d(TAG, "doWriteRegisters: 模拟下发数据：" + GsonUtils.toJson(modbusHexDatas));
                }
                emitter.onComplete();
            }).subscribeOn(Schedulers.io());
        }
        return super.rxWriteRegisters(
                ModbusConfig.SLAVE_DEVICE_ADDRESS,
                modbusHexDatas.get(0).getAddress(),
                values);
    }

    private void subscribeWrite(
            ModbusTraffic traffic,
            List<ModbusHexData> modbusHexDatas,
            WriteCallback writeCallback) {
        if (ModbusConfig.isMock()) {
            if (writeCallback != null) {
                writeCallback.onSuccess();
            }
            return;
        }
        IllegalStateException blocked = ModbusOtaExclusiveSession.checkBlocked(traffic);
        if (blocked != null) {
            Log.w(TAG, "write blocked: " + blocked.getMessage());
            if (writeCallback != null) {
                writeCallback.onFailure();
            }
            return;
        }
        withSerialGate(traffic, doWriteRegistersInternal(modbusHexDatas))
                .observeOn(Schedulers.from(ThreadPoolManager.getExecutor()))
                .subscribe(new Observer<>() {
                    @Override
                    public void onSubscribe(@NonNull Disposable d) {
                    }

                    @Override
                    public void onNext(@NonNull WriteRegistersResponse response) {
                        if (response.isException()) {
                            if (writeCallback != null) {
                                writeCallback.onFailure();
                            }
                            Log.e(TAG, "写入失败，异常码: " + response.getExceptionCode());
                        } else {
                            if (debugLog) Log.d(TAG, "写入成功!");
                            if (writeCallback != null) {
                                writeCallback.onSuccess();
                            }
                        }
                    }

                    @Override
                    public void onError(@NonNull Throwable e) {
                        errorHandler(e);
                        if (writeCallback != null) {
                            writeCallback.onFailure();
                        }
                        Log.e(TAG, "写入失败: " + e.getMessage(), e);
                    }

                    @Override
                    public void onComplete() {
                    }
                });
    }

    /**
     * 写入数据，并回调
     * @param modbusHexDatas
     * @param writeCallback
     */
    public void writeRegistersCall(List<ModbusHexData> modbusHexDatas, WriteCallback writeCallback) {
        if (!ModbusConfig.isMock() && !isCanSendData()) {
            if (writeCallback != null) {
                writeCallback.onFailure();
            }
            return;
        }
        if (ModbusConfig.isMock()) {
            if (debugLog) Log.d(TAG, "writeRegistersCall: 当前为mock模式，快速响应成功");
            if (writeCallback != null) {
                writeCallback.onSuccess();
            }
            return;
        }
        subscribeWrite(ModbusTraffic.WRITE, modbusHexDatas, writeCallback);
    }
    /**
     * 下发批量写，包含排序
     *
     * @param modbusHexDatas
     */
    public void writeRegistersSort(List<ModbusHexData> modbusHexDatas) {
        if (!ModbusConfig.isMock() && !isCanSendData()) {
            Log.w(TAG, "writeRegistersSort skipped: modbus not ready");
            return;
        }
        List<ModbusHexData> list = modbusHexDatas.stream().sorted().collect(Collectors.toList());
        writeRegisters(list);
    }

    private static IllegalStateException notReadyError() {
        return new IllegalStateException("Modbus not ready: "
                + ModbusStartupState.getReasonCode() + " " + ModbusStartupState.getReasonMessage());
    }

    /**
     * 异常处理
     * @param throwable
     */
    public void errorHandler(Throwable throwable){
        if (throwable instanceof TimeoutException||throwable instanceof ModbusTransportException){
            // TODO 处理超时
        }
    }
    /**
     * 检查设备是否可以发送数据
     * @return true: 可以发送数据
     *          false: 不可以发送数据
     */
    public boolean isCanSendData() {
        if (ModbusConfig.isMock()) {
            return true;
        }
        if (!ModbusStartupState.isAvailable()) {
            Log.w(TAG, "Modbus unavailable, skip send. reason=" + ModbusStartupState.getReasonCode() + ", message=" + ModbusStartupState.getReasonMessage());
            return false;
        }
        if (!isModbusOpened()) {
            return false;
        }
        try {
            ModbusMaster master = getModbusMaster();
            return master != null && master.isInitialized();
        } catch (Throwable throwable) {
            Log.e(TAG, "Check modbus state failed", throwable);
            return false;
        }
    }
    /**
     * 写入的回调接口
     */
    public interface WriteCallback{
        void onSuccess();
        void onFailure();
    }

    private <T> Observable<T> withSerialGate(ModbusTraffic traffic, ObservableSource<T> source) {
        IllegalStateException blocked = ModbusOtaExclusiveSession.checkBlocked(traffic);
        if (blocked != null) {
            return Observable.error(blocked);
        }
        return Observable.<T>defer(() -> Observable.create(emitter -> {
                    serialGate.beginCommand();
                    try {
                        serialGate.awaitBeforeCommand();
                        source.subscribe(new Observer<T>() {
                            @Override
                            public void onSubscribe(@NonNull Disposable d) {
                            }

                            @Override
                            public void onNext(@NonNull T value) {
                                emitter.onNext(value);
                            }

                            @Override
                            public void onError(@NonNull Throwable e) {
                                serialGate.markCommandEnd();
                                serialGate.endCommand();
                                emitter.onError(e);
                            }

                            @Override
                            public void onComplete() {
                                serialGate.markCommandEnd();
                                serialGate.endCommand();
                                emitter.onComplete();
                            }
                        });
                    } catch (Throwable t) {
                        serialGate.endCommand();
                        emitter.onError(t);
                    }
                }))
                .subscribeOn(Schedulers.from(serialSendExecutor));
    }
}
