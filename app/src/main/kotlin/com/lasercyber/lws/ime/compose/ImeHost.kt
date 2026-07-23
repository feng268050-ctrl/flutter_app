package com.lasercyber.lws.ime.compose

import android.app.Activity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.lasercyber.lws.ime.core.ImeConfig
import com.lasercyber.lws.ime.core.ImeController
import com.lasercyber.lws.ime.interop.ViewImeAnchor

@Composable
fun rememberImeSession(
    sessionKey: Any = Unit,
    config: ImeConfig = ImeConfig.defaults(),
): ImeSessionState {
    val activity = LocalContext.current as? Activity
    return remember(sessionKey, config, activity) {
        ImeSessionState(activity = activity, config = config, sessionKey = sessionKey)
    }
}

class ImeSessionState internal constructor(
    internal val activity: Activity?,
    internal val config: ImeConfig,
    internal val sessionKey: Any,
) {
    var liftOffsetPx by mutableIntStateOf(0)
        internal set
}

@Composable
fun ImeHost(
    session: ImeSessionState,
    overlayRoot: android.view.View,
    cardView: android.view.View,
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.(liftOffsetPx: Int) -> Unit,
) {
    val activity = session.activity
    DisposableEffect(activity, session.sessionKey, overlayRoot, cardView) {
        if (activity != null) {
            ImeController.attach(
                activity = activity,
                sessionKey = session.sessionKey,
                anchor = ViewImeAnchor(cardView),
                cardView = cardView,
                overlayRoot = overlayRoot,
                config = session.config,
            )
        }
        onDispose {
            if (activity != null) {
                ImeController.detach(activity, overlayRoot)
            }
        }
    }
    Box(modifier = modifier.fillMaxSize()) {
        content(session.liftOffsetPx)
    }
}
