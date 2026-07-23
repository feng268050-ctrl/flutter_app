package com.lasercyber.lws.frostui.button.interop

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import androidx.annotation.StringRes
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.AbstractComposeView
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.frostui.border.FrostResources
import com.lasercyber.lws.frostui.button.FrostButton
import com.lasercyber.lws.frostui.button.FrostButtonVariant
import com.lasercyber.lws.ui.R

/**
 * XML/Java bridge embedding [FrostButton]. Drop-in replacement for legacy FrostedGlassButton.
 *
 * Interop contract: View shell carries LayoutParams + id/click; [FrostButtonAttrs] reads frost
 * styling once; [FrostButton] renders in Compose. Size: Android measures the shell from XML
 * LayoutParams; Compose only [fillMaxWidth]/[fillMaxHeight] when an axis is not wrap_content,
 * plus [android:minWidth] when set.
 */
class FrostButtonView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = R.attr.frostButtonStyle,
) : AbstractComposeView(context, null, 0) {

    private val xmlAttrs = attrs
    private val xmlDefStyleAttr = defStyleAttr
    private val initial = FrostButtonAttrs.read(context, attrs, defStyleAttr)

    private var buttonLabel by mutableStateOf(initial.text.toString())
    private var buttonVariant by mutableStateOf(initial.variant)
    private var buttonShape by mutableStateOf(initial.shape)
    private var buttonSize by mutableStateOf(initial.size)
    private var borderGradientCenter by mutableStateOf(initial.borderGradientCenter)
    private var borderRadiusPx by mutableStateOf(initial.borderRadiusPx)
    private var frostEnabled by mutableStateOf(initial.enabled)
    private var textColorArgb by mutableStateOf(initial.textColorArgb)
    private var textSizePx by mutableStateOf(initial.textSizePx)
    private var drawableStartResId by mutableStateOf(initial.drawableStartResId)
    private var drawableEndResId by mutableStateOf(initial.drawableEndResId)
    private var drawablePaddingPx by mutableStateOf(initial.drawablePaddingPx)
    private var drawableTintArgb by mutableStateOf(initial.drawableTintArgb)
    private var contentPaddingLeftPx by mutableStateOf(initial.paddingLeftPx)
    private var contentPaddingTopPx by mutableStateOf(initial.paddingTopPx)
    private var contentPaddingRightPx by mutableStateOf(initial.paddingRightPx)
    private var contentPaddingBottomPx by mutableStateOf(initial.paddingBottomPx)
    private var styledMinWidthPx by mutableIntStateOf(initial.minWidthPx)
    private var labelAllCaps by mutableStateOf(initial.allCaps)
    private var labelSingleLine by mutableStateOf(initial.singleLine)

    init {
        applyViewShellAttrs(xmlAttrs, xmlDefStyleAttr)
        bindDeclaredOnClickFromAttrs(xmlAttrs)
        isClickable = true
        isFocusable = true
        applyMinimumWidthHint()
    }

    /** View shell only: id / visibility / tag — not frost styling. */
    private fun applyViewShellAttrs(attrs: AttributeSet?, defStyleAttr: Int) {
        if (attrs == null) {
            return
        }
        val shellAttrs = intArrayOf(
            android.R.attr.id,
            android.R.attr.tag,
            android.R.attr.visibility,
        )
        val styled = context.obtainStyledAttributes(attrs, shellAttrs, defStyleAttr, 0)
        try {
            val viewId = styled.getResourceId(0, View.NO_ID)
            if (viewId != View.NO_ID) {
                id = viewId
            }
            if (styled.hasValue(1)) {
                tag = styled.getText(1)
            }
            if (styled.hasValue(2)) {
                visibility = styled.getInt(2, visibility)
            }
        } finally {
            styled.recycle()
        }
    }

    /**
     * XML [android.R.attr.onClick] is bound by LayoutInflater after construction, but we also
     * wire it here so interop shells that omit attrs on [AbstractComposeView] still work.
     */
    private fun bindDeclaredOnClickFromAttrs(attrs: AttributeSet?) {
        if (attrs == null) {
            return
        }
        val handlerName = attrs.getAttributeValue(
            "http://schemas.android.com/apk/res/android",
            "onClick",
        ) ?: return
        val activity = resolveHostActivity() ?: return
        setOnClickListener(DeclaredOnClickListener(activity, handlerName))
    }

    private fun resolveHostActivity(): android.app.Activity? {
        var ctx = context
        while (ctx is android.content.ContextWrapper) {
            if (ctx is android.app.Activity) {
                return ctx
            }
            ctx = ctx.baseContext
        }
        return ctx as? android.app.Activity
    }

    private class DeclaredOnClickListener(
        private val activity: android.app.Activity,
        private val methodName: String,
    ) : View.OnClickListener {
        override fun onClick(view: View) {
            try {
                val method = activity.javaClass.getMethod(methodName, View::class.java)
                method.invoke(activity, view)
            } catch (_: ReflectiveOperationException) {
                // Match framework DeclaredOnClickListener: ignore missing handlers.
            }
        }
    }

    /** Imperative API (e.g. dialog code); forwarded to Compose, never kept on the View shell. */
    override fun setPadding(left: Int, top: Int, right: Int, bottom: Int) {
        contentPaddingLeftPx = left
        contentPaddingTopPx = top
        contentPaddingRightPx = right
        contentPaddingBottomPx = bottom
        super.setPadding(0, 0, 0, 0)
    }

    override fun setLayoutParams(params: ViewGroup.LayoutParams?) {
        super.setLayoutParams(params)
        applyMinimumWidthHint()
    }

    /** [android:minWidth] / dialog code — width only; height comes from LayoutParams. */
    private fun applyMinimumWidthHint() {
        val lp = layoutParams
        val fillsWidth = lp != null && FrostButtonMeasure.shouldFillWidth(lp)
        minimumWidth = if (!fillsWidth && styledMinWidthPx > 0) styledMinWidthPx else 0
    }

    private fun layoutFillsWidth(): Boolean {
        val lp = layoutParams ?: return false
        return FrostButtonMeasure.shouldFillWidth(lp)
    }

    private fun layoutFillsHeight(): Boolean {
        val lp = layoutParams ?: return false
        return FrostButtonMeasure.shouldFillHeight(lp)
    }

    private fun styledMinWidthDp(density: androidx.compose.ui.unit.Density): androidx.compose.ui.unit.Dp? {
        if (styledMinWidthPx <= 0 || layoutFillsWidth()) {
            return null
        }
        return with(density) { (styledMinWidthPx / resources.displayMetrics.density).dp }
    }

    fun setLabel(text: String) {
        buttonLabel = formatLabel(text)
    }

    fun setText(text: CharSequence?) {
        buttonLabel = formatLabel(text?.toString().orEmpty())
    }

    fun setText(@StringRes resId: Int) {
        buttonLabel = formatLabel(context.getString(resId))
    }

    /** Dialog code (e.g. [FrostPromptDialogController]) may set min width after inflation. */
    fun applyExternalMinimumWidth(minWidthPx: Int) {
        styledMinWidthPx = minWidthPx
        applyMinimumWidthHint()
    }

    fun getText(): CharSequence = buttonLabel

    fun setSingleLine(singleLine: Boolean) {
        labelSingleLine = singleLine
    }

    fun setAllCaps(allCaps: Boolean) {
        labelAllCaps = allCaps
        buttonLabel = formatLabel(buttonLabel)
    }

    fun setCompoundDrawablesWithIntrinsicBounds(left: Int, top: Int, right: Int, bottom: Int) {
        drawableStartResId = left
        drawableEndResId = right
    }

    private fun formatLabel(text: String): String =
        if (labelAllCaps) text.uppercase() else text

    fun setVariant(variant: FrostButtonVariant) {
        buttonVariant = variant
    }

    fun setButtonEnabled(enabled: Boolean) {
        frostEnabled = enabled
    }

    override fun setEnabled(enabled: Boolean) {
        super.setEnabled(enabled)
        frostEnabled = enabled
    }

    fun setTextColor(color: Int) {
        textColorArgb = color
    }

    /** Matches legacy TextView.setTextSize(TypedValue.COMPLEX_UNIT_PX, px). */
    fun setTextSize(unit: Int, size: Float) {
        textSizePx = when (unit) {
            android.util.TypedValue.COMPLEX_UNIT_PX -> size
            android.util.TypedValue.COMPLEX_UNIT_SP ->
                size * resources.displayMetrics.scaledDensity
            android.util.TypedValue.COMPLEX_UNIT_DIP ->
                size * resources.displayMetrics.density
            else -> size
        }
    }

    @Composable
    override fun Content() {
        val density = LocalDensity.current
        val cornerRadius = FrostButtonAttrs.borderRadiusDp(borderRadiusPx, context)
        val horizontalPaddingStart = contentPaddingLeftPx.toPaddingDp(density)
        val horizontalPaddingEnd = contentPaddingRightPx.toPaddingDp(density)
        val verticalPaddingTop = contentPaddingTopPx.toPaddingDp(density)
        val verticalPaddingBottom = contentPaddingBottomPx.toPaddingDp(density)
        val textColorOverride = textColorArgb?.let { androidx.compose.ui.graphics.Color(it) }
        val textSize = textSizePx?.let { px ->
            FrostResources.dimensionPxToSp(context, px)
        }
        val drawablePadding = with(density) {
            (drawablePaddingPx / resources.displayMetrics.density).dp.coerceAtLeast(0.dp)
        }
        val drawableTint = drawableTintArgb?.let { androidx.compose.ui.graphics.Color(it) }
        val fillWidth = layoutFillsWidth()
        val fillHeight = layoutFillsHeight()
        val styledMinWidth = styledMinWidthDp(density)
        val buttonEnabled = frostEnabled && isEnabled
        val drawableStart = rememberFrostButtonDrawablePainter(drawableStartResId, buttonEnabled)
        val drawableEnd = rememberFrostButtonDrawablePainter(drawableEndResId, buttonEnabled)

        var buttonModifier: Modifier = Modifier
        if (fillWidth) {
            buttonModifier = buttonModifier.fillMaxWidth()
        }
        if (fillHeight) {
            buttonModifier = buttonModifier.fillMaxHeight()
        }

        FrostButton(
            text = buttonLabel,
            onClick = {
                if (frostEnabled && isEnabled) {
                    performClick()
                }
            },
            modifier = buttonModifier,
            variant = buttonVariant,
            shape = buttonShape,
            size = buttonSize,
            minWidth = styledMinWidth,
            enabled = buttonEnabled,
            borderGradientCenter = borderGradientCenter,
            cornerRadius = cornerRadius,
            horizontalPaddingStart = horizontalPaddingStart,
            horizontalPaddingEnd = horizontalPaddingEnd,
            verticalPaddingTop = verticalPaddingTop,
            verticalPaddingBottom = verticalPaddingBottom,
            textColorOverride = textColorOverride,
            textSize = textSize,
            singleLine = labelSingleLine,
            drawableStart = drawableStart,
            drawableEnd = drawableEnd,
            drawablePadding = drawablePadding,
            drawableTint = drawableTint,
        )
    }

    private fun Int?.toPaddingDp(density: androidx.compose.ui.unit.Density): androidx.compose.ui.unit.Dp? =
        this?.let { px ->
            with(density) { (px / resources.displayMetrics.density).dp }
        }
}

/** Ripple-only overlay for glass tiles backed by [com.lasercyber.lws.frostui.card.interop.FrostCardView]. */
object FrostButtonTileRipple {

    @JvmStatic
    fun createTileRippleForeground(cornerRadiusPx: Float): RippleDrawable {
        val rippleColor = android.content.res.ColorStateList.valueOf(Color.argb(0x3D, 255, 255, 255))
        val mask = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(Color.WHITE)
            this.cornerRadius = cornerRadiusPx
        }
        return RippleDrawable(rippleColor, null, mask)
    }
}
