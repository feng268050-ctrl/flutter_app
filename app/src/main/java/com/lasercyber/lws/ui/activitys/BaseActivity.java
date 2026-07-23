package com.lasercyber.lws.ui.activitys;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import androidx.appcompat.app.AppCompatActivity;
import androidx.databinding.DataBindingUtil;
import androidx.databinding.ViewDataBinding;

import com.lasercyber.lws.ui.common.utils.AndroidEmulatorUtils;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;

/**
 * 基础的activity
 */
public abstract class BaseActivity<T extends ViewDataBinding> extends AppCompatActivity {
    protected T binding;
    protected Handler handler = new Handler(Looper.getMainLooper());
    /**
     * 任务
     */
    protected Runnable task;
    /**
     * 延迟时长
     */
    protected long delayMillis = 300;
    @Override
    protected void onCreate(Bundle savedInstanceState){
        super.onCreate(savedInstanceState);
        AndroidEmulatorUtils.hideStatusBar(this);
        if(0 == getLayoutId()){
            return;
        }
        int layoutId = getLayoutId();
        binding = DataBindingUtil.setContentView(this, layoutId);
        // 初始化视图
        initView();
        // 初始化数据
        initData();
    }
    @Override
    protected void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        super.onDestroy();
        if (task != null){
            handler.removeCallbacks(task);
            task = null;
        }
        // 销毁 binding，避免内存泄漏
        if (binding != null) {
            binding.unbind();
        }
        binding=null;
        GlobalDialogUtil.onActivityDestroyed(this);
//        WarnDialogUtil.onDestroy();
    }
    /**
     * 初始化视图
     */
    protected abstract void initView();
    /**
     * 初始化数据
     */
    protected abstract void initData();

    /**
     * 子类必须实现：返回当前 Activity 的布局 ID
     */
    protected abstract int getLayoutId();

    @Override
    protected void onResume() {
        super.onResume();
        AndroidEmulatorUtils.hideStatusBar(this);
    }

    @Override
    protected void onStop() {
        super.onStop();
    }


}
