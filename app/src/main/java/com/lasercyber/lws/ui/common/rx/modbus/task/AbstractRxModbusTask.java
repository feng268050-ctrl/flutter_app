package com.lasercyber.lws.ui.common.rx.modbus.task;

import lombok.Data;
import lombok.experimental.Accessors;

@Accessors(chain = true)
@Data
public abstract class AbstractRxModbusTask {
    /**
     * 任务Id
     */
    private String taskId;
    /**
     * 执行间隔
     */
    private long executeInterval;
    /**
     * 延迟执行时间
     */
    private int delay=0;
    /**
     * 是否已取消
     */
    private boolean isCancelled =false;
    /**
     * 错误次数
     */
    private int errorCount=0;
    /**
     * 最大错误次数
     * -1标识无限制
     */
    private int maxErrorCount=-1;

    /**
     * 任务
     */
    public abstract void run();
    /**
     * 取消任务
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
