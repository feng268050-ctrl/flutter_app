package com.lasercyber.lws.ui.bean.result;

import java.io.Serializable;

import lombok.Data;

@Data
public class CameraResult implements Serializable {
    /**
     * 状态码
     */
    private int errCode;
    /**
     * 错误信息
     */
    private String errMessage;
}
