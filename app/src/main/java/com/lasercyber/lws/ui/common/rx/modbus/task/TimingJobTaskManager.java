package com.lasercyber.lws.ui.common.rx.modbus.task;

import android.util.Log;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

/*定时工作任务管理器*/
public class TimingJobTaskManager {
    private static final String TAG = LogTAGConstant.TimingJobManager;

    /**
     * 任务列表
     */
    private final Map<String, TimingJobTask> timerMap = new HashMap<>();

    private static final class InstanceHolder {
        private static final TimingJobTaskManager instance = new TimingJobTaskManager();
    }

    /**
     * 获取实例
     * @return
     */
    public static TimingJobTaskManager getInstance() {
        return TimingJobTaskManager.InstanceHolder.instance;
    }

    /**
     * 添加任务
     * @param task
     */
    public void addTask( TimingJobTask task) {
        Timer timer = new Timer(task.getTaskId());
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                if(task.isCancelled()||task.isOverMaxErrorCount()){
                    // 暂停任务，获取超过最大次数

                }else {
                    // 执行任务
                    try {
                        task.getTimingJobContent().run();
                        // 执行成功，重置错误次数
                        task.resetErrorCount();
                    }catch (Exception exception){
                        task.incrementErrorCount();
                        Log.d(TAG, "["+task.getTaskId()+"]执行任务异常,连续失败次数:"+task.getErrorCount(),exception);
                    }
                }
            }
        }, task.getDelay(), task.getExecuteInterval());
        timerMap.put(task.getTaskId(), task);
    }

    /**
     * 开始执行
     * @param taskId
     */
    public void startTask(String taskId) {
        TimingJobTask task = timerMap.get(taskId);
        if (task != null) {
            task.startRun();
        }
    }

    /**
     * 停止任务
     * @param taskId
     */
    public void cancelTask(String taskId) {
        TimingJobTask task = timerMap.get(taskId);
        if (task != null) {
            task.cancel();
        }
    }

    /**
     * 批量取消任务
     * @param taskIds
     */
    public void batchCancelTask(List<String> taskIds) {
        if (taskIds == null || taskIds.isEmpty()){
            return;
        }
        Log.d(TAG, "正在批量取消任务");
        taskIds.forEach(this::cancelTask);
    }
    /**
     * 停止所有的任务
     */
    public void stopAllTimerTasks() {
        timerMap.values().forEach(TimingJobTask::cancel);
        timerMap.clear();
    }
}
