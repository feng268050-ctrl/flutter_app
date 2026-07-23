package com.lasercyber.lws.ime.compose

/** Global QWERTY Shift key chrome — Off / Single / Lock. */
internal enum class ImeShiftVisualState {
    /** Gray key + white outline arrow (no bottom bar). */
    Off,
    /** Gray key + orange filled Shift icon. */
    Single,
    /** Same as Single + green indicator at top-right corner arc (gray when not locked). */
    Lock,
}

internal fun resolveImeShiftVisualState(
    shiftEnabled: Boolean,
    capsLockEnabled: Boolean,
): ImeShiftVisualState = when {
    capsLockEnabled -> ImeShiftVisualState.Lock
    shiftEnabled -> ImeShiftVisualState.Single
    else -> ImeShiftVisualState.Off
}
