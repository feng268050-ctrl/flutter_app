package com.lasercyber.lws.ui.common.modbus.core;

import android.serialport.SerialPort;
import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.config.SerialPortConfig;
import com.lasercyber.lws.ui.common.modbus.monitor.CrashMonitor;
import com.lasercyber.lws.ui.common.modbus.call.SerialConnectionCallback;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.ReentrantLock;

/**
 * 串口通信工具类（自动重连，线程安全优化版）
 */
public class SerialPortHelper {
    private static final String TAG = LogTAGConstant.SerialPortHelper;
    private SerialPort serialPort;
    private InputStream inputStream;
    private OutputStream outputStream;
    private final SerialConnectionCallback connectionCallback;
    /**
     * 保护IO操作和状态变量
     */
    private final ReentrantLock ioLock = new ReentrantLock();
    /**
     * 保证多线程可见性
     */
    private volatile boolean isConnected;
    /**
     * 重连状态标记
     */
    private volatile boolean isReconnecting;

    public SerialPortHelper(SerialConnectionCallback connectionCallback) {
        this.connectionCallback = connectionCallback;
    }

    // 打开串口（幂等性，线程安全）
    public boolean open() {
//        if (true){
//            Log.d(TAG, "open: 暂时不需要这里连接=====>");
//            return true;
//        }
        ioLock.lock();
        try {
            if (isConnected) {
                Log.d(TAG, "串口已连接，无需重复打开");
                return true;
            }

            // 关闭旧资源，避免残留
            closeInternal();

            try {
                serialPort = new SerialPort(
                        new File(SerialPortConfig.DEVICE_PATH),
                        SerialPortConfig.BAUD_RATE,
                        SerialPortConfig.DATA_BITS,
                        SerialPortConfig.PARITY,
                        SerialPortConfig.STOP_BITS
                );
                inputStream = serialPort.getInputStream();
                outputStream = serialPort.getOutputStream();
                isConnected = true;
                connectionCallback.onConnected();
                Log.d(TAG, "串口打开成功: " + SerialPortConfig.DEVICE_PATH + ", " + SerialPortConfig.BAUD_RATE);
                return true;
            } catch (Throwable e) {
                CrashMonitor.getInstance().reportException(e);
                Log.e(TAG, "串口打开失败", e);
                closeInternal(); // 打开失败时清理资源
                return false;
            }
        } finally {
            ioLock.unlock();
        }
    }

    // 关闭串口（线程安全）
    public void close() {
        ioLock.lock();
        try {
            closeInternal();
            connectionCallback.onDisconnected();
            Log.d(TAG, "串口关闭");
        } finally {
            ioLock.unlock();
        }
    }

    // 发送数据（带超时锁，线程安全）
    public boolean sendData(byte[] data, long timeoutMs) {
        if (!isConnected) {
            Log.w(TAG, "发送数据失败：串口未连接");
            return false;
        }

        boolean locked = false;
        try {
            locked = ioLock.tryLock(timeoutMs, TimeUnit.MILLISECONDS);
            if (!locked) {
                Log.e(TAG, "发送数据超时：获取锁失败");
                return false;
            }

            if (!isConnected) { // 双重检查，避免获取锁后连接断开
                Log.w(TAG, "发送数据失败：串口已断开");
                return false;
            }

            outputStream.write(data);
            outputStream.flush();
            return true;
        } catch (Throwable e) {
            CrashMonitor.getInstance().reportException(e);
            Log.e(TAG, "发送数据失败", e);
            isConnected = false;
            startReconnect();
            return false;
        } finally {
            if (locked) ioLock.unlock();
        }
    }

    /**
     * 接收数据（带超时，线程安全）
     * @param timeoutMs
     * @return
     */
    public byte[] receiveData(long timeoutMs) {
        if (!isConnected) {
            Log.w(TAG, "接收数据失败：串口未连接");
            return null;
        }

        boolean locked = false;
        try {
            locked = ioLock.tryLock(timeoutMs, TimeUnit.MILLISECONDS);
            if (!locked) {
                Log.e(TAG, "接收数据超时：获取锁失败");
                return null;
            }

            if (!isConnected) { // 双重检查
                Log.w(TAG, "接收数据失败：串口已断开");
                return null;
            }

            ByteArrayOutputStream buffer = new ByteArrayOutputStream();
            long startTime = System.currentTimeMillis();
            while (System.currentTimeMillis() - startTime < timeoutMs) {
                if (inputStream.available() > 0) {
                    byte[] temp = new byte[inputStream.available()];
                    int len = inputStream.read(temp);
                    if (len == -1) break; // 流已关闭
                    buffer.write(temp, 0, len);

                    // Modbus RTU响应完整性校验
                    if (buffer.size() >= 256 || (buffer.size() >= 3 && verifyResponseComplete(buffer.toByteArray()))) {
                        break;
                    }
                } else {
                    Thread.sleep(10); // 避免CPU空转
                }
            }

            byte[] result = buffer.size() > 0 ? buffer.toByteArray() : null;
            Log.d(TAG, "接收数据长度：" + (result != null ? result.length : 0));
            return result;
        } catch (Throwable e) {
            CrashMonitor.getInstance().reportException(e);
            Log.e(TAG, "接收数据失败", e);
            isConnected = false;
            startReconnect();
            return null;
        } finally {
            if (locked) ioLock.unlock();
        }
    }

    // 验证Modbus响应是否完整
    private boolean verifyResponseComplete(byte[] data) {
        if (data.length < 3) return false;
        int functionCode = data[1] & 0xFF;
        // 错误响应：地址(1) + 功能码(1) + 错误码(1) + CRC(2) = 5字节
        if ((functionCode & 0x80) != 0) {
            return data.length >= 5;
        }
        // 正常响应：最小长度5字节（根据功能码可扩展更精确判断）
        return data.length >= 5;
    }

    /**
     * 自动重连（线程安全）
     */
    private void startReconnect() {
        // 加锁保证判断和修改的原子性
        ioLock.lock();
        try {
            if (isReconnecting || isConnected) {
                Log.d(TAG, "无需重连：当前状态 isReconnecting=" + isReconnecting + ", isConnected=" + isConnected);
                return;
            }
            isReconnecting = true;
        } finally {
            ioLock.unlock();
        }

        // 提交重连任务到线程池（守护线程）
        ThreadPoolManager.getExecutor().execute(() -> {
            int retryCount = 0;
            try {
                while (retryCount < SerialPortConfig.MAX_RECONNECT_COUNT && !isConnected) {
                    retryCount++;
                    connectionCallback.onReconnecting(retryCount);
                    Log.d(TAG, "正在重连串口（第" + retryCount + "次），间隔：" + SerialPortConfig.RECONNECT_INTERVAL + "ms");

                    try {
                        Thread.sleep(SerialPortConfig.RECONNECT_INTERVAL);
                        if (isConnected) { // 重连过程中已连接则退出
                            Log.d(TAG, "重连过程中串口已连接，退出重连");
                            break;
                        }
                        if (open()) { // 调用线程安全的open()方法
                            Log.d(TAG, "重连成功");
                            break;
                        }
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        Log.d(TAG, "重连线程被中断，退出重连");
                        break;
                    }
                }

                if (!isConnected) {
                    Log.d(TAG, "重连失败：已重试" + retryCount + "次");
                    connectionCallback.onReconnectFailed(retryCount);
                }
            } finally {
                // 原子化重置重连状态
                ioLock.lock();
                try {
                    isReconnecting = false;
                } finally {
                    ioLock.unlock();
                }
            }
        });
    }

    // 内部关闭资源（避免重复代码）
    private void closeInternal() {
        try {
            if (inputStream != null) {
                inputStream.close();
                inputStream = null;
            }
            if (outputStream != null) {
                outputStream.close();
                outputStream = null;
            }
            if (serialPort != null) {
                serialPort.close();
                serialPort = null;
            }
        } catch (Throwable e) {
            CrashMonitor.getInstance().reportException(e);
            Log.e(TAG, "关闭串口资源失败", e);
        } finally {
            isConnected = false;
        }
    }

    public boolean isConnected() {
        return isConnected;
    }
}