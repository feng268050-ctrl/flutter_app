package com.lasercyber.lws.ui.bean.ui;

import lombok.Data;

@Data
public class DataCheckResult {
    /**
     * 校验结果
     */
    private boolean success;
    /**
     * 处理完的数据
     */
    private String data;
    private String errorMsg;
    public static DataCheckResult success(String data) {
        DataCheckResult result = new DataCheckResult();
        result.success = true;
        result.data = data;
        return result;
    }
    public static DataCheckResult fail() {
        DataCheckResult result = new DataCheckResult();
        result.success = false;
        return result;
    }
    public static DataCheckResult fail(String errorMsg) {
        DataCheckResult result = new DataCheckResult();
        result.success = false;
        result.errorMsg = errorMsg;
        return result;
    }
}
