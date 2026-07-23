package com.lasercyber.lws.ui.common.rx.modbus.task;

import com.lasercyber.lws.ui.common.rx.modbus.protocol.TimingJobContent;

import lombok.Data;
import lombok.experimental.Accessors;

/*定时工作任务*/
@Accessors(chain = true)
@Data
public class TimingJobTask {
    /**
     * 任务Id
     */
    private String taskId;
    /**
     * 执行间隔（毫秒)
     */
    private long executeInterval = 60*1000;
    /**
     * 延迟执行时间 （毫秒)
     */
    private int delay = 0;
    /**
     * 是否暂停任务，默认暂停
     */
    private boolean isCancelled = true;

    private boolean upCancelled = false;
    /**
     * 错误次数
     */
    private int errorCount=0;
    /**
     * 最大错误次数
     * -1标识无限制
     */
    private int maxErrorCount=-1;

    private TimingJobContent timingJobContent;

    public void startRun(TimingJobContent content){
        timingJobContent = content;
    }
    /*启用任务*/
    public final void startRun(){
        if(isCancelled){
            isCancelled = false;
            getTimingJobContent().run();
        }
        isCancelled = false;
    }
    /**
     * 暂停任务
     */
    public final void cancel(){
        isCancelled =true;
    }
    /**
     * 累加错误次数
     */
    public void incrementErrorCount(){
        if (maxErrorCount<0){
            return;
        }
        this.errorCount++;
    }
    /**
     * 是否超过最大错误次数
     * @return
     */
    public boolean isOverMaxErrorCount(){
        if (maxErrorCount<0){
            return false;
        }
        return errorCount>=maxErrorCount;
    }
    /**
     * 重置错误次数
     */
    public void resetErrorCount(){
        errorCount=0;
    }
}
