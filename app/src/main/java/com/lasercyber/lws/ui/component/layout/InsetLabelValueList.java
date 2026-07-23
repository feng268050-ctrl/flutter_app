package com.lasercyber.lws.ui.component.layout;

import android.content.Context;
import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.TextView;

import androidx.annotation.LayoutRes;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.bean.ui.LabelValueListItem;

import java.util.List;

/** Binds read-only label / value / unit rows into an {@link InsetList}. */
public final class InsetLabelValueList {

    private InsetLabelValueList() {
    }

    public static void bind(@NonNull InsetList list, @Nullable List<LabelValueListItem> items) {
        bind(list, items, R.layout.inset_label_value_row);
    }

    public static void bindCompact(@NonNull InsetList list, @Nullable List<LabelValueListItem> items) {
        bind(list, items, R.layout.inset_label_value_row_compact);
    }

    public static void bind(
            @NonNull InsetList list,
            @Nullable List<LabelValueListItem> items,
            @LayoutRes int rowLayoutRes) {
        list.removeAllViews();
        if (items == null || items.isEmpty()) {
            return;
        }
        Context context = list.getContext();
        LayoutInflater inflater = LayoutInflater.from(context);
        for (int i = 0; i < items.size(); i++) {
            if (i > 0) {
                list.addView(new InsetDivider(context));
            }
            LabelValueListItem item = items.get(i);
            View row = inflater.inflate(rowLayoutRes, list, false);
            TextView labelView = row.findViewById(R.id.inset_label_value_label);
            TextView valueView = row.findViewById(R.id.inset_label_value_value);
            TextView unitView = row.findViewById(R.id.inset_label_value_unit);
            labelView.setText(item.getLabel());
            valueView.setText(item.getValue());
            if (TextUtils.isEmpty(item.getUnit())) {
                unitView.setVisibility(View.GONE);
            } else {
                unitView.setVisibility(View.VISIBLE);
                unitView.setText(item.getUnit());
            }
            list.addView(row);
        }
    }
}
