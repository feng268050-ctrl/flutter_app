package com.lasercyber.lws.frostui.card.interop

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Outline
import android.graphics.PorterDuff
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.util.AttributeSet
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.view.View.MeasureSpec
import android.view.ViewGroup
import android.view.ViewGroup.MarginLayoutParams
import android.view.ViewOutlineProvider
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import com.lasercyber.lws.frostui.border.PanelFillDrawable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.frostui.blur.FrostBackdropCapture
import com.lasercyber.lws.frostui.blur.FrostBackdropDisplay
import com.lasercyber.lws.frostui.blur.FrostBackdropDisplayMode
import com.lasercyber.lws.frostui.blur.FrostBackdropResolver
import com.lasercyber.lws.frostui.blur.FrostBlurViewSupport
import com.lasercyber.lws.frostui.dialog.FrostBackdropBlurRegistry
import eightbitlab.com.blurview.BlurView
import com.lasercyber.lws.frostui.border.BorderGradientCenter
import com.lasercyber.lws.frostui.border.FrostBlurIntensity
import com.lasercyber.lws.frostui.border.FrostBlurTint
import com.lasercyber.lws.frostui.border.FrostDimens
import com.lasercyber.lws.frostui.border.FrostPanelBorderForeground
import com.lasercyber.lws.frostui.border.PanelBorderPainter
import com.lasercyber.lws.frostui.card.FrostCard
import com.lasercyber.lws.frostui.card.FrostCardBlurRegistry
import com.lasercyber.lws.frostui.card.frostCornerRadiusDp
import com.lasercyber.lws.frostui.dialog.FrostOverlayHost
import com.lasercyber.lws.frostui.dialog.FrostBackdropSnapshot
import com.lasercyber.lws.frostui.dialog.FrostResourceIds
import java.util.concurrent.Future
import kotlin.math.roundToInt

/**
 * XML/Java bridge for [FrostCard]. Drop-in replacement for legacy [FrostedGlassCard] on migrated screens.
 *
 * Extends [FrameLayout] so XML children inflate normally; frost chrome is drawn by an internal [ComposeView].
 */
open class FrostCardView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : FrameLayout(context, attrs, defStyleAttr) {

    private val chromeView = ComposeView(context)
    private val contentHostLayout = LinearLayout(context)
    private val borderForeground = FrostPanelBorderForeground(context)
    private val staticBackdropLayer = FrameLayout(context).apply {
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        visibility = GONE
        clipChildren = true
        isClickable = false
        isFocusable = false
    }
    private val staticBackdropImage = ImageView(context).apply {
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        scaleType = ImageView.ScaleType.MATRIX
        isClickable = false
        isFocusable = false
    }
    private val fillOverlayView = View(context).apply {
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        visibility = GONE
        isClickable = false
        isFocusable = false
    }
    private val initialAttrs = FrostCardAttrs.read(context, attrs, defStyleAttr)

    private var panelBorderGradientCenter by mutableStateOf(initialAttrs.borderGradientCenter)
    private var drawFillEnabled by mutableStateOf(initialAttrs.drawFill)
    private val drawFillExplicit = initialAttrs.drawFillExplicit
    private var drawBorderEnabled by mutableStateOf(initialAttrs.drawBorder)
    private var stackPanelFillWithBlur by mutableStateOf(initialAttrs.stackPanelFillWithBlur)
    private var enableBackdropBlur = initialAttrs.enableBackdropBlur
    private var panelBlurTint by mutableStateOf(initialAttrs.blurTint)
    private var panelBlurIntensity by mutableStateOf(initialAttrs.blurIntensity)
    private var blurTintExplicit = initialAttrs.blurTintExplicit
    private var blurIntensityExplicit = initialAttrs.blurIntensityExplicit
    private var cornerRadiusPx by mutableStateOf(initialAttrs.cornerRadiusPx)
    private var captureGeneration = 0
    private var blurFuture: Future<*>? = null
    private var liveBlurView: BlurView? = null
    private var liveBlurConfigured = false
    private var liveBlurEnabled = false
    private var contentPaddingLeft = 0
    private var contentPaddingTop = 0
    private var contentPaddingRight = 0
    private var contentPaddingBottom = 0
    private var lastHeightMeasureMode = MeasureSpec.UNSPECIFIED
    private var staticBackdropActive by mutableStateOf(false)
    private var backdropBitmap by mutableStateOf<Bitmap?>(null)
    private var backdropDisplayMode by mutableStateOf(FrostBackdropDisplayMode.LOCAL)
    private var localCaptureScaleFactor by mutableFloatStateOf(FrostBackdropCapture.BLUR_SCALE_FACTOR)
    private var fullscreenBackdropOffsetX by mutableFloatStateOf(0f)
    private var fullscreenBackdropOffsetY by mutableFloatStateOf(0f)
    /** Dialog frozen blur is cropped once then stretched on resize (legacy BlurView freeze semantics). */
    private var dialogFrozenBackdropLocked = false
    private var appliedFrozenBackdropGeneration = -1
    /** Home/page cards: blur sampled once then frozen (matches boot self-check dialog semantics). */
    private var localBackdropLocked = false
    /** While a dialog overlay is open, page cards must not live-resample (IME / capture hide siblings). */
    private var pageBackdropFrozenDuringOverlay = false
    /** Bilinear-upscaled copy for FULLSCREEN display (avoids MATRIX 3× banding). */
    private var upscaledBackdropBitmap: Bitmap? = null

    companion object {
        private const val TAG = "FrostBackdrop"
        /** Stack fill over native blurred bitmap — keep light so backdrop stays visible. */
        private const val STATIC_BACKDROP_FILL_ALPHA = 0.35f
        /** Wait for background/GIF to paint before first card blur capture (matches BlurView settle). */
        private const val BACKDROP_CAPTURE_FRAME_WAIT = 5
    }

    init {
        contentHostLayout.orientation = initialAttrs.contentOrientation
        contentHostLayout.gravity = initialAttrs.contentGravity
        isClickable = false
        isFocusable = false
        clipChildren = true
        chromeView.isClickable = false
        chromeView.isFocusable = false
        chromeView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        contentHostLayout.isClickable = false
        contentHostLayout.isFocusable = false

        val chromeParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        val contentParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        staticBackdropLayer.addView(staticBackdropImage)
        staticBackdropLayer.addView(fillOverlayView)
        super.addView(staticBackdropLayer, 0, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        super.addView(chromeView, 1, chromeParams)
        super.addView(contentHostLayout, 2, contentParams)
        chromeView.setContent { FrostCardChrome() }
        restoreContentPaddingFromAttrs(attrs)
        updateRoundedClipOutline()
        syncBorderForeground()
    }

    private fun resolveCornerRadiusPx(): Float =
        if (cornerRadiusPx >= 0f) cornerRadiusPx else FrostDimens.cornerRadiusPx(context)

    private fun createRoundedClipDrawable(): GradientDrawable =
        GradientDrawable().apply {
            setColor(Color.TRANSPARENT)
            cornerRadius = resolveCornerRadiusPx()
        }

    private fun applyViewRoundedClip(view: View) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return
        }
        view.outlineProvider = ViewOutlineProvider.BACKGROUND
        view.clipToOutline = true
    }

    private fun updateBackdropLayerClip() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return
        }
        staticBackdropLayer.background = createRoundedClipDrawable()
        applyViewRoundedClip(staticBackdropLayer)
        staticBackdropLayer.invalidateOutline()
    }

    private fun updateRoundedClipOutline() {
        val radius = resolveCornerRadiusPx()
        if (radius <= 0f) {
            clipToOutline = false
            outlineProvider = ViewOutlineProvider.BACKGROUND
            background = null
            return
        }
        clipToOutline = true
        if (staticBackdropActive && backdropDisplayMode == FrostBackdropDisplayMode.FULLSCREEN) {
            background = createRoundedClipDrawable()
            applyViewRoundedClip(this)
            updateBackdropLayerClip()
        } else {
            background = null
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    outline.setRoundRect(0, 0, view.width, view.height, radius)
                }
            }
            if (staticBackdropActive && backdropDisplayMode == FrostBackdropDisplayMode.LOCAL) {
                updateBackdropLayerClip()
            }
        }
        invalidateOutline()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w != oldw || h != oldh) {
            invalidateOutline()
            notifyDialogCardBoundsChangedIfNeeded(w, h, oldw, oldh)
            if (staticBackdropActive &&
                (backdropDisplayMode == FrostBackdropDisplayMode.FULLSCREEN ||
                    backdropDisplayMode == FrostBackdropDisplayMode.LOCAL)
            ) {
                if (backdropDisplayMode == FrostBackdropDisplayMode.FULLSCREEN) {
                    updateFullscreenBackdropOffsetIfNeeded()
                }
                updateBackdropLayerClip()
            }
        }
    }

    private fun restoreContentPaddingFromAttrs(attrs: AttributeSet?) {
        if (attrs == null) {
            return
        }
        val paddingAttrs = intArrayOf(
            android.R.attr.padding,
            android.R.attr.paddingLeft,
            android.R.attr.paddingTop,
            android.R.attr.paddingRight,
            android.R.attr.paddingBottom,
            android.R.attr.paddingStart,
            android.R.attr.paddingEnd,
        )
        val typedArray = context.obtainStyledAttributes(attrs, paddingAttrs)
        try {
            val fallback = typedArray.getDimensionPixelSize(0, 0)
            val left = typedArray.getDimensionPixelSize(1, fallback)
            val top = typedArray.getDimensionPixelSize(2, fallback)
            val right = typedArray.getDimensionPixelSize(3, fallback)
            val bottom = typedArray.getDimensionPixelSize(4, fallback)
            val start = typedArray.getDimensionPixelSize(5, left)
            val end = typedArray.getDimensionPixelSize(6, right)
            val resolvedLeft = if (typedArray.hasValue(5)) start else left
            val resolvedRight = if (typedArray.hasValue(6)) end else right
            if (resolvedLeft != 0 || top != 0 || resolvedRight != 0 || bottom != 0) {
                setPadding(resolvedLeft, top, resolvedRight, bottom)
            }
        } finally {
            typedArray.recycle()
        }
    }

    fun setBorderGradientCenter(center: BorderGradientCenter) {
        panelBorderGradientCenter = center
        syncBorderForeground()
    }

    fun setDrawFill(enabled: Boolean) {
        drawFillEnabled = enabled
        syncBorderForeground()
    }

    fun setDrawBorder(enabled: Boolean) {
        drawBorderEnabled = enabled
        syncBorderForeground()
    }

    fun setBlurTint(tint: FrostBlurTint) {
        panelBlurTint = tint
        blurTintExplicit = true
    }

    fun setBlurIntensity(intensity: FrostBlurIntensity) {
        panelBlurIntensity = intensity
        blurIntensityExplicit = true
        if (!intensity.usesBackdropBlur()) {
            clearStaticBackdrop()
        }
        if (!drawFillExplicit) {
            drawFillEnabled = intensity.drawsFill()
        }
        scheduleBackdropBlur()
    }

    /** When false, frosted cards keep border/fill chrome but skip live backdrop capture until re-enabled. */
    @JvmOverloads
    fun setEnableBackdropBlur(enabled: Boolean) {
        if (enableBackdropBlur == enabled) {
            return
        }
        enableBackdropBlur = enabled
        if (!enabled) {
            blurFuture?.cancel(false)
            blurFuture = null
            teardownLiveBackdropBlur()
            clearStaticBackdrop()
            return
        }
        if (isAttachedToWindow) {
            scheduleBackdropBlur()
        }
    }

    fun isEnableBackdropBlur(): Boolean = enableBackdropBlur

    /** Blur preset used when [FrostOverlayHost] captures the dialog frozen backdrop. */
    fun blurIntensityForBackdropCapture(): FrostBlurIntensity = panelBlurIntensity

    protected fun isBlurTintExplicit(): Boolean = blurTintExplicit

    protected fun isBlurIntensityExplicit(): Boolean = blurIntensityExplicit

    protected fun setContentGravity(gravity: Int) {
        contentHostLayout.gravity = gravity
    }

    protected fun setContentOrientation(orientation: Int) {
        contentHostLayout.orientation = orientation
    }

    override fun setPadding(left: Int, top: Int, right: Int, bottom: Int) {
        contentPaddingLeft = left
        contentPaddingTop = top
        contentPaddingRight = right
        contentPaddingBottom = bottom
        super.setPadding(0, 0, 0, 0)
        requestLayout()
    }

    override fun getPaddingLeft(): Int = contentPaddingLeft

    override fun getPaddingTop(): Int = contentPaddingTop

    override fun getPaddingRight(): Int = contentPaddingRight

    override fun getPaddingBottom(): Int = contentPaddingBottom

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val horizontalPadding = contentPaddingLeft + contentPaddingRight
        val verticalPadding = contentPaddingTop + contentPaddingBottom

        val contentWidthSpec = measureSpecForContent(
            widthMeasureSpec,
            horizontalPadding,
            contentHostLayout.layoutParams.width,
        )
        val contentHeightSpec = measureSpecForContent(
            heightMeasureSpec,
            verticalPadding,
            contentHostLayout.layoutParams.height,
        )
        contentHostLayout.measure(contentWidthSpec, contentHeightSpec)

        val heightMode = MeasureSpec.getMode(heightMeasureSpec)
        lastHeightMeasureMode = heightMode

        val contentWidth = contentHostLayout.measuredWidth + horizontalPadding
        val contentHeight = contentHostLayout.measuredHeight + verticalPadding
        val layoutParams = layoutParams
        val desiredWidth = resolveMeasuredDimension(
            layoutParamSize = layoutParams.width,
            measureSpec = widthMeasureSpec,
            contentSize = contentWidth,
        )
        val desiredHeight = resolveMeasuredDimension(
            layoutParamSize = layoutParams.height,
            measureSpec = heightMeasureSpec,
            contentSize = contentHeight,
        )

        if (isAttachedToWindow) {
            val chromeWidthSpec = MeasureSpec.makeMeasureSpec(desiredWidth, MeasureSpec.EXACTLY)
            val chromeHeightSpec = MeasureSpec.makeMeasureSpec(desiredHeight, MeasureSpec.EXACTLY)
            if (staticBackdropLayer.visibility != GONE) {
                staticBackdropLayer.measure(chromeWidthSpec, chromeHeightSpec)
            }
            if (chromeView.visibility != GONE) {
                chromeView.measure(chromeWidthSpec, chromeHeightSpec)
            }
        }
        setMeasuredDimension(desiredWidth, desiredHeight)
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val width = right - left
        val height = bottom - top
        if (staticBackdropLayer.visibility != GONE) {
            staticBackdropLayer.layout(0, 0, width, height)
        }
        if (chromeView.visibility != GONE) {
            chromeView.layout(0, 0, width, height)
        }
        val contentBottom = if (lastHeightMeasureMode == MeasureSpec.EXACTLY) {
            height - contentPaddingBottom
        } else {
            contentPaddingTop + contentHostLayout.measuredHeight
        }
        contentHostLayout.layout(
            contentPaddingLeft,
            contentPaddingTop,
            width - contentPaddingRight,
            contentBottom,
        )
        updateFullscreenBackdropOffsetIfNeeded()
        if (isInsideDialogOverlay() &&
            dialogFrozenBackdropLocked &&
            !shouldKeepDialogBackdropLocked()
        ) {
            refreshDialogBackdropCrop()
        }
        if (changed && !hasActiveBackdrop() && !localBackdropLocked &&
            enableBackdropBlur &&
            panelBlurIntensity.usesBackdropBlur() && drawFillEnabled
        ) {
            when {
                FrostBackdropResolver.findLocalCaptureTarget(this) != null -> scheduleBackdropBlur()
                isInsideDialogOverlay() -> applyFrozenBackdropIfAvailable()
                else -> scheduleBackdropBlur()
            }
        }
    }

    /**
     * Match [FrameLayout] sizing: honor positive [ViewGroup.LayoutParams] width/height even when
     * content is smaller (machine-status dialog gauge/tile cards).
     */
    private fun resolveMeasuredDimension(
        layoutParamSize: Int,
        measureSpec: Int,
        contentSize: Int,
    ): Int {
        val mode = MeasureSpec.getMode(measureSpec)
        val specSize = MeasureSpec.getSize(measureSpec)
        if (layoutParamSize > 0) {
            return when (mode) {
                MeasureSpec.EXACTLY -> specSize
                MeasureSpec.AT_MOST -> minOf(specSize, layoutParamSize)
                else -> layoutParamSize
            }
        }
        return when (mode) {
            MeasureSpec.EXACTLY -> specSize
            MeasureSpec.AT_MOST -> minOf(specSize, contentSize)
            else -> contentSize
        }
    }

    private fun measureSpecForContent(
        parentSpec: Int,
        totalPadding: Int,
        childLayoutSize: Int,
    ): Int {
        val parentMode = MeasureSpec.getMode(parentSpec)
        val parentSize = MeasureSpec.getSize(parentSpec)
        val available = (parentSize - totalPadding).coerceAtLeast(0)
        return when (parentMode) {
            MeasureSpec.EXACTLY -> {
                when {
                    childLayoutSize == LayoutParams.MATCH_PARENT ||
                        contentHostHasMatchParentHeightChild() ->
                        MeasureSpec.makeMeasureSpec(available, MeasureSpec.EXACTLY)
                    else ->
                        MeasureSpec.makeMeasureSpec(available, MeasureSpec.AT_MOST)
                }
            }
            MeasureSpec.AT_MOST -> MeasureSpec.makeMeasureSpec(available, MeasureSpec.AT_MOST)
            else -> MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        }
    }

    private fun contentHostHasMatchParentHeightChild(): Boolean {
        for (index in 0 until contentHostLayout.childCount) {
            val childParams = contentHostLayout.getChildAt(index).layoutParams
            if (childParams.height == LayoutParams.MATCH_PARENT) {
                return true
            }
            if (childParams is LinearLayout.LayoutParams &&
                childParams.height == 0 &&
                childParams.weight > 0f
            ) {
                return true
            }
        }
        return false
    }

    fun applyFrozenBackdropIfAvailable() {
        if (shouldKeepPageBackdropUntouched()) {
            return
        }
        if (hasPanelLocalBlurTarget()) {
            scheduleBackdropBlur()
            return
        }
        if (isInsideDialogOverlay()) {
            val activity = FrostOverlayHost.findActivity(context) ?: return
            val frozen = FrostCardBlurRegistry.getFrozenBackdrop?.invoke(activity) ?: return
            val generation = FrostCardBlurRegistry.getFrozenBackdropGeneration?.invoke(activity) ?: 0
            if (dialogFrozenBackdropLocked && appliedFrozenBackdropGeneration == generation &&
                staticBackdropActive && backdropDisplayMode == FrostBackdropDisplayMode.FULLSCREEN
            ) {
                syncNativeStaticBackdrop()
                return
            }
            clearStaticBackdrop()
            applyDialogFrozenBackdrop(frozen, generation, activity)
            return
        }
    }

    /** Clears a stale in-card blur while a new anchor capture is in flight (centered card moved on screen). */
    fun clearDisplayedBackdropForRecapture() {
        if (!staticBackdropActive && !liveBlurEnabled) {
            return
        }
        teardownLiveBackdropBlur()
        recycleOwnedBackdrop()
        staticBackdropActive = false
        dialogFrozenBackdropLocked = false
        appliedFrozenBackdropGeneration = -1
    }

    /** Reapplies the latest frozen snapshot without clearing the current frame (IME backdrop refresh). */
    fun forceReapplyFrozenBackdrop() {
        if (shouldKeepPageBackdropUntouched()) {
            return
        }
        if (hasPanelLocalBlurTarget()) {
            refreshBackdropBlur(force = true)
            return
        }
        if (isInsideDialogOverlay()) {
            val activity = FrostOverlayHost.findActivity(context) ?: return
            val frozen = FrostCardBlurRegistry.getFrozenBackdrop?.invoke(activity) ?: return
            val generation = FrostCardBlurRegistry.getFrozenBackdropGeneration?.invoke(activity) ?: 0
            applyDialogFrozenBackdrop(frozen, generation, activity, forceRecrop = true)
            return
        }
        clearStaticBackdrop()
        applyFrozenBackdropIfAvailable()
    }

    /** Locks live page blur while a dialog overlay is open so IME recapture does not disturb siblings. */
    fun freezePageBackdropDuringOverlay() {
        pageBackdropFrozenDuringOverlay = true
        if (hasActiveBackdrop()) {
            localBackdropLocked = true
            freezeLiveBackdropBlur()
        }
    }

    fun unfreezePageBackdropAfterOverlay() {
        pageBackdropFrozenDuringOverlay = false
        if (!hasActiveBackdrop() && !localBackdropLocked) {
            scheduleBackdropBlur()
        }
    }

    /**
     * Re-captures page-card backdrop blur. When [force] is false, cards that already have a
     * frozen local snapshot are left untouched (avoids flash after dialog dismiss).
     */
    @JvmOverloads
    fun refreshBackdropBlur(force: Boolean = false) {
        if (!enableBackdropBlur || !panelBlurIntensity.usesBackdropBlur()) {
            return
        }
        if (shouldBlockPageBackdropMutation()) {
            return
        }
        if (!force && (localBackdropLocked || hasActiveBackdrop())) {
            return
        }
        post {
            if (force) {
                teardownLiveBackdropBlur()
                clearStaticBackdrop()
            }
            waitFramesAndCapture(BACKDROP_CAPTURE_FRAME_WAIT)
        }
    }

    fun syncStaticBackdropMatrix() {
        if (isInsideDialogOverlay() && dialogFrozenBackdropLocked) {
            if (backdropDisplayMode == FrostBackdropDisplayMode.FULLSCREEN &&
                shouldKeepDialogBackdropLocked()
            ) {
                updateFullscreenBackdropOffsetIfNeeded()
            } else if (!shouldKeepDialogBackdropLocked()) {
                refreshDialogBackdropCrop()
            }
            return
        }
        if (shouldKeepPageBackdropUntouched()) {
            return
        }
        updateFullscreenBackdropOffsetIfNeeded()
    }

    /** Re-crops the session fullscreen frozen bitmap to the card viewport (IME / layout moves). */
    fun refreshDialogBackdropCrop() {
        if (!isInsideDialogOverlay() || width <= 0 || height <= 0) {
            return
        }
        val activity = FrostOverlayHost.findActivity(context) ?: return
        val frozen = FrostCardBlurRegistry.getFrozenBackdrop?.invoke(activity) ?: return
        val generation = FrostCardBlurRegistry.getFrozenBackdropGeneration?.invoke(activity) ?: 0
        applyDialogFrozenBackdrop(frozen, generation, activity, forceRecrop = true)
    }

    private fun applyBackdropBitmap(
        bitmap: Bitmap,
        displayMode: FrostBackdropDisplayMode,
        captureScaleFactor: Float = FrostBackdropCapture.BLUR_SCALE_FACTOR,
    ) {
        teardownLiveBackdropBlur()
        val owned = bitmap.copy(bitmap.config ?: Bitmap.Config.ARGB_8888, false)
        // Keep the previous bitmap alive until the view is explicitly cleared.
        // Compose may still be drawing the old snapshot while a new one is being swapped in.
        backdropBitmap = owned
        backdropDisplayMode = displayMode
        localCaptureScaleFactor = captureScaleFactor
        staticBackdropActive = true
        if (displayMode == FrostBackdropDisplayMode.FULLSCREEN) {
            syncNativeStaticBackdrop()
            updateFullscreenBackdropOffsetIfNeeded()
        } else {
            syncNativeStaticBackdrop()
            localBackdropLocked = true
        }
        Log.d(TAG, "applyBackdropBitmap mode=$displayMode size=${owned.width}x${owned.height}")
    }

    private fun clearStaticBackdrop() {
        teardownLiveBackdropBlur()
        hideNativeStaticBackdrop()
        recycleOwnedBackdrop()
        staticBackdropActive = false
        backdropDisplayMode = FrostBackdropDisplayMode.LOCAL
        fullscreenBackdropOffsetX = 0f
        fullscreenBackdropOffsetY = 0f
        dialogFrozenBackdropLocked = false
        appliedFrozenBackdropGeneration = -1
        localBackdropLocked = false
        localCaptureScaleFactor = FrostBackdropCapture.BLUR_SCALE_FACTOR
    }

    private fun recycleOwnedBackdrop() {
        // These bitmaps are handed to Compose Image via asImageBitmap(). A draw pass can
        // still reference the old instance after View state changes, so explicit recycle()
        // can crash Canvas with "trying to use a recycled bitmap". Drop the reference and
        // let the runtime reclaim it.
        backdropBitmap = null
    }

    private fun hasActiveBackdrop(): Boolean =
        liveBlurEnabled || backdropBitmap?.takeIf { !it.isRecycled } != null

    private fun updateFullscreenBackdropOffsetIfNeeded() {
        if (!staticBackdropActive || backdropDisplayMode != FrostBackdropDisplayMode.FULLSCREEN) {
            return
        }
        updateFullscreenBackdropOffset()
    }

    private fun notifyDialogCardBoundsChangedIfNeeded(
        width: Int,
        height: Int,
        oldWidth: Int,
        oldHeight: Int,
    ) {
        if (!isInsideDialogOverlay() || !staticBackdropActive) {
            return
        }
        if (width == oldWidth && height == oldHeight) {
            return
        }
        if (dialogFrozenBackdropLocked && !shouldKeepDialogBackdropLocked()) {
            val activity = FrostOverlayHost.findActivity(context) ?: return
            FrostOverlayHost.notifyDialogCardBoundsChanged(activity)
        }
    }

    private fun shouldKeepDialogBackdropLocked(): Boolean {
        val activity = FrostOverlayHost.findActivity(context) ?: return false
        return FrostOverlayHost.shouldKeepDialogBackdropLocked(activity)
    }

    private fun updateFullscreenBackdropOffset() {
        if (!staticBackdropActive || backdropDisplayMode != FrostBackdropDisplayMode.FULLSCREEN) {
            return
        }
        val cardLocation = IntArray(2)
        val originLocation = IntArray(2)
        getLocationOnScreen(cardLocation)
        if (isInsideDialogOverlay()) {
            // Legacy FrostedGlassCard matrix: align decorView origin to the card viewport.
            rootView.getLocationOnScreen(originLocation)
        } else {
            val (offsetX, offsetY) = FrostBackdropDisplay.fullscreenOffsetPx(this)
            fullscreenBackdropOffsetX = offsetX
            fullscreenBackdropOffsetY = offsetY
            return
        }
        fullscreenBackdropOffsetX = (originLocation[0] - cardLocation[0]).toFloat()
        fullscreenBackdropOffsetY = (originLocation[1] - cardLocation[1]).toFloat()
        syncStaticBackdropImageMatrix()
    }

    private fun syncNativeStaticBackdrop() {
        if (!staticBackdropActive) {
            hideNativeStaticBackdrop()
            return
        }
        val bitmap = backdropBitmap?.takeIf { !it.isRecycled } ?: return
        applyFilteredBackdropBitmap(bitmap)
        staticBackdropImage.setColorFilter(
            panelBlurIntensity.resolveOverlayColorInt(context, panelBlurTint),
            PorterDuff.Mode.SRC_ATOP,
        )
        when (backdropDisplayMode) {
            FrostBackdropDisplayMode.FULLSCREEN -> {
                staticBackdropImage.scaleType = ImageView.ScaleType.MATRIX
                syncStaticBackdropImageMatrix()
            }
            FrostBackdropDisplayMode.LOCAL -> {
                staticBackdropImage.scaleType = ImageView.ScaleType.FIT_XY
                staticBackdropImage.imageMatrix = Matrix()
            }
        }
        staticBackdropLayer.visibility = VISIBLE
        chromeView.visibility = GONE
        updateBackdropLayerClip()
        updateRoundedClipOutline()
        val showFill = drawFillEnabled &&
            stackPanelFillWithBlur &&
            panelBlurIntensity.drawsFill() &&
            !shouldSuppressFillUntilBackdrop()
        if (showFill) {
            fillOverlayView.background = PanelFillDrawable.create(
                context,
                resolveCornerRadiusPx(),
            )
            fillOverlayView.alpha = STATIC_BACKDROP_FILL_ALPHA
            fillOverlayView.visibility = VISIBLE
        } else {
            fillOverlayView.background = null
            fillOverlayView.visibility = GONE
        }
    }

    private fun hideNativeStaticBackdrop() {
        staticBackdropLayer.visibility = GONE
        fillOverlayView.visibility = GONE
        fillOverlayView.background = null
        staticBackdropImage.setImageDrawable(null)
        staticBackdropImage.setImageBitmap(null)
        recycleUpscaledBackdrop()
        if (chromeView.visibility != VISIBLE) {
            chromeView.visibility = VISIBLE
        }
        background = null
        updateRoundedClipOutline()
    }

    private fun applyFilteredBackdropBitmap(bitmap: Bitmap) {
        recycleUpscaledBackdrop()
        bitmap.density = resources.displayMetrics.densityDpi
        val scale = localCaptureScaleFactor
        val toDisplay = if (scale > 1.01f) {
            val targetWidth = (bitmap.width * scale).roundToInt().coerceAtLeast(1)
            val targetHeight = (bitmap.height * scale).roundToInt().coerceAtLeast(1)
            if (targetWidth == bitmap.width && targetHeight == bitmap.height) {
                bitmap
            } else {
                Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true).also {
                    it.density = resources.displayMetrics.densityDpi
                    upscaledBackdropBitmap = it
                }
            }
        } else {
            bitmap
        }
        val drawable = BitmapDrawable(resources, toDisplay).apply {
            setFilterBitmap(true)
            setAntiAlias(true)
            setDither(true)
        }
        staticBackdropImage.setImageDrawable(drawable)
    }

    private fun syncStaticBackdropImageMatrix() {
        if (!staticBackdropActive || backdropDisplayMode != FrostBackdropDisplayMode.FULLSCREEN) {
            return
        }
        val matrix = Matrix()
        if (upscaledBackdropBitmap == null) {
            matrix.setScale(localCaptureScaleFactor, localCaptureScaleFactor)
        }
        matrix.postTranslate(fullscreenBackdropOffsetX, fullscreenBackdropOffsetY)
        staticBackdropImage.imageMatrix = matrix
    }

    private fun recycleUpscaledBackdrop() {
        upscaledBackdropBitmap?.let { upscaled ->
            if (!upscaled.isRecycled) {
                upscaled.recycle()
            }
        }
        upscaledBackdropBitmap = null
    }

    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        if (contentHostLayout.visibility != View.VISIBLE) {
            return super.dispatchTouchEvent(ev)
        }
        val transformed = MotionEvent.obtain(ev)
        transformed.offsetLocation(
            (scrollX - contentHostLayout.left).toFloat(),
            (scrollY - contentHostLayout.top).toFloat(),
        )
        val handled = contentHostLayout.dispatchTouchEvent(transformed)
        transformed.recycle()
        if (handled) {
            return true
        }
        return onTouchEvent(ev)
    }

    override fun onInterceptTouchEvent(ev: MotionEvent): Boolean = false

    override fun addView(child: View, index: Int, params: ViewGroup.LayoutParams?) {
        if (child === chromeView || child === contentHostLayout || child === staticBackdropLayer) {
            super.addView(child, index, params)
            return
        }
        val hostIndex = if (index < 0) -1 else index.coerceAtMost(contentHostLayout.childCount)
        val contentParams = params?.let { toContentLayoutParams(it) } ?: params
        contentHostLayout.addView(child, hostIndex, contentParams)
    }

    override fun onFinishInflate() {
        super.onFinishInflate()
        repairContentLinearLayoutParams(contentHostLayout)
    }

    private fun toContentLayoutParams(params: ViewGroup.LayoutParams): ViewGroup.LayoutParams {
        if (params is LinearLayout.LayoutParams) {
            return params
        }
        val linearParams = if (params is MarginLayoutParams) {
            LinearLayout.LayoutParams(params)
        } else {
            LinearLayout.LayoutParams(params.width, params.height)
        }
        if (params is FrameLayout.LayoutParams) {
            linearParams.gravity = params.gravity
        }
        return linearParams
    }

    private fun repairContentLinearLayoutParams(group: ViewGroup) {
        val vertical = group !is LinearLayout ||
            group.orientation == LinearLayout.VERTICAL
        for (i in 0 until group.childCount) {
            val child = group.getChildAt(i)
            val params = child.layoutParams
            if (vertical) {
                if (params.height == 0 &&
                    (params !is LinearLayout.LayoutParams || params.weight <= 0f)
                ) {
                    applyLinearWeight(child, params, params.width, 0)
                }
            } else if (params.width == 0 &&
                (params !is LinearLayout.LayoutParams || params.weight <= 0f)
            ) {
                applyLinearWeight(child, params, 0, params.height)
            }
            if (child is ViewGroup) {
                repairContentLinearLayoutParams(child)
            }
        }
    }

    private fun applyLinearWeight(
        child: View,
        params: ViewGroup.LayoutParams,
        width: Int,
        height: Int,
    ) {
        val linearParams = if (params is MarginLayoutParams) {
            LinearLayout.LayoutParams(params)
        } else {
            LinearLayout.LayoutParams(params.width, params.height)
        }
        linearParams.width = width
        linearParams.height = height
        linearParams.weight = 1f
        if (params is LinearLayout.LayoutParams) {
            linearParams.gravity = params.gravity
        }
        child.layoutParams = linearParams
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (chromeView.measuredWidth == 0 || chromeView.measuredHeight == 0) {
            requestLayout()
        }
        scheduleBackdropBlur()
    }

    override fun onDetachedFromWindow() {
        blurFuture?.cancel(false)
        blurFuture = null
        teardownLiveBackdropBlur()
        clearStaticBackdrop()
        super.onDetachedFromWindow()
    }

    private fun scheduleBackdropBlur() {
        if (hasActiveBackdrop() || localBackdropLocked) {
            return
        }
        if (!panelBlurIntensity.usesBackdropBlur() || !drawFillEnabled || !enableBackdropBlur) {
            return
        }
        if (!isAttachedToWindow) {
            return
        }
        post { waitFramesAndCapture(BACKDROP_CAPTURE_FRAME_WAIT) }
    }

    private fun waitFramesAndCapture(framesRemaining: Int) {
        if (!isAttachedToWindow || hasActiveBackdrop()) {
            return
        }
        if (framesRemaining <= 0) {
            resolveBackdropBlur()
            return
        }
        post { waitFramesAndCapture(framesRemaining - 1) }
    }

    private fun resolveBackdropBlur() {
        if (!isAttachedToWindow) {
            return
        }
        if (shouldBlockPageBackdropMutation()) {
            if (liveBlurEnabled) {
                freezeLiveBackdropBlur()
            }
            return
        }

        if (isInsideDialogOverlay()) {
            val activity = FrostOverlayHost.findActivity(context)
            if (activity != null &&
                FrostCardBlurRegistry.isFrozenBackdropDeferred?.invoke(activity) == true
            ) {
                return
            }
            // Machine-status and other panel cards: sample local blur target, not session fullscreen.
            if (hasPanelLocalBlurTarget()) {
                if (ensureLiveBackdropBlur()) {
                    return
                }
                val localLayer = FrostBackdropResolver.findLocalCaptureTarget(this) ?: return
                captureAndApplySnapshotBlur(
                    FrostBackdropResolver.resolveCaptureTargetDrawRoot(localLayer),
                )
                return
            }
            val frozenBackdrop = activity?.let { FrostCardBlurRegistry.getFrozenBackdrop?.invoke(it) }
            if (frozenBackdrop != null && activity != null) {
                val generation = FrostCardBlurRegistry.getFrozenBackdropGeneration?.invoke(activity) ?: 0
                teardownLiveBackdropBlur()
                applyDialogFrozenBackdrop(frozenBackdrop, generation, activity)
                return
            }
            if (ensureLiveBackdropBlur()) {
                return
            }
            post { waitFramesAndCapture(BACKDROP_CAPTURE_FRAME_WAIT) }
            return
        }

        if (ensureLiveBackdropBlur()) {
            return
        }

        val localLayer = FrostBackdropResolver.findLocalCaptureTarget(this)
        val drawRoot = if (localLayer != null) {
            FrostBackdropResolver.resolveCaptureTargetDrawRoot(localLayer)
        } else {
            val resolver = FrostCardBlurRegistry.resolveBackdrop ?: FrostCardBlurRegistry::defaultResolveBackdrop
            resolver(this)?.drawRoot
        } ?: return
        captureAndApplySnapshotBlur(drawRoot)
    }

    private fun hasPanelLocalBlurTarget(): Boolean =
        FrostBackdropResolver.findLocalCaptureTarget(this) != null

    private fun ensureLiveBackdropBlur(): Boolean {
        if (!panelBlurIntensity.usesBackdropBlur() || !drawFillEnabled || !enableBackdropBlur) {
            return false
        }
        if (width <= 0 || height <= 0) {
            return false
        }
        if (liveBlurConfigured && liveBlurEnabled) {
            syncLiveBackdropChrome()
            return true
        }
        val blurTarget = FrostBlurViewSupport.findBlurTarget(this) ?: return false

        val blurView = liveBlurView ?: BlurView(context).also { blur ->
            blur.layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            blur.setBackground(createRoundedClipDrawable())
            staticBackdropLayer.addView(blur, 0)
            liveBlurView = blur
        }

        val overlayColor = panelBlurIntensity.resolveOverlayColorInt(context, panelBlurTint)
        val blurRadius = panelBlurIntensity.blurViewRadiusPx().toFloat()
        val insideDialog = isInsideDialogOverlay()
        val freezeAfterSettle = when {
            hasPanelLocalBlurTarget() -> true
            insideDialog -> localBackdropLocked || pageBackdropFrozenDuringOverlay
            else -> true
        }
        liveBlurEnabled = FrostBlurViewSupport.setupBlurView(
            blurView = blurView,
            blurTarget = blurTarget,
            context = context,
            overlayColor = overlayColor,
            blurRadius = blurRadius,
            freezeAfterSettle = freezeAfterSettle,
        )
        liveBlurConfigured = true
        if (liveBlurEnabled) {
            hideStaticBackdropImage()
            syncLiveBackdropChrome()
            if (!insideDialog || hasPanelLocalBlurTarget()) {
                localBackdropLocked = true
            }
            Log.d(TAG, "live BlurView active radius=$blurRadius local=${hasPanelLocalBlurTarget()}")
        }
        return liveBlurEnabled
    }

    private fun syncLiveBackdropChrome() {
        if (!liveBlurEnabled) {
            return
        }
        liveBlurView?.visibility = VISIBLE
        staticBackdropImage.visibility = GONE
        staticBackdropLayer.visibility = VISIBLE
        chromeView.visibility = GONE
        updateBackdropLayerClip()
        updateRoundedClipOutline()
        val showFill = drawFillEnabled &&
            stackPanelFillWithBlur &&
            panelBlurIntensity.drawsFill() &&
            !shouldSuppressFillUntilBackdrop()
        if (showFill) {
            fillOverlayView.background = PanelFillDrawable.create(
                context,
                resolveCornerRadiusPx(),
            )
            fillOverlayView.alpha = STATIC_BACKDROP_FILL_ALPHA
            fillOverlayView.visibility = VISIBLE
        } else {
            fillOverlayView.background = null
            fillOverlayView.visibility = GONE
        }
    }

    private fun hideStaticBackdropImage() {
        staticBackdropImage.setImageDrawable(null)
        staticBackdropImage.setImageBitmap(null)
        staticBackdropImage.visibility = GONE
        recycleUpscaledBackdrop()
    }

    private fun freezeLiveBackdropBlur() {
        liveBlurView?.setBlurAutoUpdate(false)
    }

    private fun teardownLiveBackdropBlur() {
        liveBlurView?.let { blur ->
            if (blur.parent === staticBackdropLayer) {
                staticBackdropLayer.removeView(blur)
            }
        }
        liveBlurView = null
        liveBlurConfigured = false
        liveBlurEnabled = false
    }

    private fun captureAndApplySnapshotBlur(drawRoot: View) {
        val width = width
        val height = height
        if (width <= 0 || height <= 0) {
            return
        }
        val captureScale = FrostBackdropCapture.BLUR_SCALE_FACTOR
        val overscanPx = snapshotCaptureOverscanPx()
        val blurRadius = panelBlurIntensity.dialogGaussianBlurRadiusPx()
        val passes = panelBlurIntensity.stackBlurPasses()
        val snapshot = withFrostCardsHidden {
            FrostBackdropCapture.captureRegion(
                drawRoot,
                this,
                captureScale,
                overscanPx,
            )
        } ?: return
        val generation = ++captureGeneration
        blurFuture?.cancel(false)
        val onBlurSuccess: (Bitmap?) -> Unit = { blurred ->
            if (blurred == null) {
                if (!snapshot.isRecycled) {
                    snapshot.recycle()
                }
            } else if (!isAttachedToWindow || generation != captureGeneration) {
                if (!blurred.isRecycled) {
                    blurred.recycle()
                }
            } else if (shouldBlockPageBackdropMutation()) {
                if (!blurred.isRecycled) {
                    blurred.recycle()
                }
            } else {
                teardownLiveBackdropBlur()
                if (blurred !== snapshot && !snapshot.isRecycled) {
                    snapshot.recycle()
                }
                val cropped = cropSnapshotBlur(blurred, overscanPx, captureScale)
                if (cropped !== blurred && !blurred.isRecycled) {
                    blurred.recycle()
                }
                applyBackdropBitmap(
                    cropped,
                    FrostBackdropDisplayMode.LOCAL,
                    captureScale,
                )
            }
        }
        val onBlurFailed: () -> Unit = {
            if (!snapshot.isRecycled) {
                snapshot.recycle()
            }
        }
        blurFuture = FrostBackdropBlurRegistry.blurBitmapAsync(
            context.applicationContext,
            snapshot,
            blurRadius,
            passes,
            onSuccess = onBlurSuccess,
            onFailed = onBlurFailed,
        )
    }

    private fun snapshotCaptureOverscanPx(): Int =
        (panelBlurIntensity.blurViewRadiusPx() / 2).coerceIn(8, 16)

    private fun cropSnapshotBlur(bitmap: Bitmap, overscanPx: Int, captureScale: Float): Bitmap {
        if (overscanPx <= 0) {
            return bitmap
        }
        val scaledPad = (overscanPx / captureScale).roundToInt().coerceAtLeast(1)
        val cropWidth = bitmap.width - scaledPad * 2
        val cropHeight = bitmap.height - scaledPad * 2
        if (cropWidth <= 0 || cropHeight <= 0) {
            return bitmap
        }
        return Bitmap.createBitmap(bitmap, scaledPad, scaledPad, cropWidth, cropHeight)
    }

    private inline fun <T> withFrostCardsHidden(block: () -> T): T {
        if (isInsideDialogOverlay() || shouldKeepPageBackdropUntouched()) {
            return block()
        }
        val previousVisibility = visibility
        visibility = INVISIBLE
        try {
            return block()
        } finally {
            visibility = previousVisibility
        }
    }

    private fun isInsideDialogOverlay(): Boolean {
        val overlayRootId = FrostResourceIds.viewId(context, "frost_dialog_root")
        var current: android.view.ViewParent? = parent
        while (current is View) {
            if (current.id == overlayRootId) {
                return true
            }
            current = current.parent
        }
        return false
    }

    /**
     * While a dialog overlay is open, page cards that already have a LOCAL snapshot must not be
     * resampled or swapped to the session [pageFrozenBackdrop] (dialog/keyboard crop source).
     * Initial capture is still allowed so home entry tiles finish rendering under boot self-check.
     */
    private fun shouldBlockPageBackdropMutation(): Boolean {
        if (!hasActiveBackdrop()) {
            return false
        }
        return pageBackdropFrozenDuringOverlay || shouldPreferSessionFrozenBackdrop()
    }

    private fun shouldKeepPageBackdropUntouched(): Boolean = shouldBlockPageBackdropMutation()

    private fun shouldPreferSessionFrozenBackdrop(): Boolean {
        if (isInsideDialogOverlay()) {
            return false
        }
        val activity = FrostOverlayHost.findActivity(context) ?: return false
        return FrostCardBlurRegistry.hasOverlays?.invoke(activity) == true
    }

    private fun applyDialogFrozenBackdrop(
        frozen: Bitmap,
        generation: Int,
        activity: android.app.Activity,
        forceRecrop: Boolean = false,
    ) {
        if (dialogFrozenBackdropLocked &&
            appliedFrozenBackdropGeneration == generation &&
            !forceRecrop
        ) {
            if (backdropDisplayMode == FrostBackdropDisplayMode.FULLSCREEN) {
                updateFullscreenBackdropOffsetIfNeeded()
            }
            return
        }
        val metadata = FrostCardBlurRegistry.getFrozenBackdropFrameMetadata?.invoke(activity)
        if (metadata?.mode == FrostBackdropDisplayMode.FULLSCREEN) {
            applyBackdropBitmap(
                frozen,
                FrostBackdropDisplayMode.FULLSCREEN,
                metadata.scaleFactor,
            )
            dialogFrozenBackdropLocked = true
            appliedFrozenBackdropGeneration = generation
            updateFullscreenBackdropOffsetIfNeeded()
            return
        }
        val anchor = FrostCardBlurRegistry.getFrozenDialogAnchor?.invoke(activity)
        val bitmapToApply: Bitmap
        if (anchor != null && FrostBackdropSnapshot.matchesFrozenAnchor(frozen, anchor)) {
            bitmapToApply = frozen
        } else {
            bitmapToApply = cropFullscreenFrozenToCard(frozen) ?: frozen
        }
        applyBackdropBitmap(
            bitmapToApply,
            FrostBackdropDisplayMode.LOCAL,
            FrostBackdropSnapshot.BLUR_SCALE_FACTOR,
        )
        if (bitmapToApply !== frozen && !bitmapToApply.isRecycled) {
            bitmapToApply.recycle()
        }
        dialogFrozenBackdropLocked = true
        appliedFrozenBackdropGeneration = generation
    }

    private fun cropFullscreenFrozenToCard(frozen: Bitmap): Bitmap? {
        if (frozen.isRecycled || width <= 0 || height <= 0) {
            return null
        }
        val content = rootView.findViewById<ViewGroup>(android.R.id.content) ?: return null
        val contentLoc = IntArray(2)
        val cardLoc = IntArray(2)
        content.getLocationOnScreen(contentLoc)
        getLocationOnScreen(cardLoc)
        return FrostBackdropSnapshot.cropToContentRect(
            frozen,
            cardLoc[0] - contentLoc[0],
            cardLoc[1] - contentLoc[1],
            width,
            height,
        )
    }

    private fun shouldSuppressFillUntilBackdrop(): Boolean {
        if (staticBackdropActive) {
            return false
        }
        if (!isInsideDialogOverlay()) {
            return false
        }
        val activity = FrostOverlayHost.findActivity(context) ?: return false
        return FrostCardBlurRegistry.isFrozenBackdropDeferred?.invoke(activity) == true
    }

    private fun syncBorderForeground() {
        if (!drawBorderEnabled) {
            foreground = null
            return
        }
        val lightTone = panelBlurTint == FrostBlurTint.WARM
        val cornerRadius = if (cornerRadiusPx >= 0f) {
            cornerRadiusPx
        } else {
            FrostDimens.cornerRadiusPx(context)
        }
        borderForeground.borderSpec = PanelBorderPainter.cardBorderSpec(
            context = context,
            gradientCenter = panelBorderGradientCenter,
            lightTone = lightTone,
            cornerRadiusPx = cornerRadius,
        )
        if (foreground !== borderForeground) {
            foreground = borderForeground
        }
    }

    @androidx.compose.runtime.Composable
    private fun FrostCardChrome() {
        SideEffect { syncBorderForeground() }
        val cornerRadius = frostCornerRadiusDp(cornerRadiusPx)
        val lightTone = panelBlurTint == FrostBlurTint.WARM
        val effectiveDrawFill = drawFillEnabled && !shouldSuppressFillUntilBackdrop()
        FrostCard(
            modifier = Modifier.fillMaxSize(),
            cornerRadius = cornerRadius,
            borderGradientCenter = panelBorderGradientCenter,
            drawFill = effectiveDrawFill,
            drawBorder = false,
            lightTone = lightTone,
            stackPanelFillWithBlur = stackPanelFillWithBlur,
            blurIntensity = panelBlurIntensity,
            blurTint = panelBlurTint,
            staticBackdropActive = staticBackdropActive,
            backdropBitmap = backdropBitmap,
            backdropDisplayMode = backdropDisplayMode,
            fullscreenBackdropOffsetX = fullscreenBackdropOffsetX,
            fullscreenBackdropOffsetY = fullscreenBackdropOffsetY,
            localCaptureScaleFactor = localCaptureScaleFactor,
            contentPadding = 0.dp,
        ) {
            // Chrome-only layer; XML/Java content lives in [contentHostLayout] above this ComposeView.
        }
    }
}
