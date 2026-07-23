package com.lasercyber.lws.frostui.border

import android.content.Context
import android.graphics.Bitmap
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection

/** Renders frost panel painters to a bitmap for instrumented visual regression tests. */
object PanelBitmapRenderer {

    fun drawBorderOnly(
        context: Context,
        width: Int,
        height: Int,
        gradientCenter: BorderGradientCenter,
    ): Bitmap = drawPanel(
        context = context,
        width = width,
        height = height,
        drawFill = false,
        gradientCenter = gradientCenter,
    )

    fun drawFillOnly(
        context: Context,
        width: Int,
        height: Int,
        gradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
    ): Bitmap = drawPanel(
        context = context,
        width = width,
        height = height,
        drawFill = true,
        drawBorder = false,
        gradientCenter = gradientCenter,
    )

    fun drawPanel(
        context: Context,
        width: Int,
        height: Int,
        drawFill: Boolean = true,
        drawBorder: Boolean = true,
        gradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
    ): Bitmap {
        val imageBitmap = ImageBitmap(width, height)
        val drawScope = CanvasDrawScope()
        val density = Density(context.resources.displayMetrics.density)
        drawScope.draw(
            density = density,
            layoutDirection = LayoutDirection.Ltr,
            canvas = Canvas(imageBitmap),
            size = Size(width.toFloat(), height.toFloat()),
        ) {
            if (drawFill) {
                val fillSpec = PanelFillPainter.panelFillSpec(context)
                with(PanelFillPainter) { drawPanelFill(fillSpec) }
            }
            if (drawBorder) {
                val borderSpec = PanelBorderPainter.cardBorderSpec(
                    context = context,
                    gradientCenter = gradientCenter,
                )
                with(PanelBorderPainter) { drawPanelBorder(borderSpec) }
            }
        }
        return imageBitmap.asAndroidBitmap()
    }
}
