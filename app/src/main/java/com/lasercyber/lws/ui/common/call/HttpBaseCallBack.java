package com.lasercyber.lws.ui.common.call;

import android.util.Log;
import android.widget.Toast;

import com.lasercyber.lws.ui.bean.result.Result;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;

import lombok.Data;
import lombok.experimental.Accessors;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

/**
 * http请求的回调
 *
 * @param <T>
 */
@Accessors(chain = true)
@Data
public class HttpBaseCallBack<T> implements Callback<Result<T>> {
    private static final String TAG = LogTAGConstant.HttpBaseCallBack;
    private ErrorCallBack<T> errorCallBack;
    private SuccessCallBack<T> successCallBack;

    /**
     * 创建成功的回调处理
     *
     * @param successCallBack
     * @param <T>
     * @return
     */
    public static <T> HttpBaseCallBack<T> createSuccess(SuccessCallBack<T> successCallBack) {
        HttpBaseCallBack<T> httpBaseCallBack = new HttpBaseCallBack<T>();
        httpBaseCallBack.setSuccessCallBack(successCallBack);
        return httpBaseCallBack;
    }

    public static <T> HttpBaseCallBack<T> createBase(SuccessCallBack<T> successCallBack, ErrorCallBack<T> errorCallBack) {
        HttpBaseCallBack<T> httpBaseCallBack = new HttpBaseCallBack<T>();
        httpBaseCallBack.setSuccessCallBack(successCallBack);
        httpBaseCallBack.setErrorCallBack(errorCallBack);
        return httpBaseCallBack;
    }
    @Override
    public void onResponse(Call<Result<T>> call, Response<Result<T>> response) {
        Log.d(TAG, "请求成功:" + response.toString());
        if (successCallBack == null) {
            return;
        }
        if (!response.isSuccessful() && errorCallBack != null) {
            errorCallBack.onError(null, null);
        }
        if (response.isSuccessful()) {
            Result<T> result = response.body();
            if (result != null && result.isSuccess()) {
                successCallBack.onSuccess(result.getData());
            } else if (errorCallBack != null) {
                errorCallBack.onError(result != null ? result.getMsg() : null, null);
            }
        }
    }

    @Override
    public void onFailure(Call<Result<T>> call, Throwable t) {
        Log.e(TAG, "请求失败:", t);
        if (errorCallBack == null) {
            return;
        }
        errorCallBack.onError(null, t);
    }

    /**
     * 失败的回调
     *
     * @param <T>
     */
    public static interface ErrorCallBack<T> {
        void onError(String errorMsg, Throwable t);
    }

    /**
     * 成功的回调
     *
     * @param <T>
     */
    public static interface SuccessCallBack<T> {
        void onSuccess(T data);
    }
}
