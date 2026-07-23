package com.lasercyber.lws.frostui.blur

import android.graphics.Matrix
import android.view.View

/** How a blurred backdrop bitmap is aligned when drawn into a card-sized viewport. */
enum class FrostBackdropDisplayMode {
    /** Card-sized capture; scale to fill the anchor with no window translation. */
    LOCAL,
    /** Full-window capture; scale and translate so content aligns behind the anchor. */
    FULLSCREEN,
}

object FrostBackdropDisplay {

    const val SCALE_FACTOR = FrostBackdropCapture.BLUR_SCALE_FACTOR

    @JvmStatic
    fun imageMatrix(
        mode: FrostBackdropDisplayMode,
        anchor: View,
        contentAnchor: View? = null,
    ): Matrix {
        val matrix = Matrix()
        matrix.setScale(SCALE_FACTOR, SCALE_FACTOR)
        if (mode == FrostBackdropDisplayMode.FULLSCREEN) {
            val cardLocation = IntArray(2)
            val contentLocation = IntArray(2)
            anchor.getLocationOnScreen(cardLocation)
            val content = contentAnchor ?: anchor.rootView.findViewById(android.R.id.content)
            content?.getLocationOnScreen(contentLocation)
            if (content != null) {
                matrix.postTranslate(
                    (contentLocation[0] - cardLocation[0]).toFloat(),
                    (contentLocation[1] - cardLocation[1]).toFloat(),
                )
            }
        }
        return matrix
    }

    @JvmStatic
    fun fullscreenOffsetPx(anchor: View, contentAnchor: View? = null): Pair<Float, Float> {
        val cardLocation = IntArray(2)
        val contentLocation = IntArray(2)
        anchor.getLocationOnScreen(cardLocation)
        val content = contentAnchor ?: anchor.rootView.findViewById(android.R.id.content)
        content?.getLocationOnScreen(contentLocation)
        return fullscreenOffsetPx(
            cardLocation[0],
            cardLocation[1],
            contentLocation[0],
            contentLocation[1],
            content != null,
        )
    }

    @JvmStatic
    fun fullscreenOffsetPx(
        cardX: Int,
        cardY: Int,
        contentX: Int,
        contentY: Int,
        hasContent: Boolean,
    ): Pair<Float, Float> = if (hasContent) {
        (contentX - cardX).toFloat() to (contentY - cardY).toFloat()
    } else {
        0f to 0f
    }
}
