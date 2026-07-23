package com.lasercyber.lws.frostui.control

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.coerceAtLeast
import androidx.compose.ui.unit.dp
import com.lasercyber.lws.frostui.common.FrostUiClickSoundRegistry
import com.lasercyber.lws.frostui.common.frostSingleFingerClickable
import kotlinx.coroutines.launch

@Composable
fun FrostSegmentedControl(
    selectedIndex: Int,
    onSelectedIndexChange: (Int) -> Unit,
    options: List<String>,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    clickSoundEnabled: Boolean = true,
    appearance: FrostSegmentedAppearance,
) {
    if (options.isEmpty()) return

    val context = LocalContext.current
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    val longPressThresholdMs = FrostControlDimens.segmentLongPressThresholdMs(context)
    val pillDragScale = FrostControlDimens.sliderThumbDragScale(context)
    val dragState = rememberFrostSegmentLongPressDragState()
    val pillScale = frostSegmentPillDragScale(dragState.isPillExpanded, pillDragScale)

    val outerShape = RoundedCornerShape(appearance.capsuleCornerRadius)
    val segmentShape = RoundedCornerShape(
        (appearance.capsuleCornerRadius - appearance.capsuleInset).coerceAtLeast(0.dp),
    )
    val clampedIndex = selectedIndex.coerceIn(0, options.lastIndex)
    val slideIndexAnim = remember { Animatable(clampedIndex.toFloat()) }

    val selectedIndexState = rememberUpdatedState(clampedIndex)
    val onSelectedIndexChangeState = rememberUpdatedState(onSelectedIndexChange)
    val clickSoundEnabledState = rememberUpdatedState(clickSoundEnabled)
    val dragStateRef = rememberUpdatedState(dragState)
    val slideSpec = remember(appearance.crossfadeDurationMs) {
        segmentSlideSpec(appearance.crossfadeDurationMs)
    }

    LaunchedEffect(clampedIndex) {
        if (dragState.isSelectionArmed || dragState.isPillExpanded || dragState.releaseSlideIndex.isFinite()) {
            return@LaunchedEffect
        }
        slideIndexAnim.animateTo(clampedIndex.toFloat(), slideSpec)
    }

    Box(
        modifier = modifier
            .defaultMinSize(minHeight = FrostControlDimens.capsuleControlHeight(context))
            .frostSliderDrawUnclipped()
            .clip(outerShape)
            .background(appearance.capsuleFillColor)
            .border(
                BorderStroke(appearance.capsuleBorderWidth, appearance.capsuleBorderColor),
                outerShape,
            )
            .padding(appearance.capsuleInset)
            .frostSegmentLongPressDragGesture(
                enabled = enabled,
                optionCount = options.size,
                longPressThresholdMs = longPressThresholdMs,
                selectedIndex = clampedIndex,
                state = dragState,
                clickSoundEnabled = clickSoundEnabled,
                onPillExpand = { _, segmentWidthPx ->
                    dragStateRef.value.dragOffsetPx = frostSegmentRestingOffsetPx(
                        selectedIndex = selectedIndexState.value,
                        segmentWidthPx = segmentWidthPx,
                    )
                },
                onDragOffsetWhileArmed = { trackWidthPx, segmentWidthPx, activationX, currentX ->
                    val restingOffsetPx = frostSegmentRestingOffsetPx(
                        selectedIndex = selectedIndexState.value,
                        segmentWidthPx = segmentWidthPx,
                    )
                    dragStateRef.value.dragOffsetPx = frostSegmentPreviewOffsetPx(
                        restingOffsetPx = restingOffsetPx,
                        activationX = activationX,
                        currentX = currentX,
                        segmentWidthPx = segmentWidthPx,
                        trackWidthPx = trackWidthPx,
                    )
                },
                onRelease = { _, segmentWidthPx, cancelled ->
                    if (cancelled || !dragStateRef.value.isSelectionArmed) return@frostSegmentLongPressDragGesture
                    val releaseOffsetPx = dragStateRef.value.dragOffsetPx
                    if (!releaseOffsetPx.isFinite() || segmentWidthPx <= 0f) {
                        return@frostSegmentLongPressDragGesture
                    }
                    val targetIndex = frostSegmentNearestIndex(
                        pillOffsetXPx = releaseOffsetPx,
                        segmentWidthPx = segmentWidthPx,
                        optionCount = options.size,
                    )
                    val releaseSlideIndex = (releaseOffsetPx / segmentWidthPx)
                        .coerceIn(0f, (options.size - 1).toFloat())
                    dragStateRef.value.releaseSlideIndex = releaseSlideIndex
                    scope.launch {
                        slideIndexAnim.snapTo(releaseSlideIndex)
                        dragStateRef.value.releaseSlideIndex = Float.NaN
                        if (targetIndex != selectedIndexState.value) {
                            onSelectedIndexChangeState.value(targetIndex)
                        }
                        slideIndexAnim.animateTo(targetIndex.toFloat(), slideSpec)
                    }
                },
            ),
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .frostSliderDrawUnclipped(),
        ) {
            if (!maxWidth.value.isFinite() || maxWidth <= 0.dp) {
                return@BoxWithConstraints
            }
            val segmentWidth = maxWidth / options.size
            val trackWidthPx = with(density) { maxWidth.toPx() }
            val segmentWidthPx = frostSegmentWidthPx(trackWidthPx, options.size)
            if (segmentWidthPx <= 0f) {
                return@BoxWithConstraints
            }
            val isDragPreview = dragState.isSelectionArmed && dragState.dragOffsetPx.isFinite()
            val slideIndex = when {
                isDragPreview -> dragState.dragOffsetPx / segmentWidthPx
                dragState.releaseSlideIndex.isFinite() -> dragState.releaseSlideIndex
                else -> slideIndexAnim.value
            }
            val displayOffsetPx = when {
                isDragPreview -> dragState.dragOffsetPx
                dragState.isPillExpanded -> frostSegmentRestingOffsetPx(clampedIndex, segmentWidthPx)
                else -> segmentWidthPx * slideIndex
            }.let { offsetPx ->
                if (offsetPx.isFinite()) offsetPx else 0f
            }
            val displayIndex = if (isDragPreview || dragState.releaseSlideIndex.isFinite()) {
                frostSegmentNearestIndex(
                    pillOffsetXPx = displayOffsetPx,
                    segmentWidthPx = segmentWidthPx,
                    optionCount = options.size,
                )
            } else {
                clampedIndex
            }
            val pillOffset = with(density) { displayOffsetPx.toDp() }

            Box(
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .offset(x = pillOffset)
                    .width(segmentWidth)
                    .fillMaxHeight()
                    .graphicsLayer {
                        scaleX = pillScale
                        scaleY = pillScale
                        transformOrigin = TransformOrigin.Center
                        clip = false
                    }
                    .clip(segmentShape)
                    .background(appearance.segmentSelectedFillColor),
            )

            Row(modifier = Modifier.fillMaxSize()) {
                options.forEachIndexed { index, label ->
                    val selected = index == displayIndex
                    val textColor by animateColorAsState(
                        targetValue = if (selected) {
                            appearance.segmentSelectedTextColor
                        } else {
                            appearance.segmentUnselectedTextColor
                        },
                        animationSpec = tween(
                            durationMillis = appearance.crossfadeDurationMs,
                            easing = decelerateEasing(),
                        ),
                        label = "segmentText",
                    )

                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight()
                            .then(
                                if (enabled && index != clampedIndex) {
                                    Modifier.frostSingleFingerClickable {
                                        if (clickSoundEnabledState.value) {
                                            FrostUiClickSoundRegistry.playClick()
                                        }
                                        onSelectedIndexChangeState.value(index)
                                    }
                                } else {
                                    Modifier
                                },
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = label,
                            color = textColor,
                            fontSize = appearance.segmentTextSize,
                            textAlign = TextAlign.Center,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
        }
    }
}

fun defaultFrostSegmentedAppearance(context: android.content.Context): FrostSegmentedAppearance =
    FrostControlDimens.segmentedAppearance(context)
