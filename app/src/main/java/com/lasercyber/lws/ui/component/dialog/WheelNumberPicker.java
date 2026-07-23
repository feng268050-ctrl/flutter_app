package com.lasercyber.lws.ui.component.dialog;

import android.content.Context;
import android.util.AttributeSet;
import android.view.View;
import android.widget.EditText;
import android.widget.NumberPicker;

/**
 * {@link NumberPicker} that only shows the wheel-drawn rows.
 * <p>
 * The framework overlays an internal {@code EditText} on the selected row; it uses a separate
 * layout path and misaligns when text size/color are customized. Keeping that overlay hidden
 * makes the selected row use the same canvas drawing as the rows above and below.
 */
public class WheelNumberPicker extends NumberPicker {

    public WheelNumberPicker(Context context) {
        super(context);
    }

    public WheelNumberPicker(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    public WheelNumberPicker(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    public WheelNumberPicker(Context context, AttributeSet attrs, int defStyleAttr, int defStyleRes) {
        super(context, attrs, defStyleAttr, defStyleRes);
    }

    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        super.onLayout(changed, left, top, right, bottom);
        // Never mutate child visibility during layout; defer to the next frame.
        post(this::hideSelectorInput);
    }

    private void hideSelectorInput() {
        for (int i = 0; i < getChildCount(); i++) {
            View child = getChildAt(i);
            if (child instanceof EditText editText) {
                if (editText.getVisibility() != GONE) {
                    editText.setVisibility(GONE);
                }
                editText.setClickable(false);
                editText.setEnabled(false);
                editText.setFocusable(false);
                editText.setFocusableInTouchMode(false);
            }
        }
    }
}
