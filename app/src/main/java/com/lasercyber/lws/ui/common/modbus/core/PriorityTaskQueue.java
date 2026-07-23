package com.lasercyber.lws.ui.common.modbus.core;

import com.lasercyber.lws.ui.common.modbus.call.TaskQueueStatusCallback;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.PriorityBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.ReentrantLock;

import lombok.Setter;

/**
 *  优先级任务队列（支持插队、批量添加）
 */
public class PriorityTaskQueue {
    private final PriorityBlockingQueue<ModbusTask> queue = new PriorityBlockingQueue<>();
    private final ReentrantLock lock = new ReentrantLock();
    @Setter
    private TaskQueueStatusCallback statusCallback;

    /**
     * 添加单个任务（插队：UI任务自动优先）
     * @param task
     */
    public void addTask(ModbusTask task) {
        lock.lock();
        try {
            queue.add(task);
            notifyQueueSizeChanged();
        } finally {
            lock.unlock();
        }
    }

    /**
     * 批量添加任务
     * @param tasks
     */
    public void addTasks(List<ModbusTask> tasks) {
        lock.lock();
        try {
            queue.addAll(tasks);
            notifyQueueSizeChanged();
        } finally {
            lock.unlock();
        }
    }

    /**
     * 获取下一个任务（超时等待）
     * @param timeoutMs
     * @return
     * @throws InterruptedException
     */
    public ModbusTask take(long timeoutMs) throws InterruptedException {
        lock.lock();
        try {
            Condition notEmpty = lock.newCondition();
            if (queue.isEmpty()) {
                notEmpty.await(timeoutMs, TimeUnit.MILLISECONDS);
            }
            ModbusTask task = queue.poll();
            notifyQueueSizeChanged();
            return task;
        } finally {
            lock.unlock();
        }
    }

    /**
     * 取消任务（根据任务ID）
     * @param taskId
     * @return
     */
    public boolean cancelTask(String taskId) {
        lock.lock();
        try {
            List<ModbusTask> tasks = new ArrayList<>(queue);
            for (ModbusTask task : tasks) {
                if (task.getTaskId().equals(taskId)) {
                    task.cancel();
                    queue.remove(task);
                    notifyQueueSizeChanged();
                    return true;
                }
            }
            return false;
        } finally {
            lock.unlock();
        }
    }

    /**
     * 取消所有未执行任务
     */
    public void cancelAllTasks() {
        lock.lock();
        try {
            queue.forEach(ModbusTask::cancel);
            queue.clear();
            notifyQueueSizeChanged();
        } finally {
            lock.unlock();
        }
    }

    /**
     * 获取队列大小
     * @return
     */
    public int getSize() {
        lock.lock();
        try {
            return queue.size();
        } finally {
            lock.unlock();
        }
    }

    /**
     * 通知队列大小改变
     */
    private void notifyQueueSizeChanged() {
        if (statusCallback != null) {
            statusCallback.onQueueSizeChanged(getSize());
        }
    }

    /**
     * 清空所有的任务
     */
    public void clearAllTask(){
        lock.lock();
        try {
            queue.clear();
        } finally {
            lock.unlock();
        }
    }
}
