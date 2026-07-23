package com.lasercyber.lws.frostui.blur

import android.content.Context
import android.graphics.Bitmap
import com.lasercyber.lws.frostui.dialog.FrostBackdropBlurRegistry
import java.util.concurrent.Future
import kotlin.math.min

/** RenderScript bitmap blur via [FrostBackdropBlurRegistry] (wired in [FrostUiDialogBridge]). */
object FrostBitmapBlur {

    const val DEFAULT_RADIUS = 25
    const val CLOCK_BLUR_PASSES = 2

    @JvmStatic
    @JvmOverloads
    fun blur(
        context: Context,
        bitmap: Bitmap,
        blurRadius: Int = DEFAULT_RADIUS,
        passes: Int = 1,
        @Suppress("UNUSED_PARAMETER") sampleFactor: Float = 1f,
    ): Bitmap? {
        val radius = min(blurRadius, 25)
        if (radius <= 0) {
            return bitmap
        }
        var result = FrostBackdropBlurRegistry.blurBitmap(
            context.applicationContext,
            bitmap,
            radius,
            1,
        ) ?: return null
        repeat(passes - 1) {
            val next = FrostBackdropBlurRegistry.blurBitmap(
                context.applicationContext,
                result,
                radius,
                1,
            ) ?: return result
            if (next !== result && result !== bitmap && !result.isRecycled) {
                result.recycle()
            }
            result = next
        }
        return result
    }

    @JvmStatic
    @JvmOverloads
    fun blurAsync(
        context: Context,
        bitmap: Bitmap,
        blurRadius: Int = DEFAULT_RADIUS,
        passes: Int = 1,
        @Suppress("UNUSED_PARAMETER") sampleFactor: Float = 1f,
        onSuccess: (Bitmap) -> Unit,
        onFailed: () -> Unit,
    ): Future<*> = FrostBackdropBlurRegistry.blurBitmapAsync(
        context.applicationContext,
        bitmap,
        min(blurRadius, 25),
        passes,
        onSuccess = { blurred ->
            if (blurred != null) {
                onSuccess(blurred)
            } else {
                onFailed()
            }
        },
        onFailed = onFailed,
    )
}
