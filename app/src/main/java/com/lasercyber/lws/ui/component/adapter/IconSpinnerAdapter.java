package com.lasercyber.lws.ui.component.adapter;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.util.TypedValue;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import com.blankj.utilcode.util.StringUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.ui.SpinnerTextIcon;

import java.util.List;

import lombok.Data;
import lombok.Setter;
import lombok.experimental.Accessors;

/**
 * 包含图标的下拉选择适配器
 */
@Accessors(chain = true)
public class IconSpinnerAdapter extends ArrayAdapter<SpinnerTextIcon> {
    private Context context;
    private List<SpinnerTextIcon> iconList;
    private LayoutInflater mInflater;
    // 选中的内边距
    @Setter
    private int[] selectedPadding;
    // 选中的索引
    private int selectIndex;

    public IconSpinnerAdapter(@NonNull Context context, List<SpinnerTextIcon> spinnerTextIcons) {
        super(context, 0, spinnerTextIcons);
        this.context = context;
        this.iconList = spinnerTextIcons;
        mInflater = LayoutInflater.from(context);
    }

    /**
     * 下拉选中的内容
     *
     * @param position    index of the item whose view we want.
     * @param convertView the old view to reuse, if possible. Note: You should
     *                    check that this view is non-null and of an appropriate type before
     *                    using. If it is not possible to convert this view to display the
     *                    correct data, this method can create a new view.
     * @param parent      the parent that this view will eventually be attached to
     * @return
     */
    @Override
    public View getDropDownView(int position, @Nullable View convertView, @NonNull ViewGroup parent) {
        ViewHolder holder;
        if (convertView == null) {
            convertView = mInflater.inflate(R.layout.icon_spinner_dropdown, parent, false);
            holder = new ViewHolder();
            holder.iconView = convertView.findViewById(R.id.iv_item_icon);
            holder.textView = convertView.findViewById(R.id.tv_item_text);
            convertView.setTag(holder);
        } else {
            holder = (ViewHolder) convertView.getTag();
        }

        // 绑定数据
        SpinnerTextIcon item = iconList.get(position);
        holder.iconView.setImageResource(item.getIconId()); // 设置图标
        if (StringUtils.isEmpty(item.getText())) {
            holder.textView.setText(item.getTextId());                // 设置文字
        } else {
            holder.textView.setText(item.getText());
        }
        // 选中的文字样式
        int textColor = ContextCompat.getColor(context, R.color.white);
        // 选中的背景颜色
        int backgroundColor = Color.TRANSPARENT;
        if (this.selectIndex == position) {
            textColor = ContextCompat.getColor(context, R.color.spinner_selected_text_color);
            backgroundColor = ContextCompat.getColor(context, R.color.spinner_selected_bg_color);
        }
        holder.textView.setTextColor(textColor);
        View row = convertView.findViewById(R.id.item_spinner_dropdown);
        float[] radii=new float[]{0,0,0,0,0,0,0,0};
        if(position==0){
            float cornerRadius = TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP,
                    10,
                    row.getResources().getDisplayMetrics()
            );
            radii[0]=cornerRadius;
            radii[1]=cornerRadius;
            radii[2]=cornerRadius;
            radii[3]=cornerRadius;
        }else if(position==iconList.size()-1){
            float cornerRadius = TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP,
                    10,
                    row.getResources().getDisplayMetrics()
            );
            radii[4]=cornerRadius;
            radii[5]=cornerRadius;
            radii[6]=cornerRadius;
            radii[7]=cornerRadius;
        }
        setTopCorners(row,backgroundColor,radii);
        return convertView;
    }
    /**
     * 给 View 设置左上角和右上角 10dp 的圆角（纯色背景）
     * @param view 目标 View
     * @param bgColor 背景颜色（如 Color.WHITE）
     */
    public void setTopCorners(View view, int bgColor,float[] radii) {
        // 1. 将 dp 转换为像素（适配不同屏幕密度）
//        float cornerRadius = TypedValue.applyDimension(
//                TypedValue.COMPLEX_UNIT_DIP,
//                10,
//                view.getResources().getDisplayMetrics()
//        );

        // 2. 创建 GradientDrawable（用于绘制纯色背景和圆角）
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(bgColor); // 设置背景颜色

        // 3. 设置圆角：参数顺序为 [左上角, 右上角, 右下角, 左下角]
        drawable.setCornerRadii(radii);

        // 4. 设置为 View 的背景
        view.setBackground(drawable);
    }
    @NonNull
    @Override
    public View getView(int position, @Nullable View convertView, @NonNull ViewGroup parent) {
        // 选中项使用单独的布局
        ViewHolderSelected holder;
        if (convertView == null || !(convertView.getTag() instanceof ViewHolderSelected)) {
            convertView = mInflater.inflate(R.layout.icon_spinner_selected, parent, false);
            if (selectedPadding != null && selectedPadding.length == 4) {
                convertView.setPadding(selectedPadding[0], selectedPadding[1], selectedPadding[2], selectedPadding[3]);
            }

            holder = new ViewHolderSelected();
            holder.iconView = convertView.findViewById(R.id.iv_selected_icon);
            holder.textView = convertView.findViewById(R.id.tv_selected_text);
            convertView.setTag(holder);
        } else {
            holder = (ViewHolderSelected) convertView.getTag();
        }
        // 绑定数据
        SpinnerTextIcon item = iconList.get(position);
        holder.iconView.setImageResource(item.getIconId());
        if (StringUtils.isEmpty(item.getText())) {
            holder.textView.setText(item.getTextId());                // 设置文字
        } else {
            holder.textView.setText(item.getText());
        }

        return convertView;
    }

    /**
     * 更新选中的索引
     *
     * @param selectIndex
     * @return
     */
    public IconSpinnerAdapter setSelectIndex(int selectIndex) {
        this.selectIndex = selectIndex;
        notifyDataSetChanged();
        return this;
    }

    static class ViewHolder {
        ImageView iconView; // 新增图标视图
        TextView textView;
    }

    // 选中项的 ViewHolder
    static class ViewHolderSelected {
        ImageView iconView;
        TextView textView;
    }
}
