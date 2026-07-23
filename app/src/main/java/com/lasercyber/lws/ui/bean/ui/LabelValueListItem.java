package com.lasercyber.lws.ui.bean.ui;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import lombok.Data;
import lombok.experimental.Accessors;

/** Read-only label / value / optional unit row for {@link com.lasercyber.lws.ui.component.layout.InsetLabelValueList}. */
@Data
@Accessors(chain = true)
public class LabelValueListItem {
    @NonNull
    private String label;
    @NonNull
    private String value;
    @Nullable
    private String unit;

    public LabelValueListItem(@NonNull String label, @NonNull String value) {
        this(label, value, null);
    }

    public LabelValueListItem(@NonNull String label, @NonNull String value, @Nullable String unit) {
        this.label = label;
        this.value = value;
        this.unit = unit;
    }
}
