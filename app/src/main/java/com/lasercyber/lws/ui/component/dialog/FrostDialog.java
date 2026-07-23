package com.lasercyber.lws.ui.component.dialog;

import android.app.Activity;
import android.content.Context;
import android.view.View;

import androidx.annotation.DimenRes;
import androidx.annotation.LayoutRes;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.StringRes;

import com.lasercyber.lws.frostui.border.FrostTone;
import com.lasercyber.lws.frostui.dialog.FrostOverlayHost;
import com.lasercyber.lws.frostui.dialog.FrostPromptConfig;
import com.lasercyber.lws.frostui.dialog.FrostPromptDialogController;
import com.lasercyber.lws.frostui.dialog.FrostPromptHandle;
import com.lasercyber.lws.ime.interop.ImeOverlaySpec;
import com.lasercyber.lws.ui.common.boot.BootSelfCheckGate;

import java.util.function.Consumer;

/**
 * Reusable in-window frosted dialog with live backdrop blur.
 * <p>
 * Each {@link Handle} owns its overlay view; overlays stack per Activity (no global singleton slot).
 */
public final class FrostDialog {

    private FrostDialog() {
    }

    public static boolean isShowing() {
        return FrostOverlayHost.hasAnyOverlay();
    }

    public static boolean isShowing(@NonNull Activity activity) {
        return FrostOverlayHost.hasOverlays(activity);
    }

    /** Removes overlays for the given activity (e.g. {@link android.app.Activity#onDestroy()}). */
    public static void onActivityDestroyed(@NonNull Activity activity) {
        FrostOverlayHost.onActivityDestroyed(activity);
    }

    public static void dismiss() {
        FrostOverlayHost.dismiss();
    }

    public static void dismiss(@Nullable Activity activity) {
        FrostOverlayHost.dismiss(activity);
    }

    /** Removes the top overlay immediately without fade-out. */
    public static void dismissImmediate() {
        FrostOverlayHost.dismissImmediate();
    }

    /** Removes the top overlay on {@code activity} immediately without fade-out. */
    public static void dismissImmediate(@Nullable Activity activity) {
        FrostOverlayHost.dismissImmediate(activity);
    }

    public static PromptBuilder prompt(@NonNull Context context) {
        return new PromptBuilder(context);
    }

    public interface Handle {
        void dismiss();

        /** Closes immediately without fade-out; {@link #onDismiss} still runs when configured. */
        void dismissImmediate();

        boolean isShowing();

        @Nullable
        View getRootView();

        @Nullable
        View getTitleSlot();

        @Nullable
        View getBodySlot();

        @Nullable
        View getActionSlot();

        @Nullable
        default View findViewById(int id) {
            View root = getRootView();
            return root != null ? root.findViewById(id) : null;
        }
    }

    public static final class PromptBuilder {
        private final Context context;
        @Nullable
        private CharSequence title;
        @Nullable
        private CharSequence message;
        @Nullable
        private CharSequence confirmText;
        @Nullable
        private CharSequence cancelText;
        @Nullable
        private FrostDialogSlotContent customTitle;
        @Nullable
        private FrostDialogSlotContent customBody;
        @Nullable
        private FrostDialogSlotContent customActionBar;
        private boolean showTitle = true;
        private boolean showActionBar = true;
        private boolean showConfirm = true;
        private boolean showCancel = true;
        private boolean dismissOnScrimClick = true;
        private boolean autoDismissOnConfirm = true;
        @Nullable
        private Runnable onConfirm;
        @Nullable
        private Runnable onCancel;
        @Nullable
        private Runnable onDismiss;
        @Nullable
        private Integer widthPx;
        @Nullable
        private Float widthFraction;
        @Nullable
        private Integer contentInsetPx;
        @Nullable
        private Integer heightPx;
        private int maxHeightPx;
        private boolean expandBodyScroll = true;
        private int minHeightPx;
        private boolean replaceExistingIfOccupied;
        @NonNull
        private FrostTone tone = FrostTone.DARK;
        private boolean deferFrozenBackdropUntilIme;
        private boolean deferFrozenBackdropUntilManualCapture;
        @Nullable
        private ImeOverlaySpec imeOverlay;

        private PromptBuilder(Context context) {
            this.context = context;
        }

        /** {@link FrostTone#DARK} is the default centered card; {@link FrostTone#LIGHT} is the large warm panel. */
        public PromptBuilder tone(@NonNull FrostTone tone) {
            this.tone = tone;
            return this;
        }

        public PromptBuilder title(@Nullable CharSequence title) {
            this.title = title;
            return this;
        }

        public PromptBuilder title(@StringRes int titleRes) {
            return title(context.getString(titleRes));
        }

        public PromptBuilder message(@Nullable CharSequence message) {
            this.message = message;
            return this;
        }

        public PromptBuilder message(@StringRes int messageRes) {
            return message(context.getString(messageRes));
        }

        public PromptBuilder confirmText(@Nullable CharSequence confirmText) {
            this.confirmText = confirmText;
            return this;
        }

        public PromptBuilder confirmText(@StringRes int confirmTextRes) {
            return confirmText(context.getString(confirmTextRes));
        }

        public PromptBuilder cancelText(@Nullable CharSequence cancelText) {
            this.cancelText = cancelText;
            return this;
        }

        public PromptBuilder cancelText(@StringRes int cancelTextRes) {
            return cancelText(context.getString(cancelTextRes));
        }

        public PromptBuilder customTitleView(@NonNull View view) {
            this.customTitle = FrostDialogSlotContent.ofView(view);
            return this;
        }

        public PromptBuilder customTitleView(@LayoutRes int layoutRes, @Nullable Consumer<View> binder) {
            this.customTitle = FrostDialogSlotContent.ofLayout(layoutRes, binder);
            return this;
        }

        public PromptBuilder customBodyView(@NonNull View view) {
            this.customBody = FrostDialogSlotContent.ofView(view);
            return this;
        }

        public PromptBuilder customBodyView(@LayoutRes int layoutRes, @Nullable Consumer<View> binder) {
            this.customBody = FrostDialogSlotContent.ofLayout(layoutRes, binder);
            return this;
        }

        public PromptBuilder customActionBarView(@NonNull View view) {
            this.customActionBar = FrostDialogSlotContent.ofView(view);
            return this;
        }

        public PromptBuilder customActionBarView(@LayoutRes int layoutRes, @Nullable Consumer<View> binder) {
            this.customActionBar = FrostDialogSlotContent.ofLayout(layoutRes, binder);
            return this;
        }

        public PromptBuilder showTitle(boolean showTitle) {
            this.showTitle = showTitle;
            return this;
        }

        public PromptBuilder showActionBar(boolean showActionBar) {
            this.showActionBar = showActionBar;
            return this;
        }

        public PromptBuilder showConfirm(boolean showConfirm) {
            this.showConfirm = showConfirm;
            return this;
        }

        public PromptBuilder showCancel(boolean showCancel) {
            this.showCancel = showCancel;
            return this;
        }

        public PromptBuilder dismissOnScrimClick(boolean dismissOnScrimClick) {
            this.dismissOnScrimClick = dismissOnScrimClick;
            return this;
        }

        /**
         * When false, {@link #onConfirm} must dismiss via its {@link Handle} (validation-gated inputs).
         */
        public PromptBuilder autoDismissOnConfirm(boolean autoDismissOnConfirm) {
            this.autoDismissOnConfirm = autoDismissOnConfirm;
            return this;
        }

        public PromptBuilder onConfirm(@Nullable Runnable onConfirm) {
            this.onConfirm = onConfirm;
            return this;
        }

        public PromptBuilder onCancel(@Nullable Runnable onCancel) {
            this.onCancel = onCancel;
            return this;
        }

        /** Invoked after the overlay is removed from the window (including fade-out completion). */
        public PromptBuilder onDismiss(@Nullable Runnable onDismiss) {
            this.onDismiss = onDismiss;
            return this;
        }

        public PromptBuilder widthPx(int widthPx) {
            this.widthPx = widthPx;
            this.widthFraction = null;
            return this;
        }

        public PromptBuilder widthFraction(float widthFraction) {
            this.widthFraction = widthFraction;
            this.widthPx = null;
            return this;
        }

        public PromptBuilder widthDp(float widthDp) {
            float density = context.getResources().getDisplayMetrics().density;
            return widthPx(Math.round(widthDp * density));
        }

        public PromptBuilder widthDimen(@DimenRes int dimenRes) {
            return widthPx(context.getResources().getDimensionPixelSize(dimenRes));
        }

        public PromptBuilder heightPx(int heightPx) {
            this.heightPx = heightPx;
            return this;
        }

        public PromptBuilder heightDimen(@DimenRes int dimenRes) {
            return heightPx(context.getResources().getDimensionPixelSize(dimenRes));
        }

        /** Caps wrap-content card height without changing default width. */
        public PromptBuilder maxHeightPx(int maxHeightPx) {
            this.maxHeightPx = maxHeightPx;
            return this;
        }

        public PromptBuilder maxHeightDimen(@DimenRes int dimenRes) {
            return maxHeightPx(context.getResources().getDimensionPixelSize(dimenRes));
        }

        /** When false, fixed-height cards keep body wrap_content (compact prompt dialogs). */
        public PromptBuilder expandBodyScroll(boolean expandBodyScroll) {
            this.expandBodyScroll = expandBodyScroll;
            return this;
        }

        public PromptBuilder minHeightPx(int minHeightPx) {
            this.minHeightPx = minHeightPx;
            return this;
        }

        public PromptBuilder minHeightDimen(@DimenRes int dimenRes) {
            return minHeightPx(context.getResources().getDimensionPixelSize(dimenRes));
        }

        /** Equal inset on all four sides; width resolves to screen width minus twice the inset. */
        public PromptBuilder contentInsetPx(int contentInsetPx) {
            this.contentInsetPx = contentInsetPx;
            this.widthPx = null;
            this.widthFraction = null;
            return this;
        }

        public PromptBuilder contentInsetDimen(@DimenRes int dimenRes) {
            return contentInsetPx(context.getResources().getDimensionPixelSize(dimenRes));
        }

        /**
         * Dismiss other overlays on the same activity before showing this one.
         * Skipped while boot self-check is active so the self-check dialog is not replaced.
         */
        public PromptBuilder replaceExistingIfOccupied(boolean replaceExistingIfOccupied) {
            this.replaceExistingIfOccupied = replaceExistingIfOccupied;
            return this;
        }

        /**
         * Defers frozen backdrop capture until the IME is visible and the overlay card has settled.
         * Use for numeric/text/WiFi input prompts that auto-show the keyboard.
         */
        public PromptBuilder deferFrozenBackdropUntilIme(boolean deferFrozenBackdropUntilIme) {
            this.deferFrozenBackdropUntilIme = deferFrozenBackdropUntilIme;
            return this;
        }

        /**
         * Defers frozen backdrop capture until the caller explicitly requests the final frame.
         * Use for dialogs whose bounds change while content is appended, such as boot self-check.
         */
        public PromptBuilder deferFrozenBackdropUntilManualCapture(
                boolean deferFrozenBackdropUntilManualCapture) {
            this.deferFrozenBackdropUntilManualCapture = deferFrozenBackdropUntilManualCapture;
            return this;
        }

        public PromptBuilder imeOverlay(@Nullable ImeOverlaySpec imeOverlay) {
            this.imeOverlay = imeOverlay;
            if (imeOverlay != null) {
                this.deferFrozenBackdropUntilIme = true;
            }
            return this;
        }

        @Nullable
        public Handle show() {
            FrostPromptConfig.Builder builder = new FrostPromptConfig.Builder(context)
                    .tone(tone)
                    .title(title)
                    .message(message)
                    .confirmText(confirmText)
                    .cancelText(cancelText)
                    .customTitle(customTitle != null ? customTitle.toFrostSlot() : null)
                    .customBody(customBody != null ? customBody.toFrostSlot() : null)
                    .customActionBar(customActionBar != null ? customActionBar.toFrostSlot() : null)
                    .showTitle(showTitle)
                    .showActionBar(showActionBar)
                    .showConfirm(showConfirm)
                    .showCancel(showCancel)
                    .dismissOnScrimClick(dismissOnScrimClick)
                    .autoDismissOnConfirm(autoDismissOnConfirm)
                    .onConfirm(onConfirm)
                    .onCancel(onCancel)
                    .onDismiss(onDismiss)
                    .maxHeightPx(maxHeightPx)
                    .expandBodyScroll(expandBodyScroll)
                    .minHeightPx(minHeightPx)
                    .replaceExistingIfOccupied(replaceExistingIfOccupied)
                    .bootSelfCheckActive(BootSelfCheckGate.isActive())
                    .deferFrozenBackdropUntilIme(deferFrozenBackdropUntilIme)
                    .deferFrozenBackdropUntilManualCapture(
                            deferFrozenBackdropUntilManualCapture)
                    .imeOverlay(imeOverlay);
            if (contentInsetPx != null) {
                builder.contentInsetPx(contentInsetPx);
            }
            if (widthPx != null) {
                builder.widthPx(widthPx);
            }
            if (widthFraction != null) {
                builder.widthFraction(widthFraction);
            }
            if (heightPx != null) {
                builder.heightPx(heightPx);
            }
            FrostPromptHandle handle = FrostPromptDialogController.show(builder.build());
            return handle != null ? new FrostPromptHandleAdapter(handle) : null;
        }
    }

    private static final class FrostPromptHandleAdapter implements Handle {
        private final FrostPromptHandle delegate;

        private FrostPromptHandleAdapter(@NonNull FrostPromptHandle delegate) {
            this.delegate = delegate;
        }

        @Override
        public void dismiss() {
            delegate.dismiss();
        }

        @Override
        public void dismissImmediate() {
            delegate.dismissImmediate();
        }

        @Override
        public boolean isShowing() {
            return delegate.isShowing();
        }

        @Override
        public View getRootView() {
            return delegate.getRootView();
        }

        @Override
        public View getTitleSlot() {
            return delegate.getTitleSlot();
        }

        @Override
        public View getBodySlot() {
            return delegate.getBodySlot();
        }

        @Override
        public View getActionSlot() {
            return delegate.getActionSlot();
        }

        @Override
        public View findViewById(int id) {
            return delegate.findViewById(id);
        }
    }
}
