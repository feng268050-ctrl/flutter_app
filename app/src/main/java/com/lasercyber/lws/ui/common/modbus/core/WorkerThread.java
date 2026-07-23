package com.lasercyber.lws.ui.common.modbus.core;

import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

/**
 * 支持线程状态管理、安全中断
 */
public class WorkerThread extends Thread{
    private static final String TAG = LogTAGConstant.WorkerThread;
    private volatile boolean isRunning = false; // 线程运行状态（volatile 保证可见性）
    private final Runnable task; // 线程要执行的核心任务
    private OnThreadStateListener stateListener; // 线程状态回调

    /**
     * 构造器
     * @param task 核心任务（Runnable）
     * @param threadName 线程名称（用于日志区分）
     */
    public WorkerThread(Runnable task, String threadName) {
        super(task, threadName);
        this.task = task;
    }

    /**
     * 启动线程（重写父类 start，增加状态标记）
     */
    @Override
    public void start() {
        if (!isRunning) {
            isRunning = true;
            super.start();
            Log.d(TAG, "线程启动：" + getName());
            if (stateListener != null) {
                stateListener.onThreadStarted(getName());
            }
        } else {
            Log.w(TAG, "线程已在运行：" + getName());
        }
    }

    /**
     * 安全中断线程（避免强制中断导致资源泄漏）
     */
    public void safeInterrupt() {
        if (isRunning) {
            isRunning = false;
            // 确保中断状态被设置
            if (!isInterrupted()) {
                interrupt();
            }
            Log.d(TAG, "触发线程中断：" + getName());
            if (stateListener != null) {
                stateListener.onThreadInterrupting(getName());
            }
        }
    }

    /**
     * 检查线程是否在运行
     */
    public boolean isThreadRunning() {
        return isRunning && isAlive();
    }

    /**
     * 线程执行完毕回调（重写 run 方法，捕获中断异常）
     */
    @Override
    public void run() {
        try {
            if (task != null) {
                task.run(); // 执行核心任务
            }
        } catch (Exception e) {
            Log.e(TAG, "线程执行异常：" + getName(), e);
        } finally {
            isRunning = false;
            Log.d(TAG, "线程终止：" + getName());
            if (stateListener != null) {
                stateListener.onThreadTerminated(getName());
            }
        }
    }

    // ------------------- 状态回调接口 -------------------
    public interface OnThreadStateListener {
        void onThreadStarted(String threadName); // 线程启动
        void onThreadInterrupting(String threadName); // 线程正在中断
        void onThreadTerminated(String threadName); // 线程终止
    }

    // 设置状态监听器
    public void setOnThreadStateListener(OnThreadStateListener listener) {
        this.stateListener = listener;
    }
}
