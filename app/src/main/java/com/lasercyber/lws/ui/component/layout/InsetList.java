package com.lasercyber.lws.ui.component.layout;

import android.content.Context;
import android.util.AttributeSet;
import android.widget.LinearLayout;

import androidx.annotation.Nullable;

/** Vertical container for {@link InsetListRow} rows and {@link InsetDivider}s. */
public class InsetList extends LinearLayout {
    public InsetList(Context context) {
        this(context, null);
    }

    public InsetList(Context context, @Nullable AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public InsetList(Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        setOrientation(VERTICAL);
    }
}
