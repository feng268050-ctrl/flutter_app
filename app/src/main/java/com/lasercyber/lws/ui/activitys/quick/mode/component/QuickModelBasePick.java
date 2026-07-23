package com.lasercyber.lws.ui.activitys.quick.mode.component;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;
import android.util.Log;
import android.view.LayoutInflater;
import android.widget.LinearLayout;

import androidx.annotation.Nullable;
import androidx.databinding.DataBindingUtil;
import androidx.databinding.ViewDataBinding;

import com.blankj.utilcode.util.GsonUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.quick.mode.listener.CircularPickListener;
import com.lasercyber.lws.ui.bean.ui.DoubleWheelViewItem;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.util.List;

import lombok.Getter;
import lombok.Setter;

public abstract class QuickModelBasePick<T extends ViewDataBinding> extends LinearLayout {
    protected static final String TAG = LogTAGConstant.QuickModelBasePick;
    /**
     * DataBinding 绑定对象
     */
    protected T binding;
    /**
     * 数据列表
     */
    protected List<DoubleWheelViewItem> dataList;
    /**
     * 激活的索引
     */
    @Getter
    protected int activeIndex=-1;
    /**
     * 圆环选择监听
     */
    @Setter
    protected CircularPickListener circularPickListener;

    public QuickModelBasePick(Context context) {
        super(context);
        this.initViewBefore(context);
        this.attrsHandlerBefore(context, null);
    }

    public QuickModelBasePick(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        this.initViewBefore(context);
        this.attrsHandlerBefore(context, attrs);
    }

    public QuickModelBasePick(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        this.initViewBefore(context);
        this.attrsHandlerBefore(context, attrs);
    }

    public QuickModelBasePick(Context context, AttributeSet attrs, int defStyleAttr, int defStyleRes) {
        super(context, attrs, defStyleAttr, defStyleRes);
        this.initViewBefore(context);
        this.attrsHandlerBefore(context, attrs);
    }
    protected abstract int getLayoutId();
    private void initViewBefore(Context context){
        // 核心：通过 DataBindingUtil 绑定布局（无反射，编译期安全）
        binding = DataBindingUtil.inflate(
                LayoutInflater.from(context),        // 布局加载器
                getLayoutId(),   // 子 Fragment 提供的布局 ID
                this,       // 父容器
                true            // 不自动添加到父容器（系统统一管理）
        );
        Log.d(TAG, "正在初始化视图："+getLayoutId());
        this.initView(context);
        this.initSelectBefore(this.activeIndex);
    }
    public void setDataList(List<DoubleWheelViewItem> dataList){
        this.dataList=dataList;
        this.activeIndex=dataList!=null&&!dataList.isEmpty()?1:-1;
        initSelectBefore(this.activeIndex);
        Log.d(TAG, "初始化的数据:"+ GsonUtils.toJson(dataList));
    }

    /**
     * 获取选择的文字
     * @param index
     * @return
     */
    public String getSelectedText(int index){
        index=index-1;
        if (this.dataList==null||this.dataList.isEmpty()){
            return "";
        }
        if (index>=0&&index<this.dataList.size()){
            return this.dataList.get(index).getText();
        }
        return "";
    }

    /**
     * 选择
     * @param index
     */
    public void select(int index){
        initSelectBefore(index);
        if (this.circularPickListener!=null){
            DoubleWheelViewItem doubleWheelViewItem = null;
            if (this.dataList!=null&&(index-1)<this.dataList.size()){
                doubleWheelViewItem= this.dataList.get(index - 1);
            }
            this.circularPickListener.onClickListener(doubleWheelViewItem);
        }
    }
    /**
     * 初始化选择
     * @param index
     */
    public void initSelectBefore(int index) {
        this.activeIndex= index;
        this.initSelect(this.activeIndex);
    }

    public abstract void initView(Context context);

    public abstract void initSelect(int index);
    /**
     * 解析参数
     * @param context
     * @param attrs
     */
    private void attrsHandlerBefore(Context context, @Nullable AttributeSet attrs){
        if (attrs == null) {
            return;
        }
        int[] styleable = R.styleable.QuickModelBasePick;

        if (styleable==null){
            return;
        }
        TypedArray typedArray = context.obtainStyledAttributes(attrs,styleable );
        // 自定义的属性xml
        this.attrsHandler(context,typedArray);
        // 回收typedArray
        typedArray.recycle();
    }
    protected abstract void attrsHandler(Context context, TypedArray typedArray);

    @Override
    protected void onDetachedFromWindow() {
        super.onDetachedFromWindow();
        if (binding!=null){
            binding.unbind();
            binding=null;
        }
    }
}
