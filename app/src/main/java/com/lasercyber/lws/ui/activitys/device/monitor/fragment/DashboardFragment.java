package com.lasercyber.lws.ui.activitys.device.monitor.fragment;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.ItemTouchHelper;
import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseFragment;
import com.lasercyber.lws.ui.activitys.engineer.mode.model.CustomLayoutViewModel;
import com.lasercyber.lws.ui.bean.entity.CustomLayout;
import com.lasercyber.lws.ui.bean.entity.vo.CustomLayoutVoid;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.common.utils.web.HomeLayoutUtils;
import com.lasercyber.lws.ui.component.adapter.CardAdapter;
import com.lasercyber.lws.ui.component.dialog.GlobalDialogUtil;
import com.lasercyber.lws.ui.databinding.FragmentDashboardBinding;

import java.util.ArrayList;
import java.util.List;

/* 1、将排序的结果进行删除+修改，
2、首页跟随变动。
3、进入页面默认渲染*/
public class DashboardFragment extends BaseFragment<FragmentDashboardBinding> {

    private CardAdapter adapter;
    private List<CustomLayoutVoid> initCardData;
    private ItemTouchHelper touchHelper;
    /*model连接类*/
    private CustomLayoutViewModel model;

    public interface CallbackDashboard{
       public void callback(List<CustomLayout> list);
    }

    @Override
    protected int getLayoutId() {
        return  R.layout.fragment_dashboard;
    }

    @Override
    protected void initView() {
    }
    @Override
    protected void initData() {
        //1、获取全部布局内容。
        //@@@@@@尝试通过监听进行直接获取，  如果不行，则通过查询条件，新增一个查询回调进行获取。
        model = new ViewModelProvider(this).get(CustomLayoutViewModel.class);
        model.initGetData( getContext(), new CallbackDashboard() {
            @Override
            public void callback(List<CustomLayout> list) {
                initCardData( list ); // 初始化卡片数据（与截图一致）
                initRecyclerView(); // 初始化网格列表+拖拽排序
                initSaveButton(); // 初始化保存按钮
            }
        });
    }

    // 初始化与截图一致的卡片数据
    private void initCardData( List<CustomLayout> list ) {
        initCardData = new ArrayList<>();

        for ( CustomLayout customLayout : list ) {

            Integer type = customLayout.getType();

            CustomLayoutVoid customLayoutVoid = new CustomLayoutVoid(
                    type,
                    HomeLayoutUtils.typeToTitle( type, getContext() ) );
            initCardData.add(customLayoutVoid);
        }
    }

    // 初始化RecyclerView+拖拽排序
    private void initRecyclerView() {
        RecyclerView recyclerView = binding.recyclerView;
        // 设置4列网格布局
        recyclerView.setLayoutManager(new GridLayoutManager(getContext(), 4));

        // 配置拖拽排序（支持上下/左右拖拽）
        touchHelper = new ItemTouchHelper(new ItemTouchHelper.Callback() {
            @Override
            public int getMovementFlags(@NonNull RecyclerView recyclerView,
                                        @NonNull RecyclerView.ViewHolder viewHolder) {
                int dragFlags = ItemTouchHelper.UP | ItemTouchHelper.DOWN
                        | ItemTouchHelper.LEFT | ItemTouchHelper.RIGHT;
                int swipeFlags = 0;
                return makeMovementFlags(dragFlags, swipeFlags);
            }

            @Override
            public boolean onMove(@NonNull RecyclerView recyclerView,
                                  @NonNull RecyclerView.ViewHolder viewHolder,
                                  @NonNull RecyclerView.ViewHolder target) {
                // 获取原位置和目标位置（Adapter索引）
                int fromPos = viewHolder.getAdapterPosition();
                int toPos = target.getAdapterPosition();

                // 边界校验（避免越界）
                if (fromPos < 0 || toPos < 0 || fromPos >= adapter.getCurrentCardList().size() || toPos >= adapter.getCurrentCardList().size()) {
                    return false;
                }
                // 拖拽过程仅移动列表
                adapter.swapTempItems(fromPos, toPos);
                return true;
            }

            @Override
            public void onSwiped(@NonNull RecyclerView.ViewHolder viewHolder, int direction) {
                // 无需滑动删除，空实现
            }

            @Override// 关闭系统长按拖拽（用“按下即拖拽”）
            public boolean isLongPressDragEnabled() {
                return false;
            }
            @Override
            public boolean isItemViewSwipeEnabled() {
                return false;
            }
            // 开始拖拽：初始化临时列表
            @Override
            public void onSelectedChanged(@Nullable RecyclerView.ViewHolder viewHolder, int actionState) {
                super.onSelectedChanged(viewHolder, actionState);
                GlobalSoundManager.playClickSound();
                if (actionState == ItemTouchHelper.ACTION_STATE_DRAG) {
                    if (viewHolder != null) {
                        adapter.startDragging();
                        ((CardAdapter.CardViewHolder) viewHolder).setDraggingState();
                    }
                } else if (actionState == ItemTouchHelper.ACTION_STATE_IDLE) {
                    adapter.cancelDrag();
                }
            }

            // 松开卡片：确认排序+刷新背景
            @Override
            public void clearView(@NonNull RecyclerView recyclerView, @NonNull RecyclerView.ViewHolder viewHolder) {
                super.clearView(recyclerView, viewHolder);
                ((CardAdapter.CardViewHolder) viewHolder).resetViewState();
                adapter.confirmDrag(); // 确认最终排序
                // 全量刷新，让所有卡片按新位置设置背景
                adapter.notifyItemRangeChanged(0, adapter.getItemCount());
                viewHolder.itemView.setTranslationX(0);
                viewHolder.itemView.setTranslationY(0);
            }
        });
        touchHelper.attachToRecyclerView(recyclerView);

        adapter = new CardAdapter(initCardData,() -> touchHelper);
        recyclerView.setAdapter(adapter);
    }

    // 初始化保存按钮（触发排序结果回传）
    private void initSaveButton() {
        binding.btnSave.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            try {
                btnSaveOper();
                GlobalDialogUtil.showStatusDialog(getContext(), 1, "Save Succeeded", getResources().getString(R.string.complete_operation));
            }catch (Exception e){
                GlobalDialogUtil.showStatusDialog(getContext(), 0, "Save Failed", getResources().getString(R.string.please_wait));
            }
            handler.postDelayed(new Runnable() {
                @Override
                public void run() {
                    GlobalDialogUtil.closeDialog();
                }

            }, 1000);
        });
    }

    private void btnSaveOper(){
        // 将当前排序后的列表回传Activity
        List<CustomLayoutVoid> currentCardList = adapter.getCurrentCardList();
        List<CustomLayout> list = new ArrayList<>();
        //转换类型进行先删除、后添加的操作
        for (int i = 0; i < currentCardList.size(); i++) {
            CustomLayoutVoid vd = currentCardList.get(i);
            CustomLayout customLayout = new CustomLayout();
            customLayout.setType(vd.getType());
            customLayout.setLaoutIndex(i);
            list.add(customLayout);
        }
        model.addCustomLayout(getContext(),list);
    }


}
