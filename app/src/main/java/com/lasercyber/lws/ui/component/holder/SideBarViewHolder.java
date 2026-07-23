package com.lasercyber.lws.ui.component.holder;

import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.lasercyber.lws.ui.R;

public class SideBarViewHolder extends RecyclerView.ViewHolder{
    private ImageView iconView;
    private TextView titleView;
    public SideBarViewHolder(@NonNull View itemView) {
        super(itemView);
        iconView= itemView.findViewById(R.id.tab_icon);
        titleView=itemView.findViewById(R.id.tab_title);
    }
    public void updateTitleColor(int textColorId){
        this.titleView.setTextColor(textColorId);
    }
    /**
     * 更新title
     * @param textColorId
     */
    public void updateTitle(int textColorId,int textColor){
        this.titleView.setText(textColorId);
        this.titleView.setTextColor(textColor);

    }

    /**
     * 更新icon
     * @param icon
     */
    public void updateIcon(int icon){
        this.iconView.setImageResource(icon);
    }
}
