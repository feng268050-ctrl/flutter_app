package com.lasercyber.lws.ui.common.rx.modbus.task;

import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

/**
 * 任务管理器
 */
public class RxTaskManager {
    private static final String TAG = LogTAGConstant.RxTaskManager;

    private static final class ScheduledEntry {
        private final AbstractRxModbusTask task;
        private final Timer timer;
        private final TimerTask timerTask;

        private ScheduledEntry(AbstractRxModbusTask task, Timer timer, TimerTask timerTask) {
            this.task = task;
            this.timer = timer;
            this.timerTask = timerTask;
        }
    }

    private final Map<String, ScheduledEntry> scheduledTasks = new HashMap<>();

    private static final class InstanceHolder {
        private static final RxTaskManager instance = new RxTaskManager();
    }

    public static RxTaskManager getInstance() {
        return InstanceHolder.instance;
    }

    public void addTask(AbstractRxModbusTask task) {
        cancelTask(task.getTaskId());
        Timer timer = new Timer("Rx-modbus-task-" + task.getTaskId(), true);
        TimerTask timerTask = new TimerTask() {
            @Override
            public void run() {
                if (task.isCancelled() || task.isOverMaxErrorCount()) {
                    cancel();
                    cancelTask(task.getTaskId());
                    if (task.isOverMaxErrorCount()) {
                        Log.e(TAG, "[" + task.getTaskId() + "]任务连续失败：["
                                + task.getErrorCount() + "]次，任务已取消");
                    }
                    return;
                }
                try {
                    task.run();
                    task.resetErrorCount();
                } catch (Exception exception) {
                    task.incrementErrorCount();
                    Log.d(TAG, "[" + task.getTaskId() + "]执行任务异常,连续失败次数:"
                            + task.getErrorCount(), exception);
                }
            }
        };
        timer.schedule(timerTask, task.getDelay(), task.getExecuteInterval());
        scheduledTasks.put(task.getTaskId(), new ScheduledEntry(task, timer, timerTask));
    }

    public void cancelTask(String taskId) {
        ScheduledEntry entry = scheduledTasks.remove(taskId);
        if (entry == null) {
            return;
        }
        entry.task.cancel();
        entry.timerTask.cancel();
        entry.timer.cancel();
        entry.timer.purge();
    }

    public void batchCancelTask(List<String> taskIds) {
        if (taskIds == null || taskIds.isEmpty()) {
            return;
        }
        Log.d(TAG, "正在批量取消任务");
        taskIds.forEach(this::cancelTask);
        taskIds.clear();
    }

    public void stopAllTimerTasks() {
        for (String taskId : new ArrayList<>(scheduledTasks.keySet())) {
            cancelTask(taskId);
        }
    }
}
