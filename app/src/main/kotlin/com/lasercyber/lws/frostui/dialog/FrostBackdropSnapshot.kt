package com.lasercyber.lws.frostui.dialog

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.view.ViewGroup
import com.lasercyber.lws.frostui.blur.FrostBackdropCapture
import com.lasercyber.lws.frostui.blur.FrostBackdropResolver
import com.lasercyber.lws.frostui.blur.HomeBackdropWebPCaptureGuard
import com.lasercyber.lws.frostui.border.FrostBlurIntensity
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Future
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * One-shot backdrop capture for overlay dialogs.
 * Blur is delegated to [FrostBackdropBlurRegistry] (RenderScript Gaussian on app startup).
 */
object FrostBackdropSnapshot {

    /** Matches scale factor used when re-displaying the snapshot. */
    const val BLUR_SCALE_FACTOR = 3f

    private val mainHandler = Handler(Looper.getMainLooper())

    @JvmStatic
    @JvmOverloads
    fun captureAndBlur(
        contentRoot: ViewGroup,
        context: Context,
        blurIntensity: FrostBlurIntensity = FrostBlurIntensity.MIDDLE,
    ): Bitmap? {
        val snapshot = captureSnapshot(contentRoot) ?: return null
        val blurred = FrostBackdropBlurRegistry.blurBitmap(
            context.applicationContext,
            snapshot,
            blurIntensity.dialogGaussianBlurRadiusPx(),
            1,
        )
        if (blurred != null && blurred !== snapshot && !snapshot.isRecycled) {
            snapshot.recycle()
        }
        return blurred
    }

    /**
     * Captures on the UI thread, blurs on a worker thread, then invokes [onComplete] on the main thread.
     */
    @JvmStatic
    @JvmOverloads
    fun captureAndBlurAsync(
        contentRoot: ViewGroup,
        context: Context,
        blurIntensity: FrostBlurIntensity = FrostBlurIntensity.MIDDLE,
        onComplete: (Bitmap?) -> Unit,
    ) {
        val snapshot = captureSnapshot(contentRoot)
        if (snapshot == null) {
            onComplete(null)
            return
        }
        FrostBackdropBlurRegistry.blurBitmapAsync(
            context.applicationContext,
            snapshot,
            blurIntensity.dialogGaussianBlurRadiusPx(),
            1,
            onSuccess = { blurred ->
                if (blurred != null && blurred !== snapshot && !snapshot.isRecycled) {
                    snapshot.recycle()
                }
                onComplete(blurred)
            },
            onFailed = {
                recycle(snapshot)
                onComplete(null)
            },
        )
    }

    /**
     * Crops a card-sized region from a full-window frozen backdrop for dialog cards.
     * Prefer [cropToContentRect] with a [FrozenDialogAnchor] captured at snapshot time.
     */
    @JvmStatic
    fun cropToAnchor(
        frozenFullscreen: Bitmap,
        contentRoot: ViewGroup,
        anchor: View,
    ): Bitmap? {
        if (frozenFullscreen.isRecycled || anchor.width <= 0 || anchor.height <= 0) {
            return null
        }
        val contentLoc = IntArray(2)
        val anchorLoc = IntArray(2)
        contentRoot.getLocationOnScreen(contentLoc)
        anchor.getLocationOnScreen(anchorLoc)
        return cropToContentRect(
            frozenFullscreen,
            anchorLoc[0] - contentLoc[0],
            anchorLoc[1] - contentLoc[1],
            anchor.width,
            anchor.height,
        )
    }

    @JvmStatic
    fun cropToContentRect(
        frozenFullscreen: Bitmap,
        contentLeftPx: Int,
        contentTopPx: Int,
        contentWidthPx: Int,
        contentHeightPx: Int,
    ): Bitmap? {
        if (frozenFullscreen.isRecycled || contentWidthPx <= 0 || contentHeightPx <= 0) {
            return null
        }
        val scale = 1f / BLUR_SCALE_FACTOR
        val left = (contentLeftPx * scale)
            .roundToInt()
            .coerceIn(0, frozenFullscreen.width - 1)
        val top = (contentTopPx * scale)
            .roundToInt()
            .coerceIn(0, frozenFullscreen.height - 1)
        val cropWidth = max(
            1,
            min((contentWidthPx * scale).roundToInt(), frozenFullscreen.width - left),
        )
        val cropHeight = max(
            1,
            min((contentHeightPx * scale).roundToInt(), frozenFullscreen.height - top),
        )
        return Bitmap.createBitmap(frozenFullscreen, left, top, cropWidth, cropHeight)
    }

    @JvmStatic
    fun cropToFrozenAnchor(
        frozenFullscreen: Bitmap,
        anchor: FrozenDialogAnchor,
    ): Bitmap? = cropToContentRect(
        frozenFullscreen,
        anchor.leftPx,
        anchor.topPx,
        anchor.widthPx,
        anchor.heightPx,
    )

    @JvmStatic
    fun captureRegionForAnchor(
        contentRoot: ViewGroup,
        anchor: FrozenDialogAnchor,
    ): Bitmap? {
        if (!anchor.isValid()) {
            return null
        }
        val drawRoot = FrostBackdropResolver.resolveBackdropSnapshotRoot(contentRoot) ?: return null
        val drawLoc = IntArray(2)
        val contentLoc = IntArray(2)
        drawRoot.getLocationOnScreen(drawLoc)
        contentRoot.getLocationOnScreen(contentLoc)
        val offsetX = anchor.leftPx + (contentLoc[0] - drawLoc[0])
        val offsetY = anchor.topPx + (contentLoc[1] - drawLoc[1])
        val scale = 1f / BLUR_SCALE_FACTOR
        val scaledWidth = maxOf(1, kotlin.math.ceil(anchor.widthPx * scale).toInt())
        val scaledHeight = maxOf(1, kotlin.math.ceil(anchor.heightPx * scale).toInt())
        val snapshot = Bitmap.createBitmap(scaledWidth, scaledHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(snapshot)
        canvas.scale(scale, scale)
        canvas.translate(-offsetX.toFloat(), -offsetY.toFloat())
        drawRoot.draw(canvas)
        return snapshot
    }

    /**
     * Captures and blurs the page region behind [card] (dialog card hidden during draw).
     * Uses screen coordinates and [FrostBackdropCapture] for alignment with page cards.
     */
    @JvmStatic
    @JvmOverloads
    fun captureAndBlurForCard(
        contentRoot: ViewGroup,
        card: View,
        context: Context,
        blurIntensity: FrostBlurIntensity = FrostBlurIntensity.MIDDLE,
        overscanPx: Int = 0,
    ): Bitmap? {
        if (card.width <= 0 || card.height <= 0) {
            return null
        }
        val drawRoot = FrostBackdropResolver.resolveBackdropSnapshotRoot(contentRoot) ?: return null
        val snapshot = FrostBackdropCapture.captureRegion(
            drawRoot,
            card,
            BLUR_SCALE_FACTOR,
            overscanPx,
        ) ?: return null
        val blurred = FrostBackdropBlurRegistry.blurBitmap(
            context.applicationContext,
            snapshot,
            blurIntensity.dialogGaussianBlurRadiusPx(),
            1,
        )
        if (blurred != null && blurred !== snapshot && !snapshot.isRecycled) {
            snapshot.recycle()
        }
        return blurred
    }

    @JvmStatic
    @JvmOverloads
    fun blurCapturedSnapshotAsync(
        context: Context,
        snapshot: Bitmap,
        blurIntensity: FrostBlurIntensity = FrostBlurIntensity.MIDDLE,
        onComplete: (Bitmap?) -> Unit,
    ): Future<*> {
        return FrostBackdropBlurRegistry.blurBitmapAsync(
            context.applicationContext,
            snapshot,
            blurIntensity.dialogGaussianBlurRadiusPx(),
            1,
            onSuccess = { blurred ->
                if (blurred != null && blurred !== snapshot && !snapshot.isRecycled) {
                    snapshot.recycle()
                }
                onComplete(blurred)
            },
            onFailed = {
                recycle(snapshot)
                onComplete(null)
            },
        )
    }

    /**
     * Captures and blurs only the dialog-card viewport (legacy BlurView samples card-sized region).
     */
    @JvmStatic
    @JvmOverloads
    fun captureAndBlurForAnchor(
        contentRoot: ViewGroup,
        anchor: FrozenDialogAnchor,
        context: Context,
        blurIntensity: FrostBlurIntensity = FrostBlurIntensity.MIDDLE,
    ): Bitmap? {
        val snapshot = captureRegionForAnchor(contentRoot, anchor) ?: return null
        val blurred = FrostBackdropBlurRegistry.blurBitmap(
            context.applicationContext,
            snapshot,
            blurIntensity.dialogGaussianBlurRadiusPx(),
            1,
        )
        if (blurred != null && blurred !== snapshot && !snapshot.isRecycled) {
            snapshot.recycle()
        }
        return blurred
    }

    @JvmStatic
    fun captureSnapshot(contentRoot: ViewGroup): Bitmap? {
        val drawRoot = FrostBackdropResolver.resolveBackdropSnapshotRoot(contentRoot) ?: return null
        val width = contentRoot.width
        val height = contentRoot.height
        if (width <= 0 || height <= 0) {
            return null
        }

        val scale = 1f / BLUR_SCALE_FACTOR
        val scaledWidth = maxOf(1, kotlin.math.ceil(width * scale).toInt())
        val scaledHeight = maxOf(1, kotlin.math.ceil(height * scale).toInt())

        val snapshot = Bitmap.createBitmap(scaledWidth, scaledHeight, Bitmap.Config.ARGB_8888)
        snapshot.density = contentRoot.resources.displayMetrics.densityDpi
        val canvas = Canvas(snapshot)
        canvas.scale(scale, scale)
        // Match legacy FrostedGlassBackdropSnapshot: draw page root at content origin.
        HomeBackdropWebPCaptureGuard.withOverlayHidden(drawRoot) {
            drawRoot.draw(canvas)
        }
        return snapshot
    }

    @JvmStatic
    fun recycle(bitmap: Bitmap?) {
        if (bitmap != null && !bitmap.isRecycled) {
            bitmap.recycle()
        }
    }

    /** True when [bitmap] was captured for a single dialog card (IME refresh), not full-window. */
    @JvmStatic
    fun matchesFrozenAnchor(bitmap: Bitmap, anchor: FrozenDialogAnchor): Boolean {
        if (bitmap.isRecycled || !anchor.isValid()) {
            return false
        }
        val expectedW = kotlin.math.ceil(anchor.widthPx / BLUR_SCALE_FACTOR).toInt()
        val expectedH = kotlin.math.ceil(anchor.heightPx / BLUR_SCALE_FACTOR).toInt()
        return abs(bitmap.width - expectedW) <= 2 && abs(bitmap.height - expectedH) <= 2
    }
}
