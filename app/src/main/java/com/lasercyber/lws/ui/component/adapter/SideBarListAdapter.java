package com.lasercyber.lws.ui.component.adapter;

import android.content.Context;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.ui.SideBarItem;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.component.holder.SideBarViewHolder;
import com.lasercyber.lws.ui.component.listener.SideBarListener;

import java.util.List;

import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.Setter;

/**
 * 侧边栏的适配器
 */
@EqualsAndHashCode(callSuper = true)
@Data
public class SideBarListAdapter extends RecyclerView.Adapter<SideBarViewHolder> {
    private static final String TAG = LogTAGConstant.SideBarListAdapter;
    private Context mContext;

    /**
     * tab列表
     */
    private List<SideBarItem> sideBarItems;
    /**
     * tab变化监听器
     */
    private SideBarListener sideBarListener;
    /**
     * 当前激活的下标
     */
    @Getter
    private int activeIndex=0;

    public SideBarListAdapter(Context mContext, List<SideBarItem> sideBarItems) {
        this.mContext = mContext;
        this.sideBarItems = sideBarItems;
    }

    /**
     * 初始化列表的视图
     * @param parent The ViewGroup into which the new View will be added after it is bound to
     *               an adapter position.
     * @param viewType The view type of the new View.
     *
     * @return
     */
    @NonNull
    @Override
    public SideBarViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(mContext).inflate(R.layout.side_bar_item, parent, false);
        return new SideBarViewHolder(view);
    }


    /**
     * 绑定数据和视图
     * @param holder The ViewHolder which should be updated to represent the contents of the
     *        item at the given position in the data set.
     * @param position The position of the item within the adapter's data set.
     */
    @Override
    public void onBindViewHolder(@NonNull SideBarViewHolder holder, int position) {
        if (sideBarItems ==null){
            return;
        }
        SideBarItem sidebarItem = sideBarItems.get(position);

        int textColor =ContextCompat.getColor(mContext,R.color.side_tab_not_active_color);
        if (position==this.activeIndex){
            textColor= ContextCompat.getColor(mContext, R.color.side_tab_active_color);
        }
        holder.updateTitle(sidebarItem.getTitleTextId(),textColor);
        final int positionTemp=position;
        holder.itemView.setOnClickListener(v -> {
            // 选中当前tab
            var lastSelect=this.activeIndex;
            this.activeIndex=positionTemp;
            if (sideBarListener!=null){
                sideBarListener.onChangSideBar(sidebarItem,positionTemp);
            }
            // 刷新上一次选中项
            notifyItemChanged(lastSelect);
            // 仅刷新当前选中项
            notifyItemChanged(positionTemp);
        });
    }

    @Override
    public int getItemCount() {
        return sideBarItems.size();
    }
    // 更新选中索引，并通知刷新
    public void setActiveIndex(int newIndex) {
        int oldIndex = activeIndex;
        activeIndex = newIndex;
        // 刷新旧选中项和新选中项（避免全量刷新，提升性能）
        if (oldIndex != -1) {
            notifyItemChanged(oldIndex);
        }
        if (newIndex != -1) {
            notifyItemChanged(newIndex);
        }
    }
}
