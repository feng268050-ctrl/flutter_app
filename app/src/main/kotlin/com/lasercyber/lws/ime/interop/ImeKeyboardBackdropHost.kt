package com.lasercyber.lws.ime.interop

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PorterDuff
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import com.lasercyber.lws.frostui.border.FrostBlurIntensity
import com.lasercyber.lws.frostui.border.FrostBlurTint
import com.lasercyber.lws.frostui.border.FrostDimens
import com.lasercyber.lws.frostui.border.PanelFillDrawable

/**
 * Displays a cropped region from the dialog session's frozen backdrop snapshot.
 * Sampling reuses the same full-window capture as [com.lasercyber.lws.frostui.dialog.FrostOverlayHost].
 */
class ImeKeyboardBackdropHost(context: Context) : FrameLayout(context) {

    private val backdropImage = ImageView(context)
    private val fillOverlayView = View(context)
    private var appliedGeneration = -1

    init {
        isClickable = false
        isFocusable = false
        backdropImage.isClickable = false
        backdropImage.isFocusable = false
        backdropImage.scaleType = ImageView.ScaleType.FIT_XY
        backdropImage.visibility = GONE
        fillOverlayView.isClickable = false
        fillOverlayView.isFocusable = false
        addView(
            backdropImage,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT),
        )
        addView(
            fillOverlayView,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT),
        )
        syncPanelFill()
        visibility = VISIBLE
    }

    fun applyLocalBackdrop(
        bitmap: Bitmap?,
        generation: Int,
        blurIntensity: FrostBlurIntensity = FrostBlurIntensity.HIGH,
        forceReapply: Boolean = false,
    ) {
        if (bitmap == null || bitmap.isRecycled) {
            clearBackdrop()
            return
        }
        if (!forceReapply && appliedGeneration == generation && backdropImage.drawable != null) {
            return
        }
        val owned = bitmap.copy(bitmap.config ?: Bitmap.Config.ARGB_8888, false)
        backdropImage.setImageBitmap(owned)
        backdropImage.setColorFilter(
            blurIntensity.resolveOverlayColorInt(context, FrostBlurTint.DARK),
            PorterDuff.Mode.SRC_ATOP,
        )
        backdropImage.visibility = VISIBLE
        appliedGeneration = generation
        syncPanelFill()
        Log.d(TAG, "applyKeyboardBackdrop generation=$generation size=${bitmap.width}x${bitmap.height}")
    }

    fun clearBackdrop() {
        backdropImage.setImageDrawable(null)
        backdropImage.visibility = GONE
        appliedGeneration = -1
        syncPanelFill()
    }

    fun hasValidBackdrop(minBitmapHeightPx: Int): Boolean {
        if (backdropImage.visibility != VISIBLE || backdropImage.drawable == null) {
            return false
        }
        val bitmap = (backdropImage.drawable as? android.graphics.drawable.BitmapDrawable)?.bitmap
            ?: return true
        return !bitmap.isRecycled && bitmap.height >= minBitmapHeightPx
    }

    private fun syncPanelFill() {
        val hasBlur = backdropImage.visibility == VISIBLE
        if (hasBlur) {
            fillOverlayView.visibility = GONE
            fillOverlayView.background = null
            return
        }
        fillOverlayView.alpha = PLACEHOLDER_FILL_ALPHA
        fillOverlayView.background = PanelFillDrawable.create(
            context,
            FrostDimens.cornerRadiusPx(context),
        )
        fillOverlayView.visibility = VISIBLE
    }

    companion object {
        private const val TAG = "FrostBackdrop"
        /** Light frosted placeholder while async capture is in flight (all keyboard kinds). */
        private const val PLACEHOLDER_FILL_ALPHA = 0.35f
    }
}
