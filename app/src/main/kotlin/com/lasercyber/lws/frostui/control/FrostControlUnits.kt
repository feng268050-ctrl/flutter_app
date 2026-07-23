package com.lasercyber.lws.frostui.control

import android.content.Context
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** [android.util.TypedArray.getDimension] / [android.content.res.Resources.getDimension] return px. */
internal fun Context.pxToDp(px: Float): Dp = (px / resources.displayMetrics.density).dp

internal fun Context.pxToSp(px: Float): TextUnit = (px / resources.displayMetrics.scaledDensity).sp
