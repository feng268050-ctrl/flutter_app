package com.lasercyber.lws.ui.bean.event;

/**
 * Image inference result event for upload/download testing workflow.
 */
public class LensCheckResultImageEvent {
    private final int level;
    private final String status;
    private final String message;
    private final String sourceImagePath;
    private final String resultImagePath;
    private final boolean success;
    private final String errorMessage;

    public LensCheckResultImageEvent(int level,
                                     String status,
                                     String message,
                                     String sourceImagePath,
                                     String resultImagePath,
                                     boolean success,
                                     String errorMessage) {
        this.level = level;
        this.status = status;
        this.message = message;
        this.sourceImagePath = sourceImagePath;
        this.resultImagePath = resultImagePath;
        this.success = success;
        this.errorMessage = errorMessage;
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

    public String getSourceImagePath() {
        return sourceImagePath;
    }

    public String getResultImagePath() {
        return resultImagePath;
    }

    public boolean isSuccess() {
        return success;
    }

    public String getErrorMessage() {
        return errorMessage;
    }
}
