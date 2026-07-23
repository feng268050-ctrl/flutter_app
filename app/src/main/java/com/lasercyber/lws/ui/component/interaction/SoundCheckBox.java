package com.lasercyber.lws.ui.component.interaction;

import android.content.Context;
import android.util.AttributeSet;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.widget.AppCompatCheckBox;

/**
 * CheckBox that plays the user-selected click effect from settings on user tap.
 */
public class SoundCheckBox extends AppCompatCheckBox {

    public SoundCheckBox(@NonNull Context context) {
        super(context);
        init();
    }

    public SoundCheckBox(@NonNull Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public SoundCheckBox(@NonNull Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        ClickSoundSupport.install(this);
    }

    @Override
    public boolean performClick() {
        ClickSoundSupport.play(this);
        return super.performClick();
    }
}
