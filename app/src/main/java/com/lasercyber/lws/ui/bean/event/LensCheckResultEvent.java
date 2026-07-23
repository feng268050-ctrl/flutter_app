package com.lasercyber.lws.ui.bean.event;

/**
 * 镜片污点检测结果事件
 * level: 0=洁净, 1=轻度污染, 2=重度污染
 * status: "CLEAN", "STAIN_MILD", "STAIN_HEAVY"
 * message: 人类可读的中文描述
 */
public class LensCheckResultEvent {
    private final int level;
    private final String status;
    private final String message;

    public LensCheckResultEvent(int level, String status, String message) {
        this.level = level;
        this.status = status;
        this.message = message;
    }

    public int getLevel() {
        return level;
    }

    public String getStatus() {
        return status;
    }

    public String getMessage() {
        return message;
    }
}
