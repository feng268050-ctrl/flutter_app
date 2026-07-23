package com.lasercyber.lws.ui.component;

import android.content.Context;
import android.content.res.TypedArray;
import android.util.AttributeSet;
import android.util.Log;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.ui.SideBarItem;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.component.adapter.SideBarListAdapter;
import com.lasercyber.lws.ui.component.listener.SideBarListener;

import java.util.List;

/**
 * 侧边栏导航
 */
public class SideBar extends LinearLayout {
    private static final String TAG = LogTAGConstant.SideBar;
    private RecyclerView recyclerView;
    /**
     * 适配器
     */
    private SideBarListAdapter sideBarListAdapter;
    /**
     * 主标题
     */
    private TextView sideMasterTitle;
    /**
     * 返回首页
     */
    private TextView calBackHome;

    public SideBar(Context context) {
        super(context);
        initView(context);
    }

    public SideBar(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        initView(context);
        attrsHandler(context, attrs);
    }

    public SideBar(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        initView(context);
        attrsHandler(context, attrs);
    }

    public SideBar(Context context, AttributeSet attrs, int defStyleAttr, int defStyleRes) {
        super(context, attrs, defStyleAttr, defStyleRes);
        initView(context);
        attrsHandler(context, attrs);
    }

    /**
     * 设置监听器
     *
     * @param sideBarListener
     * @return
     */
    public SideBar setSideBarListener(SideBarListener sideBarListener) {
        if (sideBarListAdapter == null) {
            return this;
        }
        sideBarListAdapter.setSideBarListener(sideBarListener);
        if (calBackHome != null) {
            calBackHome.setOnClickListener(v -> {
                if (sideBarListener != null) {
                    sideBarListener.callBackHome();
                }
            });
        }
        return this;
    }

    public void initView(Context context) {
        // 加载自定义布局
        View view = inflate(context, R.layout.side_bar, this);
        sideMasterTitle = view.findViewById(R.id.side_master_title);
        calBackHome = view.findViewById(R.id.call_back_home);
        recyclerView = view.findViewById(R.id.side_bar_item_list);

    }

    /**
     * 初始化tabBar
     *
     * @param tabBarList
     * @return
     */
    public SideBar initTabBar(List<SideBarItem> tabBarList) {
        sideBarListAdapter = new SideBarListAdapter(getContext(), tabBarList);
        recyclerView.setAdapter(sideBarListAdapter);

        // 设置布局管理器（横向/纵向）
        LinearLayoutManager linearLayoutManager = new LinearLayoutManager(getContext());
        linearLayoutManager.setOrientation(LinearLayoutManager.VERTICAL);
        recyclerView.setLayoutManager(linearLayoutManager);
        return this;
    }

    /**
     * 参数解析
     *
     * @param context
     * @param attrs
     */
    private void attrsHandler(Context context, @Nullable AttributeSet attrs) {

        TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.SideBar);
        // 自定义的属性xml
        int masterTitle = typedArray.getResourceId(R.styleable.SideBar_side_bar_master_title, R.string.empty_text);
        sideMasterTitle.setText(masterTitle);
        // 使用返回到首页
        boolean useCallBackHome = typedArray.getBoolean(R.styleable.SideBar_use_call_back_home, false);
        if (useCallBackHome) {
            calBackHome.setVisibility(View.VISIBLE);
        } else {
            calBackHome.setVisibility(View.GONE);
        }
        // 回收typedArray
        typedArray.recycle();
    }

    /**
     * 更新选择
     * @param position
     */
    public void updateChange(int position){
        if (position < 0 || position >= sideBarListAdapter.getItemCount()) return;
        
        RecyclerView.LayoutManager layoutManager = recyclerView.getLayoutManager();
        if (layoutManager==null){
            Log.e(TAG, "updateChange: 未找到RecyclerView的视图管理器:"+position);
            return;
        }
        if (position==sideBarListAdapter.getActiveIndex()){
            Log.d(TAG, "updateChange: 当前已经激活了该页面:当前需要跳转的页面:"+ position+"，上一个页面："+sideBarListAdapter.getActiveIndex());
            return;
        }
        // 同步更新适配器的选中索引
        /*sideBarListAdapter.setActiveIndex( position);
        View lastView = layoutManager.findViewByPosition(sideBarListAdapter.getActiveIndex());
        if(lastView!=null){
            lastView.setSelected(false);
        }
        // 选择当前
        View nowView = layoutManager.findViewByPosition(position);
        if(nowView!=null){
            nowView.setSelected(true);
        }*/
    }
}
