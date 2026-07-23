package com.lasercyber.lws.frostui.card

import android.graphics.Bitmap
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.frostui.blur.FrostBackdropDisplay
import com.lasercyber.lws.frostui.blur.FrostBackdropDisplayMode
import com.lasercyber.lws.frostui.border.BorderGradientCenter
import com.lasercyber.lws.frostui.border.FrostBlurIntensity
import com.lasercyber.lws.frostui.border.FrostBlurTint
import com.lasercyber.lws.frostui.border.FrostDimens
import com.lasercyber.lws.frostui.border.PanelBorderPainter
import com.lasercyber.lws.frostui.border.frostPanelBorder
import com.lasercyber.lws.frostui.border.frostPanelFill

@Composable
fun FrostCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = FrostDimens.cornerRadius(LocalContext.current),
    borderGradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
    drawFill: Boolean = true,
    drawBorder: Boolean = true,
    lightTone: Boolean = false,
    stackPanelFillWithBlur: Boolean = false,
    staticBackdropActive: Boolean = false,
    backdropBitmap: Bitmap? = null,
    backdropDisplayMode: FrostBackdropDisplayMode = FrostBackdropDisplayMode.LOCAL,
    fullscreenBackdropOffsetX: Float = 0f,
    fullscreenBackdropOffsetY: Float = 0f,
    localCaptureScaleFactor: Float = FrostBackdropDisplay.SCALE_FACTOR,
    blurIntensity: FrostBlurIntensity = FrostBlurIntensity.MIDDLE,
    blurTint: FrostBlurTint = FrostBlurTint.DARK,
    contentPadding: Dp = FrostDimens.contentPadding(LocalContext.current),
    content: @Composable () -> Unit,
) {
    val shape = RoundedCornerShape(cornerRadius)
    val backdropBlurActive = blurIntensity.usesBackdropBlur() && staticBackdropActive
    // Dialog FULLSCREEN blur is rendered by native ImageView in [interop.FrostCardView].
    val composeBackdropBitmap = if (
        backdropBlurActive && backdropDisplayMode == FrostBackdropDisplayMode.LOCAL
    ) {
        backdropBitmap
    } else {
        null
    }
    val showComposeFill = drawFill &&
        blurIntensity.drawsFill() &&
        (!backdropBlurActive || stackPanelFillWithBlur) &&
        !blurIntensity.usesSolidFill()
    val showSolidFill = drawFill && blurIntensity.usesSolidFill()
    val context = LocalContext.current
    val density = LocalDensity.current
    val cornerRadiusPx = with(density) { cornerRadius.toPx() }
    val borderSpec = PanelBorderPainter.cardBorderSpec(
        context = context,
        gradientCenter = borderGradientCenter,
        lightTone = lightTone,
        cornerRadiusPx = cornerRadiusPx,
    )

    Box(
        modifier = modifier.clip(shape),
    ) {
        FrostSnapshotBlur(
            bitmap = composeBackdropBitmap,
            blurIntensity = blurIntensity,
            blurTint = blurTint,
            displayMode = backdropDisplayMode,
            fullscreenOffsetX = fullscreenBackdropOffsetX,
            fullscreenOffsetY = fullscreenBackdropOffsetY,
            captureScaleFactor = localCaptureScaleFactor,
            modifier = Modifier.fillMaxSize(),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .then(
                        if (showComposeFill || showSolidFill) {
                            Modifier.frostPanelFill(
                                lightTone = lightTone,
                                solid = showSolidFill,
                                cornerRadius = cornerRadius,
                            )
                        } else {
                            Modifier
                        },
                    )
                    .then(
                        if (drawBorder) {
                            Modifier.frostPanelBorder(spec = borderSpec)
                        } else {
                            Modifier
                        },
                    )
                    .padding(contentPadding),
            ) {
                content()
            }
        }
    }
}

@Composable
fun frostCornerRadiusDp(cornerRadiusPx: Float): Dp {
    val context = LocalContext.current
    val density = LocalDensity.current
    return if (cornerRadiusPx >= 0f) {
        with(density) { cornerRadiusPx.toDp() }
    } else {
        FrostDimens.cornerRadius(context)
    }
}
