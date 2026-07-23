package com.lasercyber.lws.frostui.dialog

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.ViewTreeObserver
import android.view.animation.DecelerateInterpolator
import android.widget.ImageView
import kotlin.jvm.JvmStatic
import com.lasercyber.lws.frostui.blur.FrostBackdropCapture
import com.lasercyber.lws.frostui.border.FrostBlurIntensity
import com.lasercyber.lws.frostui.border.FrostResources
import com.lasercyber.lws.frostui.border.FrostTone

/**
 * Light-tone frosted panel shell: activity snapshot, warm gradient tint, and border.
 * Backdrop blur uses live BlurView; RenderScript snapshot fallback when BlurView setup fails.
 */
object FrostPanelShell {

    private class ShellState {
        var backdropSnapshot: Bitmap? = null
    }

    @JvmStatic
    fun install(overlayRoot: View, context: Context) {
        syncBackdropClipToForeground(overlayRoot)
        val backdropTintId = FrostResourceIds.viewId(context, "frost_dialog_backdrop_tint")
        val backdropTint = overlayRoot.findViewById<View>(backdropTintId)
        FrostPanelShellResources.backdropTintProvider?.let { provider ->
            backdropTint?.background = provider(context)
        }
        scheduleCaptureRevealAndFrost(overlayRoot, context, ShellState())
    }

    @JvmStatic
    fun release(overlayRoot: View) {
        val tagId = FrostResourceIds.viewId(overlayRoot.context, "frost_dialog_panel_shell")
        val tag = overlayRoot.getTag(tagId)
        if (tag is ShellState) {
            FrostBackdropSnapshot.recycle(tag.backdropSnapshot)
            tag.backdropSnapshot = null
            overlayRoot.setTag(tagId, null)
        }
    }

    /**
     * Keep the shell backdrop the same size as the foreground so a match_parent backdrop
     * does not expand a wrap_content panel to the full screen height.
     */
    private fun syncBackdropClipToForeground(overlayRoot: View) {
        val context = overlayRoot.context
        val backdropClipId = FrostResourceIds.viewId(context, "frost_dialog_backdrop_clip")
        val foregroundId = FrostResourceIds.viewId(context, "frost_dialog_light_foreground")
        val backdropClip = overlayRoot.findViewById<View>(backdropClipId) ?: return
        val foreground = overlayRoot.findViewById<View>(foregroundId) ?: return
        val sync = Runnable {
            val width = foreground.width
            val height = foreground.height
            if (width <= 0 || height <= 0) {
                return@Runnable
            }
            val layoutParams = backdropClip.layoutParams
            if (layoutParams.width == width && layoutParams.height == height) {
                return@Runnable
            }
            layoutParams.width = width
            layoutParams.height = height
            backdropClip.layoutParams = layoutParams
        }
        foreground.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> sync.run() }
        foreground.post(sync)
    }

    private fun scheduleCaptureRevealAndFrost(
        overlayRoot: View,
        context: Context,
        shell: ShellState,
    ) {
        val blurTargetId = FrostResourceIds.viewId(context, "frost_blur_target")
        val blurTarget = overlayRoot.findViewById<View>(blurTargetId)
        if (blurTarget == null) {
            initShellFrost(overlayRoot, context)
            playRevealFadeIn(overlayRoot, context)
            return
        }
        overlayRoot.alpha = 0f
        blurTarget.viewTreeObserver.addOnPreDrawListener(object : ViewTreeObserver.OnPreDrawListener {
            override fun onPreDraw(): Boolean {
                blurTarget.viewTreeObserver.removeOnPreDrawListener(this)
                attachActivityBackdropSnapshot(overlayRoot, context, shell)
                initShellFrost(overlayRoot, context)
                overlayRoot.post {
                    overlayRoot.post {
                        overlayRoot.post { playRevealFadeIn(overlayRoot, context) }
                    }
                }
                return true
            }
        })
    }

    private fun attachActivityBackdropSnapshot(
        overlayRoot: View,
        context: Context,
        shell: ShellState,
    ) {
        val activity = FrostOverlayHost.findActivity(context) ?: return
        val contentRoot = activity.findViewById<ViewGroup>(android.R.id.content) ?: return
        if (contentRoot.width <= 0 || contentRoot.height <= 0) {
            return
        }
        FrostBackdropSnapshot.recycle(shell.backdropSnapshot)
        shell.backdropSnapshot = FrostBackdropSnapshot.captureAndBlur(
            contentRoot,
            context,
            FrostBlurIntensity.EXTREME,
        )
        val snapshot = shell.backdropSnapshot ?: return
        val snapshotId = FrostResourceIds.viewId(context, "frost_dialog_backdrop_snapshot")
        val snapshotView = overlayRoot.findViewById<ImageView>(snapshotId) ?: return
        snapshotView.setImageBitmap(snapshot)
        snapshotView.visibility = View.VISIBLE
        updateBackdropSnapshotMatrix(overlayRoot, context)
        val tagId = FrostResourceIds.viewId(context, "frost_dialog_panel_shell")
        overlayRoot.setTag(tagId, shell)
    }

    private fun updateBackdropSnapshotMatrix(overlayRoot: View, context: Context) {
        val activity = FrostOverlayHost.findActivity(context) ?: return
        val content = activity.findViewById<View>(android.R.id.content) ?: return
        val backdropClipId = FrostResourceIds.viewId(context, "frost_dialog_backdrop_clip")
        val snapshotId = FrostResourceIds.viewId(context, "frost_dialog_backdrop_snapshot")
        val backdropClip = overlayRoot.findViewById<View>(backdropClipId) ?: return
        val snapshotView = overlayRoot.findViewById<ImageView>(snapshotId) ?: return
        val matrix = Matrix()
        val scaleUp = FrostBackdropCapture.BLUR_SCALE_FACTOR
        matrix.setScale(scaleUp, scaleUp)
        val anchorLocation = IntArray(2)
        val contentLocation = IntArray(2)
        backdropClip.getLocationOnScreen(anchorLocation)
        content.getLocationOnScreen(contentLocation)
        matrix.postTranslate(
            (contentLocation[0] - anchorLocation[0]).toFloat(),
            (contentLocation[1] - anchorLocation[1]).toFloat(),
        )
        snapshotView.imageMatrix = matrix
    }

    private fun initShellFrost(overlayRoot: View, context: Context) {
        val backdropClipId = FrostResourceIds.viewId(context, "frost_dialog_backdrop_clip")
        val backdropClip = overlayRoot.findViewById<View>(backdropClipId)
        if (backdropClip != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            backdropClip.outlineProvider = ViewOutlineProvider.BACKGROUND
            backdropClip.clipToOutline = true
        }
        val panelId = FrostResourceIds.viewId(context, "frost_dialog_panel")
        val panel = overlayRoot.findViewById<View>(panelId)
        if (panel is ViewGroup) {
            panel.clipChildren = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val clipDrawableId = FrostPanelShellResources.roundedClipDrawableId
                if (clipDrawableId != 0) {
                    panel.setBackgroundResource(clipDrawableId)
                }
                applyRoundedClip(panel)
            }
        }
        FrostPanelShellResources.shellBorderProvider?.let { provider ->
            backdropClip?.foreground = provider(context)
        }
        val shellFrostId = FrostResourceIds.viewId(context, "frost_dialog_shell_frost")
        val shellFrost = overlayRoot.findViewById<View>(shellFrostId) ?: return
        applyRoundedClip(shellFrost)
        val snapshotId = FrostResourceIds.viewId(context, "frost_dialog_backdrop_snapshot")
        val snapshotView = overlayRoot.findViewById<ImageView>(snapshotId)
        if (snapshotView != null && snapshotView.visibility == View.VISIBLE) {
            val tone = FrostTone.LIGHT
            val overlayColor = tone.blurIntensity().resolveOverlayColorInt(context, tone.blurTint())
            shellFrost.setBackgroundColor(overlayColor)
            shellFrost.foreground = FrostPanelShellResources.shellFrostForegroundProvider?.invoke(context)
        } else {
            shellFrost.foreground = null
            FrostPanelShellResources.shellFallbackProvider?.let { provider ->
                shellFrost.background = provider(context)
            }
        }
    }

    private fun applyRoundedClip(view: View) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return
        }
        view.outlineProvider = ViewOutlineProvider.BACKGROUND
        view.clipToOutline = true
    }

    private fun playRevealFadeIn(overlayRoot: View, context: Context) {
        overlayRoot.animate().cancel()
        val duration = FrostResources.integer(context, "frost_dialog_fade_in_duration_ms")
        overlayRoot.animate()
            .alpha(1f)
            .setDuration(duration.toLong())
            .setInterpolator(DecelerateInterpolator())
            .start()
    }
}
