package com.lasercyber.lws.ui.common.modbus;

import android.os.Handler;
import android.os.Looper;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.modbus.call.ModbusLogger;
import com.lasercyber.lws.ui.common.modbus.call.SerialConnectionCallback;
import com.lasercyber.lws.ui.common.modbus.call.TaskQueueStatusCallback;
import com.lasercyber.lws.ui.common.config.ModbusConfig;
import com.lasercyber.lws.ui.common.modbus.core.ModbusTask;
import com.lasercyber.lws.ui.common.modbus.core.PriorityTaskQueue;
import com.lasercyber.lws.ui.common.modbus.core.SerialPortHelper;
import com.lasercyber.lws.ui.common.modbus.core.WorkerThread;
import com.lasercyber.lws.ui.common.modbus.enums.ModbusProtocolType;
import com.lasercyber.lws.ui.common.modbus.log.ModbusLogConstant;
import com.lasercyber.lws.ui.common.modbus.monitor.CrashMonitor;
import com.lasercyber.lws.ui.common.modbus.protocol.ModbusProtocol;
import com.lasercyber.lws.ui.common.modbus.protocol.ModbusResponse;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

/**
 * Modbus 核心管理器（调度中心）
 */
public class ModbusManager {
    private static final String TAG = LogTAGConstant.ModbusManager;
    private static volatile ModbusManager instance;
    private final SerialPortHelper serialPortHelper;
    private final PriorityTaskQueue taskQueue;
    private final ModbusLogger logger;
    private final CrashMonitor crashMonitor;
    private  WorkerThread workerThread; // 替换为自定义 WorkerThread
    private final TimerTaskManager timerTaskManager;
    private ModbusProtocolType lastProtocolType;

    // 单例初始化（不变）
    public static ModbusManager getInstance(ModbusLogger logger) {
        if (instance == null) {
            synchronized (ModbusManager.class) {
                if (instance == null) {
                    instance = new ModbusManager(logger);
                    logger.log(TAG, "ModbusManager实例创建完成====>");
                }
            }
        }
        return instance;
    }

    private ModbusManager(ModbusLogger logger) {
        logger.log(TAG, "ModbusManager 初始化中......");
        this.logger = logger;
        this.crashMonitor = CrashMonitor.getInstance();
        this.taskQueue = new PriorityTaskQueue();
        this.serialPortHelper = new SerialPortHelper(new SerialConnectionCallback() {
            @Override
            public void onConnected() {
                logger.log(TAG, "串口连接成功");
                taskQueue.clearAllTask();
                startWorkerThread(); // 串口连接成功后启动工作线程
            }

            @Override
            public void onDisconnected() {
                logger.log(TAG, "串口断开连接");
                stopWorkerThread(); // 串口断开后停止工作线程
            }

            @Override
            public void onReconnecting(int retryCount) {
                logger.log(TAG, "串口重连中（第" + retryCount + "次）");
            }

            @Override
            public void onReconnectFailed(int totalRetryCount) {
                logger.log(TAG, "串口重连失败（共" + totalRetryCount + "次）");
            }
        });
        this.timerTaskManager = new TimerTaskManager(this);
        initTaskQueueStatusCallback();
    }

    // ------------------- 关键修改：启动工作线程 -------------------
    private void startWorkerThread() {
        // 检查线程是否已在运行（避免重复启动）
        if (workerThread != null && workerThread.isThreadRunning()) {
            logger.log(TAG, "工作线程已在运行，无需重复启动");
            return;
        }

        // 创建自定义 WorkerThread，传入核心任务（workerRun）
        workerThread = new WorkerThread(this::workerRun, "Modbus-Worker");
        // 设置线程状态监听器（可选，用于日志跟踪）
        workerThread.setOnThreadStateListener(new WorkerThread.OnThreadStateListener() {
            @Override
            public void onThreadStarted(String threadName) {
                logger.log(TAG, "工作线程启动成功：" + threadName);
            }

            @Override
            public void onThreadInterrupting(String threadName) {
                logger.log(TAG, "工作线程正在中断：" + threadName);
            }

            @Override
            public void onThreadTerminated(String threadName) {
                logger.log(TAG, "工作线程已终止：" + threadName);
                workerThread = null; // 线程终止后置空，避免内存泄漏
            }
        });

        // 启动线程
        workerThread.start();
    }

    // ------------------- 关键修改：停止工作线程 -------------------
    private void stopWorkerThread() {
        if (workerThread != null) {
            workerThread.safeInterrupt(); // 调用自定义的安全中断方法
            // 无需手动置空，线程终止后会在 onThreadTerminated 中置空
        } else {
            logger.log(TAG, "工作线程未启动，无需停止");
        }
    }

    // ------------------- 核心任务逻辑（workerRun 不变） -------------------
    private void workerRun() {
        while (workerThread != null && workerThread.isThreadRunning()) { // 用自定义线程的运行状态判断
            try {
                // 1. 获取下一个任务（超时1秒）
                ModbusTask task = taskQueue.take(1000);
                if (task == null) continue;

                // 2. 检查任务是否取消
                if (task.isCancelled()) {
                    logger.logTask(task.getTaskId(), getPriorityDesc(task), ModbusLogConstant.CANCELLED, "任务已取消");
                    continue;
                }

                // 3. 协议间隔控制
                controlProtocolInterval(task.getProtocolType());

                // 4. 发送数据
                logger.logTask(task.getTaskId(), getPriorityDesc(task), ModbusLogConstant.SEND, "发送数据：" + bytesToHex(task.getRequestData()));
                boolean sendSuccess = serialPortHelper.sendData(task.getRequestData(), ModbusConfig.SEND_TIMEOUT);
                if (!sendSuccess) {
                    handleSendFailed(task, "发送数据失败");
                    continue;
                }

                // 5. 接收响应
                byte[] responseData = serialPortHelper.receiveData(ModbusConfig.RECEIVE_TIMEOUT);
                if (responseData == null) {
                    handleSendFailed(task, "接收响应超时");
                    continue;
                }

                // 6. 解析响应
                logger.logTask(task.getTaskId(), getPriorityDesc(task), ModbusLogConstant.RECEIVE, "接收数据：" + bytesToHex(responseData));
                ModbusResponse response = ModbusProtocol.parseResponse(responseData);
                if (response.isSuccess()) {
                    handleSendSuccess(task, response);
                } else {
                    handleSendFailed(task, response.getErrorMsg());
                }

                // 7. 更新上一次协议类型
                lastProtocolType = task.getProtocolType();

            } catch (InterruptedException e) {
                // 捕获线程中断异常（自定义线程已处理中断标记）
                logger.log(TAG, "工作线程捕获中断信号，准备退出");
                break;
            } catch (Exception e) {
                crashMonitor.reportException(e);
                logger.log(TAG, "工作线程异常：" + e.getMessage());
            }
        }
    }

    // ------------------- 其他原有方法（不变） -------------------
    private void controlProtocolInterval(ModbusProtocolType currentType) {
        if (lastProtocolType == null) return;
        long interval = ModbusConfig.COMMAND_INTERVAL_MS;
        try {
            Thread.sleep(interval);
            logger.log(TAG, "协议间隔：" + interval + "ms（上一次：" + lastProtocolType + "，当前：" + currentType + "）");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    /**
     * 成功处理
     *
     * @param task
     * @param response
     */
    private void handleSendSuccess(ModbusTask task, ModbusResponse response) {
        logger.logTask(task.getTaskId(), getPriorityDesc(task), ModbusLogConstant.SUCCESS, "响应解析成功");
        if (task.getCallback() != null) {
            new Handler(Looper.getMainLooper()).post(() -> task.getCallback().onSuccess(task, response));
        }
//        if (!task.isUiTask()) {
//            taskQueue.addTask(task);
//        }
    }

    /**
     * 失败处理
     *
     * @param task
     * @param errorMsg
     */
    private void handleSendFailed(ModbusTask task, String errorMsg) {
        task.incrementRetryCount();
        logger.logTask(task.getTaskId(), getPriorityDesc(task), ModbusLogConstant.FAILED, "错误：" + errorMsg + "，已重试：" + task.getRetryCount() + "/" + task.getMaxRetryCount());

        if (task.getRetryCount() < task.getMaxRetryCount()) {
            taskQueue.addTask(task);
            logger.logTask(task.getTaskId(), getPriorityDesc(task), ModbusLogConstant.RETRY, "准备重试");
        } else {
            if (task.getCallback() != null) {
                new Handler(Looper.getMainLooper()).post(() -> task.getCallback().onFailed(task, errorMsg));
            }
            if (task.getRetryFailedCallback() != null) {
                new Handler(Looper.getMainLooper()).post(task.getRetryFailedCallback());
            }
            logger.logTask(task.getTaskId(), getPriorityDesc(task), ModbusLogConstant.RETRY_FAILED, "重试次数耗尽");
        }
    }

    // 对外API（openSerialPort、closeSerialPort、addTask等）均不变...

    private String getPriorityDesc(ModbusTask task) {
        return task.isUiTask() ? "UI_TASK(最高)" : "TIMER_TASK(" + task.getPriority() + ")";
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02X ", b));
        }
        return sb.toString().trim();
    }

    // TimerTaskManager 内部类（不变）
    private static class TimerTaskManager {
        private final Map<String, Timer> timerMap = new HashMap<>();
        private final ModbusManager modbusManager;

        public TimerTaskManager(ModbusManager modbusManager) {
            this.modbusManager = modbusManager;
        }

        public void addTimerTask(ModbusTask task, long intervalMs) {
            Timer timer = new Timer("Modbus-Timer-" + task.getTaskId());
            timer.schedule(new TimerTask() {
                @Override
                public void run() {
                    if (!task.isCancelled()) {
                        modbusManager.taskQueue.addTask(task);
                    } else {
                        cancel();
                        timerMap.remove(task.getTaskId());
                    }
                }
            }, 0, intervalMs);
            timerMap.put(task.getTaskId(), timer);
        }

        public void removeTimerTask(String taskId) {
            Timer timer = timerMap.remove(taskId);
            if (timer != null) {
                timer.cancel();
            }
        }

        public void stopAllTimerTasks() {
            timerMap.values().forEach(Timer::cancel);
            timerMap.clear();
        }
    }

    /**
     * 初始化任务队列状态回调：当队列任务数变化时，记录日志（支持UI层扩展）
     */
    private void initTaskQueueStatusCallback() {
        // 给 PriorityTaskQueue 设置状态回调，监听队列大小变化
        taskQueue.setStatusCallback(new TaskQueueStatusCallback() {
            @Override
            public void onQueueSizeChanged(int size) {
                // 队列大小变化时，通过日志记录（UI层可在此基础上扩展UI更新）
                logger.log(TAG, "任务队列大小更新：当前等待任务数 = " + size);
                // 若需UI层实时显示，可在此处添加UI回调（如通过接口通知Activity）
                // 示例：if (uiStatusCallback != null) uiStatusCallback.onQueueSizeUpdate(size);
            }
        });
    }

    // ------------ 对外API ------------
    // 打开串口
    public void openSerialPort() {
        if(serialPortHelper.isConnected()){
            logger.log(TAG, "串口已打开，不用重复打开");
            return;
        }
        serialPortHelper.open();
    }
    // 关闭串口
    public void closeSerialPort() {
        serialPortHelper.close();
        timerTaskManager.stopAllTimerTasks();
        taskQueue.cancelAllTasks();
    }

    // 添加单个任务（UI任务优先）
    public void addTask(ModbusTask task) {
        taskQueue.addTask(task);
        logger.logTask(task.getTaskId(), getPriorityDesc(task), ModbusLogConstant.ADD_UI, "任务加入队列");
    }

    // 批量添加任务
    public void addTasks(List<ModbusTask> tasks) {
        taskQueue.addTasks(tasks);
        tasks.forEach(task -> logger.logTask(task.getTaskId(), getPriorityDesc(task), ModbusLogConstant.ADD_BATCH, "批量任务加入队列"));
    }

    // 取消任务（通过任务ID）
    public boolean cancelTask(String taskId) {
        boolean success = taskQueue.cancelTask(taskId);
        logger.log(TAG, "取消任务：" + taskId + "，结果：" + success);
        return success;
    }

    // 取消所有任务
    public void cancelAllTasks() {
        taskQueue.cancelAllTasks();
        logger.log(TAG, "取消所有未执行任务");
    }

    /**
     * 清空所有未执行任务，包括定时任务
     */
    public void clearAllTasks(){
        timerTaskManager.stopAllTimerTasks();
        taskQueue.cancelAllTasks();
        logger.log(TAG, "清空所有未执行任务，包括定时任务");
    }
    // 添加定时任务（轮询发送）
    public void addTimerTask(ModbusTask task, long intervalMs) {
        timerTaskManager.addTimerTask(task, intervalMs);
        logger.logTask(task.getTaskId(), getPriorityDesc(task), ModbusLogConstant.ADD_TIMER, "定时任务添加，间隔：" + intervalMs + "ms");
    }

    // 移除定时任务
    public void removeTimerTask(String taskId) {
        timerTaskManager.removeTimerTask(taskId);
        cancelTask(taskId);
        logger.log(TAG, "移除定时任务：" + taskId);
    }

    // 获取等待任务数
    public int getTaskQueueSize() {
        return taskQueue.getSize();
    }
    /**
     *  增加单例销毁方法（用于退出时清理资源）
     */
    public void destroy() {
        synchronized (ModbusManager.class) {
            if (instance != null) {
                stopWorkerThread();
                closeSerialPort();
                instance = null;
                logger.log(TAG, "ModbusManager实例已销毁");
            }
        }
    }
}
