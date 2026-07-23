package com.lasercyber.lws.frostui.button.interop

import android.content.Context
import android.util.AttributeSet
import androidx.compose.ui.unit.Dp
import com.lasercyber.lws.frostui.border.BorderGradientCenter
import com.lasercyber.lws.frostui.button.FrostButtonShape
import com.lasercyber.lws.frostui.button.FrostButtonSize
import com.lasercyber.lws.frostui.button.FrostButtonVariant
import com.lasercyber.lws.ui.R

internal data class FrostButtonAttrs(
    val variant: FrostButtonVariant = FrostButtonVariant.DEFAULT,
    val size: FrostButtonSize = FrostButtonSize.DEFAULT,
    val shape: FrostButtonShape = FrostButtonShape.ROUNDED,
    val borderGradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
    val borderRadiusPx: Float? = null,
    val text: CharSequence = "",
    val enabled: Boolean = true,
    val textColorArgb: Int? = null,
    val textSizePx: Float? = null,
    val drawableStartResId: Int = 0,
    val drawableEndResId: Int = 0,
    val drawablePaddingPx: Int = 0,
    val drawableTintArgb: Int? = null,
    val paddingLeftPx: Int? = null,
    val paddingTopPx: Int? = null,
    val paddingRightPx: Int? = null,
    val paddingBottomPx: Int? = null,
    val minWidthPx: Int = 0,
    val singleLine: Boolean = true,
    val allCaps: Boolean = false,
) {
    companion object {
        fun read(context: Context, attrs: AttributeSet?, defStyleAttr: Int, defStyleRes: Int = R.style.FrostButton): FrostButtonAttrs {
            if (attrs == null && defStyleAttr == 0 && defStyleRes == 0) {
                return FrostButtonAttrs()
            }
            val styled = context.obtainStyledAttributes(
                attrs,
                R.styleable.FrostButton,
                defStyleAttr,
                defStyleRes,
            )
            return try {
                val variant = variantFromXml(
                    styled.getString(R.styleable.FrostButton_frostedGlassButtonVariant),
                )
                val size = sizeFromXml(
                    styled.getString(R.styleable.FrostButton_frostedGlassButtonSize),
                )
                val shape = shapeFromXml(
                    styled.getString(R.styleable.FrostButton_frostedGlassButtonShape),
                )
                val borderGradientCenter = BorderGradientCenter.fromXmlValue(
                    styled.getString(R.styleable.FrostButton_borderGradientCenter),
                )
                val borderRadiusPx = if (styled.hasValue(R.styleable.FrostButton_borderRadius)) {
                    styled.getDimension(R.styleable.FrostButton_borderRadius, 0f)
                } else {
                    null
                }
                val text = styled.getText(R.styleable.FrostButton_android_text)?.toString().orEmpty()
                val enabled = styled.getBoolean(R.styleable.FrostButton_android_enabled, true)
                val textSizePx = if (styled.hasValue(R.styleable.FrostButton_android_textSize)) {
                    styled.getDimension(R.styleable.FrostButton_android_textSize, 0f)
                } else {
                    null
                }
                val drawableStartResId = styled.getResourceId(
                    R.styleable.FrostButton_android_drawableStart,
                    0,
                )
                val drawableEndResId = styled.getResourceId(
                    R.styleable.FrostButton_android_drawableEnd,
                    0,
                )
                val drawablePaddingPx = if (styled.hasValue(R.styleable.FrostButton_android_drawablePadding)) {
                    styled.getDimensionPixelSize(R.styleable.FrostButton_android_drawablePadding, 0)
                } else {
                    0
                }
                val drawableTintArgb = if (styled.hasValue(R.styleable.FrostButton_drawableTint)) {
                    styled.getColor(R.styleable.FrostButton_drawableTint, 0)
                } else {
                    null
                }
                val paddingLeftPx = readHorizontalPaddingStart(styled)
                val paddingRightPx = readHorizontalPaddingEnd(styled)
                val paddingTopPx = readVerticalPaddingTop(styled)
                val paddingBottomPx = readVerticalPaddingBottom(styled)
                val minWidthPx = if (styled.hasValue(R.styleable.FrostButton_android_minWidth)) {
                    styled.getDimensionPixelSize(R.styleable.FrostButton_android_minWidth, 0)
                } else {
                    0
                }
                val singleLine = styled.getBoolean(R.styleable.FrostButton_android_singleLine, true)
                val allCaps = if (styled.hasValue(R.styleable.FrostButton_android_textAllCaps)) {
                    styled.getBoolean(R.styleable.FrostButton_android_textAllCaps, false)
                } else {
                    false
                }
                FrostButtonAttrs(
                    variant = variant,
                    size = size,
                    shape = shape,
                    borderGradientCenter = borderGradientCenter,
                    borderRadiusPx = borderRadiusPx,
                    text = text,
                    enabled = enabled,
                    // Match legacy FrostedGlassButton: variant drives label color at inflation;
                    // callers override via setTextColor() (e.g. warn dialog orange/red labels).
                    textColorArgb = null,
                    textSizePx = textSizePx,
                    drawableStartResId = drawableStartResId,
                    drawableEndResId = drawableEndResId,
                    drawablePaddingPx = drawablePaddingPx,
                    drawableTintArgb = drawableTintArgb,
                    paddingLeftPx = paddingLeftPx,
                    paddingTopPx = paddingTopPx,
                    paddingRightPx = paddingRightPx,
                    paddingBottomPx = paddingBottomPx,
                    minWidthPx = minWidthPx,
                    singleLine = singleLine,
                    allCaps = allCaps,
                )
            } finally {
                styled.recycle()
            }
        }

        private fun readHorizontalPaddingStart(styled: android.content.res.TypedArray): Int? {
            if (styled.hasValue(R.styleable.FrostButton_android_paddingStart)) {
                return styled.getDimensionPixelSize(R.styleable.FrostButton_android_paddingStart, 0)
            }
            if (styled.hasValue(R.styleable.FrostButton_android_paddingLeft)) {
                return styled.getDimensionPixelSize(R.styleable.FrostButton_android_paddingLeft, 0)
            }
            return readUniformPadding(styled)
        }

        private fun readHorizontalPaddingEnd(styled: android.content.res.TypedArray): Int? {
            if (styled.hasValue(R.styleable.FrostButton_android_paddingEnd)) {
                return styled.getDimensionPixelSize(R.styleable.FrostButton_android_paddingEnd, 0)
            }
            if (styled.hasValue(R.styleable.FrostButton_android_paddingRight)) {
                return styled.getDimensionPixelSize(R.styleable.FrostButton_android_paddingRight, 0)
            }
            return readUniformPadding(styled)
        }

        private fun readVerticalPaddingTop(styled: android.content.res.TypedArray): Int? {
            if (styled.hasValue(R.styleable.FrostButton_android_paddingTop)) {
                return styled.getDimensionPixelSize(R.styleable.FrostButton_android_paddingTop, 0)
            }
            return readUniformPadding(styled)
        }

        private fun readVerticalPaddingBottom(styled: android.content.res.TypedArray): Int? {
            if (styled.hasValue(R.styleable.FrostButton_android_paddingBottom)) {
                return styled.getDimensionPixelSize(R.styleable.FrostButton_android_paddingBottom, 0)
            }
            return readUniformPadding(styled)
        }

        /** Legacy TextView: android:padding applies to all sides unless overridden per edge. */
        private fun readUniformPadding(styled: android.content.res.TypedArray): Int? =
            if (styled.hasValue(R.styleable.FrostButton_android_padding)) {
                styled.getDimensionPixelSize(R.styleable.FrostButton_android_padding, 0)
            } else {
                null
            }

        private fun variantFromXml(value: String?): FrostButtonVariant = when (value) {
            "primary" -> FrostButtonVariant.PRIMARY
            "secondary" -> FrostButtonVariant.SECONDARY
            "light" -> FrostButtonVariant.LIGHT
            else -> FrostButtonVariant.DEFAULT
        }

        private fun sizeFromXml(value: String?): FrostButtonSize = when (value) {
            "small" -> FrostButtonSize.SMALL
            else -> FrostButtonSize.DEFAULT
        }

        private fun shapeFromXml(value: String?): FrostButtonShape = when (value) {
            "rectangle" -> FrostButtonShape.RECTANGLE
            else -> FrostButtonShape.ROUNDED
        }

        fun borderRadiusDp(borderRadiusPx: Float?, context: Context): Dp? =
            borderRadiusPx?.let { px ->
                Dp(px / context.resources.displayMetrics.density)
            }
    }
}
