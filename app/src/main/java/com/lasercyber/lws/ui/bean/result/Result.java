package com.lasercyber.lws.ui.bean.result;

import com.google.gson.annotations.SerializedName;

import java.io.Serializable;

import lombok.Data;

@Data
public class Result <T> implements Serializable {
    @SerializedName("msg")
    private String msg;

    @SerializedName("code")
    private int code;

    @SerializedName("data")
    private T data;

    public boolean isSuccess() {
        return code == 200;
    }
}
