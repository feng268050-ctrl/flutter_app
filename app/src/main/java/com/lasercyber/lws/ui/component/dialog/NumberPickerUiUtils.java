package com.lasercyber.lws.ui.component.dialog;

import android.content.Context;
import android.util.TypedValue;
import android.widget.NumberPicker;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import com.lasercyber.lws.ui.R;

/** Text styling for {@link WheelNumberPicker} inside {@link FrostDialog} bodies. */
public final class NumberPickerUiUtils {

    private NumberPickerUiUtils() {
    }

    public static void applyFrostPickerStyle(@NonNull Context context, @NonNull NumberPicker picker, boolean wrap) {
        picker.setWrapSelectorWheel(wrap);
        picker.setDescendantFocusability(NumberPicker.FOCUS_BLOCK_DESCENDANTS);
        picker.setTextSize(TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_SP, 22, context.getResources().getDisplayMetrics()));
        picker.setTextColor(ContextCompat.getColor(context, R.color.frost_text_primary));
        int value = picker.getValue();
        picker.setValue(value);
        picker.invalidate();
    }
}
