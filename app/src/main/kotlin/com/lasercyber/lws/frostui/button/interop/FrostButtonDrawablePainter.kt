package com.lasercyber.lws.frostui.button.interop

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import androidx.annotation.DrawableRes
import androidx.appcompat.content.res.AppCompatResources
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.platform.LocalContext
import kotlin.math.roundToInt

/**
 * Legacy [android.widget.TextView] compound drawables may be layer-list / selector wrappers
 * (e.g. engineer reset icons, [btn_icon_fixed_size]). Compose [painterResource] only supports
 * plain vector + raster assets, so interop always rasterizes like TextView would draw them.
 */
@Composable
internal fun rememberFrostButtonDrawablePainter(
    @DrawableRes resId: Int,
    enabled: Boolean,
): Painter? {
    if (resId == 0) {
        return null
    }
    val context = LocalContext.current
    return remember(resId, enabled) {
        rasterizeDrawableToPainter(context, resId, enabled)
    }
}

private fun rasterizeDrawableToPainter(
    context: Context,
    @DrawableRes resId: Int,
    enabled: Boolean,
): Painter? {
    val drawable = AppCompatResources.getDrawable(context, resId)?.constantState?.newDrawable()?.mutate()
        ?: return null
    drawable.setState(
        intArrayOf(
            if (enabled) android.R.attr.state_enabled else -android.R.attr.state_enabled,
        ),
    )
    val (width, height) = resolveRasterSize(context, drawable)
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    Canvas(bitmap).apply {
        drawable.setBounds(0, 0, width, height)
        drawable.draw(this)
    }
    return BitmapPainter(bitmap.asImageBitmap())
}

private fun resolveRasterSize(context: Context, drawable: Drawable): Pair<Int, Int> {
    var width = drawable.intrinsicWidth
    var height = drawable.intrinsicHeight
    if (width > 0 && height > 0) {
        return width to height
    }
    val fallbackPx = (24f * context.resources.displayMetrics.density).roundToInt().coerceAtLeast(1)
    drawable.setBounds(0, 0, fallbackPx, fallbackPx)
    width = drawable.intrinsicWidth
    height = drawable.intrinsicHeight
    if (width <= 0) {
        width = fallbackPx
    }
    if (height <= 0) {
        height = fallbackPx
    }
    return width.coerceAtLeast(1) to height.coerceAtLeast(1)
}
