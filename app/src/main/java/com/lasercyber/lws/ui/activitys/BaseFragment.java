package com.lasercyber.lws.ui.activitys;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.LayoutRes;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.databinding.DataBindingUtil;
import androidx.databinding.ViewDataBinding;
import androidx.fragment.app.Fragment;

/**
 * 基础的Fragment
 * @param <T> DataBinding 绑定对象
 */
public abstract class BaseFragment<T extends ViewDataBinding> extends Fragment {
    /**
     * DataBinding 绑定对象
     */
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

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        // 核心：通过 DataBindingUtil 绑定布局（无反射，编译期安全）
        binding = DataBindingUtil.inflate(
                inflater,        // 布局加载器
                getLayoutId(),   // 子 Fragment 提供的布局 ID
                container,       // 父容器
                false            // 不自动添加到父容器（系统统一管理）
        );
        return binding.getRoot(); // 返回 DataBinding 根视图
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        // 绑定生命周期所有者（关键：让 DataBinding 自动响应数据变化）
        binding.setLifecycleOwner(getViewLifecycleOwner());
        // 绑定数据模型（如 ViewModel，子 Fragment 实现）
        bindViewModel();
        // 初始化视图（子 Fragment 实现）
        initView();
        // 初始化视图之后
        initViewAfter();
        // 初始化数据
        initData();
    }

    /**
     * 视图的布局Id
     *
     * @return
     */
    @LayoutRes
    protected abstract int getLayoutId();
    /**
     * 初始化视图之后
     */
    public void initViewAfter(){

    }

    /**
     * 子 Fragment 必须实现：初始化视图（设置点击事件、控件状态等）
     */
    protected abstract void initView();

    /**
     * 子 Fragment 必须实现：初始化数据（请求接口、加载本地数据等）
     */
    protected abstract void initData();

    /**
     * 子 Fragment 可选实现：绑定 ViewModel（DataBinding 核心）
     * 示例：binding.setViewModel(mViewModel);
     */
    protected void bindViewModel() {
    }
    @Override
    public void onDestroyView() {
        handler.removeCallbacksAndMessages(null);
        super.onDestroyView();
        if (task!=null){
            handler.removeCallbacks(task);
            task = null;
        }
        if (binding!=null){
            binding.unbind();
            binding = null;
        }
    }

    /**
     * 获取FragmentId
     *
     * @return
     */
    public long fragmentId() {
        return -1;
    }
}
