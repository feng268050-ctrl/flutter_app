package com.lasercyber.lws.ui.component.adapter;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.entity.WarnTable;
import com.lasercyber.lws.ui.bean.entity.vo.WarnTableVo;
import com.lasercyber.lws.ui.common.enums.AlarmCodeEnums;

import java.util.List;

import cn.hutool.core.util.StrUtil;

public class WarnLogAdapter extends RecyclerView.Adapter<WarnLogAdapter.WarnLogViewHolder> {
    private WarnTableVo warnTable;

    public WarnLogAdapter(WarnTableVo warnTable) {
        this.warnTable = warnTable;
    }
    // 设置初始数据
    public void setWarnLogs(List<WarnTable> logs) {
        warnTable.getListData().clear();
        warnTable.getListData().addAll(logs);
        notifyDataSetChanged();
    }

    // 添加更多数据（用于触底加载）
    public void addMoreLogs(List<WarnTable> newLogs) {
        int startPosition = warnTable.getListData().size();
        warnTable.getListData().addAll(newLogs);
        notifyItemRangeInserted(startPosition, newLogs.size()); // 局部刷新，性能更优
    }

    // 清空数据
    public void clearLogs() {
        warnTable.getListData().clear();
        notifyDataSetChanged();
    }

    @NonNull
    @Override
    public WarnLogViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_warn_log, parent, false);
        return new WarnLogViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull WarnLogViewHolder holder, int position) {
        List<WarnTable> listData = warnTable.getListData();
        WarnTable table = listData.get(position);
        String content = table.getContent();
        if (StrUtil.isBlank(content)) {
            int titleId = AlarmCodeEnums.findTitleId(table.getCode());
            if (titleId <= 0) {
                titleId = R.string.def_warn_text;
            }
            content = holder.itemView.getContext().getString(titleId);
        }
        holder.tvTime.setText(table.getYmdDate() +" "+ table.getHmDate());
        holder.tvCodeDesc.setText(table.getCode() + " " + content);
    }

    @Override
    public int getItemCount() {
        return warnTable.getListData().size();
    }

    static class WarnLogViewHolder extends RecyclerView.ViewHolder {
        TextView tvTime;
        TextView tvCodeDesc;

        public WarnLogViewHolder(@NonNull View itemView) {
            super(itemView);
            tvTime = itemView.findViewById( R.id.tv_time );
            tvCodeDesc = itemView.findViewById( R.id.tv_code_desc );
        }
    }
}
