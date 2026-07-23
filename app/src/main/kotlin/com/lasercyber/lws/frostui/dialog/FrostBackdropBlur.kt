package com.lasercyber.lws.frostui.dialog

import android.content.Context
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future

/** Bitmap blur for frost dialog/card backdrop snapshots (implementation wired in app layer). */
fun interface FrostBackdropBlur {
    fun blurBitmap(context: Context, bitmap: Bitmap, blurRadius: Int, passes: Int): Bitmap?
}

object FrostBackdropBlurRegistry {
    @Volatile
    private var blur: FrostBackdropBlur? = null

    private val executor: ExecutorService = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "frost-backdrop-blur").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    @JvmStatic
    fun register(implementation: FrostBackdropBlur) {
        blur = implementation
    }

    internal fun blurBitmap(
        context: Context,
        bitmap: Bitmap,
        blurRadius: Int,
        passes: Int = 1,
    ): Bitmap? {
        val implementation = blur ?: return null
        val radius = blurRadius.coerceIn(0, 25)
        if (radius <= 0) {
            return bitmap
        }
        var result = implementation.blurBitmap(context, bitmap, radius, 1) ?: return null
        repeat((passes - 1).coerceAtLeast(0)) {
            val next = implementation.blurBitmap(context, result, radius, 1) ?: return result
            if (next !== result && !result.isRecycled) {
                result.recycle()
            }
            result = next
        }
        return result
    }

    @JvmStatic
    @JvmOverloads
    fun blurBitmapAsync(
        context: Context,
        bitmap: Bitmap,
        blurRadius: Int,
        passes: Int = 1,
        onSuccess: (Bitmap?) -> Unit,
        onFailed: () -> Unit = {},
    ): Future<*> = executor.submit {
        try {
            val blurred = blurBitmap(context, bitmap, blurRadius, passes)
            mainHandler.post { onSuccess(blurred) }
        } catch (_: Exception) {
            mainHandler.post { onFailed() }
        }
    }
}
