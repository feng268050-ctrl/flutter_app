package com.lasercyber.lws.frostui.card.interop

import android.content.Context
import android.util.AttributeSet
import android.widget.LinearLayout
import com.lasercyber.lws.frostui.border.BorderGradientCenter
import com.lasercyber.lws.frostui.border.FrostBlurIntensity
import com.lasercyber.lws.frostui.border.FrostBlurTint
import com.lasercyber.lws.ui.R

internal data class FrostCardAttrs(
    val borderGradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
    val drawFill: Boolean = true,
    val drawBorder: Boolean = true,
    val stackPanelFillWithBlur: Boolean = false,
    val enableBackdropBlur: Boolean = true,
    val blurTint: FrostBlurTint = FrostBlurTint.DARK,
    val blurIntensity: FrostBlurIntensity = FrostBlurIntensity.MIDDLE,
    val blurTintExplicit: Boolean = false,
    val blurIntensityExplicit: Boolean = false,
    val drawFillExplicit: Boolean = false,
    val cornerRadiusPx: Float = -1f,
    val contentOrientation: Int = LinearLayout.VERTICAL,
    val contentGravity: Int = 0,
) {
    companion object {
        private const val BACKGROUND_FROSTED = "frosted"
        private const val BACKGROUND_TRANSPARENT = "transparent"

        fun read(context: Context, attrs: AttributeSet?, defStyleAttr: Int): FrostCardAttrs {
            if (attrs == null && defStyleAttr == 0) {
                return FrostCardAttrs()
            }
            val styled = context.obtainStyledAttributes(
                attrs,
                R.styleable.FrostCard,
                defStyleAttr,
                0,
            )
            return try {
                val drawFillExplicit = styled.hasValue(R.styleable.FrostCard_frostedGlassDrawFill)
                var drawFill = styled.getBoolean(R.styleable.FrostCard_frostedGlassDrawFill, true)
                val drawBorder = styled.getBoolean(R.styleable.FrostCard_frostedGlassDrawBorder, true)
                val stackPanelFillWithBlur = styled.getBoolean(
                    R.styleable.FrostCard_frostedGlassStackPanelFill,
                    false,
                )
                val enableBackdropBlur = styled.getBoolean(
                    R.styleable.FrostCard_frostedGlassBackdropBlur,
                    true,
                )
                var blurTint = FrostBlurTint.DARK
                var blurTintExplicit = false
                if (styled.hasValue(R.styleable.FrostCard_frostedGlassBlurTint)) {
                    blurTint = FrostBlurTint.fromIndex(
                        styled.getInt(R.styleable.FrostCard_frostedGlassBlurTint, 0),
                    )
                    blurTintExplicit = true
                }
                var blurIntensity = FrostBlurIntensity.MIDDLE
                var blurIntensityExplicit = false
                if (styled.hasValue(R.styleable.FrostCard_frostedGlassBlurIntensity)) {
                    blurIntensity = FrostBlurIntensity.fromXmlValue(
                        styled.getInt(R.styleable.FrostCard_frostedGlassBlurIntensity, 1),
                    )
                    blurIntensityExplicit = true
                } else {
                    val cardBackground = styled.getString(R.styleable.FrostCard_cardBackground)
                    if (cardBackground != null) {
                        blurIntensity = resolveCardBackground(cardBackground, blurIntensity)
                        blurIntensityExplicit = cardBackground.equals(
                            BACKGROUND_TRANSPARENT,
                            ignoreCase = true,
                        )
                    } else if (drawFillExplicit) {
                        drawFill = styled.getBoolean(R.styleable.FrostCard_frostedGlassDrawFill, drawFill)
                    }
                }
                if (blurIntensityExplicit && !drawFillExplicit) {
                    drawFill = blurIntensity.drawsFill()
                }
                val borderGradientCenter = BorderGradientCenter.fromXmlValue(
                    styled.getString(R.styleable.FrostCard_borderGradientCenter),
                )
                val cornerRadiusPx = if (styled.hasValue(R.styleable.FrostCard_frostedGlassCornerRadius)) {
                    styled.getDimension(R.styleable.FrostCard_frostedGlassCornerRadius, -1f)
                } else {
                    -1f
                }
                val contentOrientation = styled.getInt(
                    R.styleable.FrostCard_android_orientation,
                    LinearLayout.VERTICAL,
                )
                val contentGravity = styled.getInt(R.styleable.FrostCard_android_gravity, 0)
                FrostCardAttrs(
                    borderGradientCenter = borderGradientCenter,
                    drawFill = drawFill,
                    drawBorder = drawBorder,
                    stackPanelFillWithBlur = stackPanelFillWithBlur,
                    enableBackdropBlur = enableBackdropBlur,
                    blurTint = blurTint,
                    blurIntensity = blurIntensity,
                    blurTintExplicit = blurTintExplicit,
                    blurIntensityExplicit = blurIntensityExplicit,
                    drawFillExplicit = drawFillExplicit,
                    cornerRadiusPx = cornerRadiusPx,
                    contentOrientation = contentOrientation,
                    contentGravity = contentGravity,
                )
            } finally {
                styled.recycle()
            }
        }

        internal fun resolveCardBackground(
            cardBackground: String,
            current: FrostBlurIntensity,
        ): FrostBlurIntensity = when {
            cardBackground.equals(BACKGROUND_TRANSPARENT, ignoreCase = true) ->
                FrostBlurIntensity.TRANSPARENT
            cardBackground.equals(BACKGROUND_FROSTED, ignoreCase = true) &&
                current == FrostBlurIntensity.TRANSPARENT ->
                FrostBlurIntensity.MIDDLE
            else -> current
        }
    }
}
