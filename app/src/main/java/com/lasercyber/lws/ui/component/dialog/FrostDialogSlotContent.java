package com.lasercyber.lws.ui.component.dialog;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import androidx.annotation.LayoutRes;
import androidx.annotation.Nullable;

import java.util.function.Consumer;

final class FrostDialogSlotContent {

    @Nullable
    private final View view;
    @LayoutRes
    private final int layoutRes;
    @Nullable
    private final Consumer<View> binder;

    private FrostDialogSlotContent(
            @Nullable View view,
            @LayoutRes int layoutRes,
            @Nullable Consumer<View> binder) {
        this.view = view;
        this.layoutRes = layoutRes;
        this.binder = binder;
    }

    static FrostDialogSlotContent ofView(@Nullable View view) {
        return new FrostDialogSlotContent(view, 0, null);
    }

    static FrostDialogSlotContent ofLayout(@LayoutRes int layoutRes, @Nullable Consumer<View> binder) {
        return new FrostDialogSlotContent(null, layoutRes, binder);
    }

    @Nullable
    com.lasercyber.lws.frostui.dialog.FrostPromptSlotContent toFrostSlot() {
        if (!hasCustomContent()) {
            return null;
        }
        if (view != null) {
            return com.lasercyber.lws.frostui.dialog.FrostPromptSlotContent.ofView(view);
        }
        return com.lasercyber.lws.frostui.dialog.FrostPromptSlotContent.ofLayout(layoutRes, binder);
    }

    boolean hasCustomContent() {
        return view != null || layoutRes != 0;
    }

    @Nullable
    View install(Context context, View overlay, int slotId) {
        if (!hasCustomContent()) {
            return null;
        }
        FrameLayout slot = overlay.findViewById(slotId);
        if (slot == null) {
            return null;
        }
        slot.removeAllViews();
        View content = view;
        if (content == null) {
            content = LayoutInflater.from(context).inflate(layoutRes, slot, false);
        }
        ViewGroup.LayoutParams layoutParams = content.getLayoutParams();
        if (layoutParams instanceof FrameLayout.LayoutParams frameParams) {
            frameParams.width = ViewGroup.LayoutParams.MATCH_PARENT;
            frameParams.gravity = android.view.Gravity.CENTER_HORIZONTAL;
            content.setLayoutParams(frameParams);
        } else {
            layoutParams = new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    android.view.Gravity.CENTER_HORIZONTAL);
            content.setLayoutParams(layoutParams);
        }
        slot.addView(content);
        if (binder != null) {
            binder.accept(content);
        }
        return content;
    }
}
