package com.lasercyber.lws.frostui.card

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import com.lasercyber.lws.frostui.blur.FrostBackdropDisplay
import com.lasercyber.lws.frostui.blur.FrostBackdropDisplayMode
import com.lasercyber.lws.frostui.border.FrostBlurIntensity
import com.lasercyber.lws.frostui.border.FrostBlurTint

/** Slight upscale so blurred pixels bleed past rounded-rect clips at dialog corners. */
private const val BLUR_CORNER_BLEED_SCALE = 1.06f

/**
 * Compose backdrop blur layer from a pre-blurred snapshot bitmap.
 * Capture and blur happen in [interop.FrostCardView] via live BlurView; bitmap fallback uses RenderScript registry.
 */
@Composable
fun FrostSnapshotBlur(
    bitmap: android.graphics.Bitmap?,
    blurIntensity: FrostBlurIntensity,
    blurTint: FrostBlurTint,
    displayMode: FrostBackdropDisplayMode = FrostBackdropDisplayMode.LOCAL,
    fullscreenOffsetX: Float = 0f,
    fullscreenOffsetY: Float = 0f,
    captureScaleFactor: Float = FrostBackdropDisplay.SCALE_FACTOR,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val overlayColor = blurIntensity.resolveOverlayColor(context, blurTint)

    Box(modifier = modifier) {
        val imageBitmap = remember(bitmap, context) {
            bitmap?.takeIf { !it.isRecycled }?.also {
                it.density = context.resources.displayMetrics.densityDpi
            }?.asImageBitmap()
        }
        if (imageBitmap != null) {
            when (displayMode) {
                FrostBackdropDisplayMode.FULLSCREEN -> {
                    // Match ImageView MATCH_PARENT + MATRIX inside the card viewport.
                    Image(
                        bitmap = imageBitmap,
                        contentDescription = null,
                        modifier = Modifier
                            .fillMaxSize()
                            .graphicsLayer {
                                scaleX = captureScaleFactor
                                scaleY = captureScaleFactor
                                translationX = fullscreenOffsetX
                                translationY = fullscreenOffsetY
                                transformOrigin = TransformOrigin(0f, 0f)
                            },
                        contentScale = ContentScale.None,
                        filterQuality = FilterQuality.Low,
                        colorFilter = ColorFilter.tint(overlayColor, BlendMode.SrcAtop),
                    )
                }
                FrostBackdropDisplayMode.LOCAL -> {
                    Image(
                        bitmap = imageBitmap,
                        contentDescription = null,
                        modifier = Modifier
                            .fillMaxSize()
                            .graphicsLayer {
                                scaleX = BLUR_CORNER_BLEED_SCALE
                                scaleY = BLUR_CORNER_BLEED_SCALE
                                transformOrigin = TransformOrigin(0f, 0f)
                            },
                        contentScale = ContentScale.FillBounds,
                        colorFilter = ColorFilter.tint(overlayColor, BlendMode.SrcAtop),
                    )
                }
            }
        }
        content()
    }
}
