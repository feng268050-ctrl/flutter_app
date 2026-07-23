package com.lasercyber.lws.ui.activitys.engineer.mode.component;

import android.content.Context;
import android.view.View;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.bean.ui.DataListPopupItem;
import com.lasercyber.lws.ui.component.InterceptablePopupWindow;
import com.lasercyber.lws.ui.component.popup.FrostPopupMenu;
import com.lasercyber.lws.ui.component.popup.PopupMenuItem;

import java.util.ArrayList;
import java.util.List;

import lombok.Setter;

/**
 * Engineer-mode wrapper around {@link FrostPopupMenu}.
 */
public class DataListPopup {
    private final FrostPopupMenu popup;

    @Setter
    private int xOffset = 0;
    @Setter
    private int yOffset = 0;

    public DataListPopup(Context context) {
        popup = new FrostPopupMenu(context);
    }

    public void setModelType(@Nullable Integer modelType) {
        popup.setModelTypeTheme(modelType);
    }

    public void setMaterialList(
            List<DataListPopupItem> dataList,
            int notSelectedColorId,
            OnItemClickListener listener) {
        List<PopupMenuItem> items = new ArrayList<>(dataList.size());
        for (DataListPopupItem data : dataList) {
            items.add(new PopupMenuItem()
                    .setIconRes(data.getIconRes())
                    .setLabel(data.getName())
                    .setSelected(data.isSelected())
                    .setTag(data));
        }
        popup.setItems(items, notSelectedColorId, (item, position) -> {
            if (listener != null) {
                listener.onItemClick((DataListPopupItem) item.getTag(), position);
            }
        });
    }

    public void show(View anchorView) {
        popup.setXOffset(xOffset);
        popup.setYOffset(yOffset);
        popup.show(anchorView);
    }

    public void dismiss() {
        popup.dismiss();
    }

    public void dismissInterceptListener(InterceptablePopupWindow.OnDismissInterceptListener listener) {
        popup.setDismissInterceptListener(listener);
    }

    public void setContentWidth(int width, int height) {
        popup.setContentSize(width, height);
    }

    public interface OnItemClickListener {
        void onItemClick(DataListPopupItem item, int position);
    }
}
