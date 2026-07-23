package com.lasercyber.lws.ui.component.dialog;

import com.lasercyber.lws.frostui.card.FrostCardBlurRegistry;
import com.lasercyber.lws.frostui.common.FrostUiClickSoundRegistry;
import com.lasercyber.lws.frostui.card.interop.FrostCardView;
import com.lasercyber.lws.frostui.dialog.FrostBackdropBlurRegistry;
import com.lasercyber.lws.frostui.dialog.FrostOverlayHost;
import com.lasercyber.lws.frostui.dialog.FrostOverlayHostRegistry;
import com.lasercyber.lws.frostui.dialog.FrostPanelShell;
import com.lasercyber.lws.frostui.border.PanelShellDrawables;
import com.lasercyber.lws.frostui.dialog.FrostPanelShellResources;
import com.lasercyber.lws.ime.ImeRegistry;
import com.lasercyber.lws.ime.interop.ImeKeyboardOverlay;
import com.lasercyber.lws.ui.MainActivity;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.utils.AndroidEmulatorUtils;
import com.lasercyber.lws.ui.common.utils.BlurUtils;
import com.lasercyber.lws.ui.common.utils.SystemSettingUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;

/** Wires ui-layer implementations into frostui dialog registries. */
public final class FrostUiDialogBridge {

    private FrostUiDialogBridge() {
    }

    public static void register() {
        FrostBackdropBlurRegistry.register((context, bitmap, blurRadius, passes) -> {
            if (bitmap == null || bitmap.isRecycled()) {
                return null;
            }
            int radius = Math.min(25, Math.round(blurRadius));
            if (radius <= 0) {
                return bitmap;
            }
            return BlurUtils.blurBitmap(context.getApplicationContext(), bitmap, radius);
        });

        FrostUiClickSoundRegistry.register(GlobalSoundManager::playClickSound);

        FrostPanelShellResources.backdropTintProvider = WorkStatusDialogBackdropDrawable::new;
        FrostPanelShellResources.shellBorderProvider = PanelShellDrawables::workStatusShellBorder;
        FrostPanelShellResources.shellFallbackProvider = PanelShellDrawables::workStatusShellFallback;
        FrostPanelShellResources.shellFrostForegroundProvider = WorkStatusDialogShellFrostDrawable::new;
        FrostPanelShellResources.roundedClipDrawableId = R.drawable.frost_rounded_clip;

        FrostOverlayHostRegistry.panelShellInstaller = (overlay, context) -> {
            FrostPanelShell.install(overlay, context);
            return kotlin.Unit.INSTANCE;
        };
        FrostOverlayHostRegistry.panelShellReleaser = overlay -> {
            FrostPanelShell.release(overlay);
            return kotlin.Unit.INSTANCE;
        };
        FrostOverlayHostRegistry.frozenBackdropApplier = cardView -> {
            if (cardView instanceof FrostCardView frostCard) {
                frostCard.applyFrozenBackdropIfAvailable();
            }
            return kotlin.Unit.INSTANCE;
        };
        FrostOverlayHostRegistry.immersiveSystemUiMaintainer = activity -> {
            AndroidEmulatorUtils.hideStatusBar(activity);
            SystemSettingUtils.hideStatusBar();
            SystemSettingUtils.hideNavigationBar();
            return kotlin.Unit.INSTANCE;
        };

        FrostCardBlurRegistry.getFrozenBackdrop = FrostOverlayHost::getFrozenBackdrop;
        FrostCardBlurRegistry.getPageFrozenBackdrop = FrostOverlayHost::getPageFrozenBackdrop;
        FrostCardBlurRegistry.getFrozenDialogAnchor = FrostOverlayHost::getFrozenDialogAnchor;
        FrostCardBlurRegistry.getFrozenBackdropGeneration = FrostOverlayHost::getFrozenBackdropGeneration;
        FrostCardBlurRegistry.getPageFrozenBackdropGeneration = FrostOverlayHost::getPageFrozenBackdropGeneration;
        FrostCardBlurRegistry.getFrozenBackdropFrameMetadata =
                FrostOverlayHost::getFrozenBackdropFrameMetadata;
        FrostCardBlurRegistry.hasOverlays = FrostOverlayHost::hasOverlays;
        FrostCardBlurRegistry.isFrozenBackdropDeferred = FrostOverlayHost::isFrozenBackdropDeferred;
        FrostCardBlurRegistry.onOverlayAttached = activity -> {
            if (activity instanceof MainActivity) {
                ((MainActivity) activity).freezePageBackdropsDuringOverlay();
            }
            return kotlin.Unit.INSTANCE;
        };
        FrostCardBlurRegistry.onAllOverlaysDismissed = activity -> {
            if (activity instanceof MainActivity) {
                ((MainActivity) activity).unfreezePageBackdropsAfterOverlay();
                ((MainActivity) activity).refreshHomeStatCardBackdrop();
            }
            return kotlin.Unit.INSTANCE;
        };

        ImeRegistry.setLanguageProvider(SystemSettingUtils::getLanguage);
        ImeRegistry.setOnKeyboardShown((activity, keyboardHeightPx) -> {
            android.view.View decor = activity.getWindow() != null
                    ? activity.getWindow().getDecorView()
                    : null;
            if (decor != null) {
                decor.postDelayed(
                        () -> FrostOverlayHost.captureImeBackdropOnce(activity),
                        120L);
                // RK3566 and other embedded targets can miss the first pass while the panel lifts.
                decor.postDelayed(
                        () -> FrostOverlayHost.captureImeBackdropOnce(activity),
                        350L);
            } else {
                FrostOverlayHost.captureImeBackdropOnce(activity);
            }
            return kotlin.Unit.INSTANCE;
        });
        ImeRegistry.setOnAnchorLiftApplied(cardView -> {
            ImeKeyboardOverlay.maintainLayerOrderForDialogCard(cardView);
            return kotlin.Unit.INSTANCE;
        });
        ImeRegistry.setOnCardBackdropRefresh(cardView -> {
            ImeKeyboardOverlay.maintainLayerOrderForDialogCard(cardView);
            return kotlin.Unit.INSTANCE;
        });
    }
}
