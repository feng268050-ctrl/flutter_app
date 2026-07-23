package com.lasercyber.lws.ui.activitys;

import android.util.Log;

import androidx.lifecycle.MutableLiveData;
import androidx.lifecycle.ViewModel;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import lombok.Getter;


public abstract class BaseViewModel<T> extends ViewModel {
    protected static final String TAG = LogTAGConstant.BaseViewModel;
    /**
     * 监听的数据
     */
    private final MutableLiveData<T> liveData = new MutableLiveData<>();
    @Getter
    private boolean isInit = false;
    protected void startInit(){
        isInit=true;
    }
    /**
     * 初始化完成
     */
    public void endInit(){
        isInit=false;
    }

    /**
     * 添加数据
     * @param data
     */
    public void updateLiveData(T data){
        liveData.setValue(data);
    }

    /**
     * 子线程中更新
     * @param data
     */
    public void postLiveData(T data){
        liveData.postValue(data);
    }
    /**
     * 获取监听的数据
     * @return
     */
    public MutableLiveData<T> getLiveData(){
        return liveData;
    }

    /**
     * 获取原始数据
     * @return
     */
    public T getData(){
        if (liveData.getValue()==null){
            Log.w(TAG, "getData: 获取到的数据为空");
        }
        return liveData.getValue();
    }
}
