package com.lasercyber.lws.ui.component.dialog;

import android.app.Activity;
import android.content.Context;
import android.content.res.Resources;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.text.TextPaint;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.DimenRes;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.StringRes;

import com.lasercyber.lws.frostui.border.FrostTone;
import com.lasercyber.lws.frostui.dialog.FrostOverlayHost;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.frostui.button.interop.FrostButtonView;
import com.lasercyber.lws.frostui.control.interop.FrostCheckboxView;

import java.util.function.Consumer;

/**
 * Shared LIGHT prompt shell: icon + title + body, confirm pinned at bottom.
 * Card height follows content ({@code wrap_content}) with min/max bounds; body scrolls when text exceeds scroll max height.
 * Optional "don't show again" checkbox in the action bar (engineer-mode entry tips).
 */
public final class FrostPromptDialog {

    public static final float TITLE_TEXT_SIZE_SP = 48f;
    private static final float MAX_WIDTH_FRACTION = 0.95f;

    private FrostPromptDialog() {
    }

    public static Builder builder(@NonNull Context context) {
        return new Builder(context);
    }

    public static int standardWidthPx(@NonNull Context context) {
        return context.getResources().getDimensionPixelSize(R.dimen.engineer_mode_entry_dialog_width);
    }

    /** Maximum prompt height ({@link R.dimen#frost_dialog_prompt_max_height}). */
    public static int standardHeightPx(@NonNull Context context) {
        return context.getResources().getDimensionPixelSize(R.dimen.frost_dialog_prompt_max_height);
    }

    /** Single-line title width + horizontal content inset; at least {@link #standardWidthPx}. */
    public static int resolveTitleBasedWidthPx(@NonNull Context context, @NonNull CharSequence title) {
        Resources resources = context.getResources();
        int minWidth = standardWidthPx(context);
        int maxWidth = Math.max(minWidth, Math.round(
                resources.getDisplayMetrics().widthPixels * MAX_WIDTH_FRACTION));
        int horizontalInset = resources.getDimensionPixelSize(R.dimen.frost_dialog_prompt_content_inset) * 2;
        TextPaint paint = createTitlePaint(resources);
        int titleWidth = (int) Math.ceil(paint.measureText(title, 0, title.length())) + horizontalInset;
        return Math.min(maxWidth, Math.max(minWidth, titleWidth));
    }

    @NonNull
    private static TextPaint createTitlePaint(@NonNull Resources resources) {
        TextPaint paint = new TextPaint(Paint.ANTI_ALIAS_FLAG);
        paint.setTextSize(resources.getDimension(R.dimen.frost_dialog_prompt_title_text_size));
        paint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        return paint;
    }

    public static void clearActionSectionTopMargin(@NonNull View actionRoot) {
        View actionSection = actionRoot.getRootView().findViewById(R.id.frost_dialog_action_section);
        if (actionSection == null
                || !(actionSection.getLayoutParams() instanceof ViewGroup.MarginLayoutParams params)) {
            return;
        }
        params.topMargin = 0;
        actionSection.setLayoutParams(params);
    }

    /** Icon top uses content inset; bottom uses {@link #applyPromptShellInsets} rules. */
    static void applyPromptShellInsets(@NonNull View anchor, boolean withDontShowAgain) {
        View foreground = anchor.getRootView().findViewById(R.id.frost_dialog_light_foreground);
        if (foreground == null) {
            return;
        }
        Resources resources = anchor.getResources();
        int horizontalInset = resources.getDimensionPixelSize(R.dimen.frost_dialog_prompt_content_inset);
        int bottomInset = withDontShowAgain
                ? resources.getDimensionPixelSize(R.dimen.frost_dialog_prompt_dont_show_again_inset)
                : horizontalInset;
        foreground.setPaddingRelative(
                foreground.getPaddingStart(),
                horizontalInset,
                foreground.getPaddingEnd(),
                bottomInset);
    }

    public static final class Builder {
        private final Context context;
        @Nullable
        private Integer widthPx;
        @Nullable
        private Integer widthDimenRes;
        @Nullable
        private CharSequence confirmText;
        @Nullable
        private Consumer<View> bodyBinder;
        @Nullable
        private Runnable onConfirm;
        @Nullable
        private Runnable onCancel;
        @Nullable
        private Runnable onDismiss;
        @Nullable
        private java.util.function.Consumer<Boolean> onDontShowAgainConfirm;
        private boolean dismissOnScrimClick = true;
        private boolean replaceExistingIfOccupied;
        private boolean showDontShowAgain;
        private boolean dontShowAgainChecked = true;

        private Builder(@NonNull Context context) {
            this.context = context;
        }

        public Builder widthPx(int widthPx) {
            this.widthPx = widthPx;
            this.widthDimenRes = null;
            return this;
        }

        public Builder widthDimen(@DimenRes int dimenRes) {
            this.widthDimenRes = dimenRes;
            this.widthPx = null;
            return this;
        }

        public Builder confirmText(@NonNull CharSequence confirmText) {
            this.confirmText = confirmText;
            return this;
        }

        public Builder confirmText(@StringRes int confirmTextRes) {
            return confirmText(context.getString(confirmTextRes));
        }

        public Builder body(@NonNull Consumer<View> bodyBinder) {
            this.bodyBinder = bodyBinder;
            return this;
        }

        public Builder onConfirm(@Nullable Runnable onConfirm) {
            this.onConfirm = onConfirm;
            return this;
        }

        public Builder onCancel(@Nullable Runnable onCancel) {
            this.onCancel = onCancel;
            return this;
        }

        public Builder onDismiss(@Nullable Runnable onDismiss) {
            this.onDismiss = onDismiss;
            return this;
        }

        public Builder dismissOnScrimClick(boolean dismissOnScrimClick) {
            this.dismissOnScrimClick = dismissOnScrimClick;
            return this;
        }

        public Builder replaceExistingIfOccupied(boolean replaceExistingIfOccupied) {
            this.replaceExistingIfOccupied = replaceExistingIfOccupied;
            return this;
        }

        public Builder showDontShowAgain(boolean show) {
            this.showDontShowAgain = show;
            return this;
        }

        public Builder dontShowAgainCheckedByDefault(boolean checked) {
            this.dontShowAgainChecked = checked;
            return this;
        }

        /** Invoked on confirm when {@link #showDontShowAgain(boolean)} is enabled. */
        public Builder onDontShowAgainConfirm(@NonNull java.util.function.Consumer<Boolean> listener) {
            this.onDontShowAgainConfirm = listener;
            return this;
        }

        @Nullable
        public FrostDialog.Handle show() {
            Activity activity = resolveActivity(context);
            if (activity == null) {
                return null;
            }

            FrostDialog.PromptBuilder dialog = FrostDialog.prompt(activity)
                    .tone(FrostTone.LIGHT)
                    .minHeightDimen(R.dimen.frost_dialog_prompt_min_height)
                    .expandBodyScroll(false)
                    .showTitle(false)
                    .showActionBar(true)
                    .autoDismissOnConfirm(false)
                    .dismissOnScrimClick(dismissOnScrimClick)
                    .replaceExistingIfOccupied(replaceExistingIfOccupied)
                    .customBodyView(R.layout.dialog_frost_body_prompt, body -> {
                        if (bodyBinder != null) {
                            bodyBinder.accept(body);
                        }
                    })
                    .customActionBarView(R.layout.dialog_frost_action_prompt, this::bindAction)
                    .onCancel(onCancel)
                    .onDismiss(onDismiss);

            if (widthPx != null) {
                dialog.widthPx(widthPx);
            } else if (widthDimenRes != null) {
                dialog.widthDimen(widthDimenRes);
            } else {
                dialog.widthDimen(R.dimen.engineer_mode_entry_dialog_width);
            }

            return dialog.show();
        }

        private void bindAction(@NonNull View action) {
            applyPromptShellInsets(action, showDontShowAgain);
            clearActionSectionTopMargin(action);

            FrostCheckboxView dontRemind = action.findViewById(R.id.cb_dont_remind);
            if (dontRemind != null) {
                dontRemind.setVisibility(showDontShowAgain ? View.VISIBLE : View.GONE);
                if (showDontShowAgain) {
                    dontRemind.setChecked(dontShowAgainChecked);
                }
            }

            FrostButtonView confirm = action.findViewById(R.id.btn_confirm);
            if (confirm == null) {
                return;
            }
            if (confirmText != null) {
                confirm.setText(confirmText);
            }
            confirm.setOnClickListener(v -> {
                if (showDontShowAgain && dontRemind != null && onDontShowAgainConfirm != null) {
                    onDontShowAgainConfirm.accept(dontRemind.isChecked());
                }
                if (onConfirm != null) {
                    onConfirm.run();
                }
            });
        }
    }

    /** Binds engineer-mode entry tips content on {@link R.layout#dialog_frost_body_prompt}. */
    public static void bindEngineerModeEntryBody(@NonNull View body) {
        View icon = body.findViewById(R.id.prompt_icon);
        if (icon instanceof android.widget.ImageView imageView) {
            imageView.setImageResource(R.mipmap.home_to_page_right_img_);
        }

        TextView title = body.findViewById(R.id.prompt_title);
        title.setText(R.string.dialog_main_title);
        title.setTextColor(body.getContext().getColor(R.color.reminder_confirm_button));

        TextView content = body.findViewById(R.id.prompt_content);
        content.setText(R.string.dialog_main_info);
    }

    @Nullable
    private static Activity resolveActivity(@NonNull Context context) {
        if (context instanceof Activity activity) {
            if (activity.isFinishing() || activity.isDestroyed()) {
                return null;
            }
            return activity;
        }
        Activity top = FrostOverlayHost.findActivity(context);
        if (top == null || top.isFinishing() || top.isDestroyed()) {
            return null;
        }
        return top;
    }
}
