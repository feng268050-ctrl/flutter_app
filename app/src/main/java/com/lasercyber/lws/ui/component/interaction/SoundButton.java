package com.lasercyber.lws.ui.component.interaction;

import android.content.Context;
import android.util.AttributeSet;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.widget.AppCompatButton;

/**
 * Standard button that plays the user-selected click effect from settings on tap.
 */
public class SoundButton extends AppCompatButton {

    public SoundButton(@NonNull Context context) {
        super(context);
        init();
    }

    public SoundButton(@NonNull Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public SoundButton(@NonNull Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
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
