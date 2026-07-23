package com.lasercyber.lws.ui.activitys.dev

import android.util.Log
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.ViewCompositionStrategy
import com.blankj.utilcode.util.ToastUtils
import com.innohi.YNHAPI
import com.lasercyber.lws.ui.R
import com.lasercyber.lws.ui.activitys.BaseActivity
import com.lasercyber.lws.ui.bean.entity.ProcessParametersData
import com.lasercyber.lws.ui.common.audio.MusicPlaybackVolume
import com.lasercyber.lws.ui.common.camera.EasyPlayerClientManger
import com.lasercyber.lws.ui.common.config.CameraConfig
import com.lasercyber.lws.ui.common.config.GpioLedConfig
import com.lasercyber.lws.ui.common.constant.LogTAGConstant
import com.lasercyber.lws.ui.common.constant.ModelConstant
import com.lasercyber.lws.ui.common.gpio.IndicatorMode
import com.lasercyber.lws.ui.common.gpio.LedColor
import com.lasercyber.lws.ui.common.gpio.LedIndicatorManager
import com.lasercyber.lws.ui.common.handler.GpioLedHandler
import com.lasercyber.lws.ui.common.handler.VideoAndProcessParamsHandler
import com.lasercyber.lws.ui.common.utils.CameraUtils
import com.lasercyber.lws.ui.common.utils.DefaultValueUtils
import com.lasercyber.lws.ui.common.utils.LoadingUtils
import com.lasercyber.lws.ui.common.utils.ShellCmdUtil
import com.lasercyber.lws.ui.common.utils.VideoUploadProgressDialog
import com.lasercyber.lws.ui.component.dialog.FrostDialog
import com.lasercyber.lws.ui.databinding.ActivityDevBinding
import com.xuexiang.xui.widget.dialog.MiniLoadingDialog

/**
 * Developer debug screen (FrostUI Compose).
 */
class DevActivity : BaseActivity<ActivityDevBinding>() {

    private val tag = LogTAGConstant.DevActivity
    private var miniLoadingDialog: MiniLoadingDialog? = null
    private var videoUploadProgressDialog: VideoUploadProgressDialog? = null
    private var uploadCancelledByUser = false
    private val statusState = mutableStateOf("")
    private val musicState = mutableStateOf(DevMusicUiState())
    private var musicRhythmPlayer: DevMusicRhythmPlayer? = null

    override fun initView() {
        miniLoadingDialog = LoadingUtils.getMiniLoadingDialog(this)
        musicRhythmPlayer = DevMusicRhythmPlayer(this) { state ->
            musicState.value = musicState.value.copy(
                trackFileName = state.trackFileName,
                isPrepared = state.isPrepared,
                isPlaying = state.isPlaying,
                positionMs = state.positionMs,
                durationMs = state.durationMs,
                barSegments = state.barSegments,
                pulseLevel = state.pulseLevel,
                analyzerActive = state.analyzerActive,
            )
        }
        musicState.value = musicState.value.copy(
            volumePercent = MusicPlaybackVolume.getVolumePercent(this),
        )
        musicRhythmPlayer?.prepare()
        binding.devComposeRoot.setViewCompositionStrategy(
            ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed,
        )
        binding.devComposeRoot.setContent {
            DevScreen(
                statusLine = statusState.value,
                hardwareReady = isHardwareReady(),
                showVirtualRhythmBar = !isYnhApiAvailable(),
                musicState = musicState.value,
                callbacks = DevScreenCallbacks(
                    onIndicatorModeChange = ::onIndicatorModeChange,
                    onIndicatorBrightnessChange = ::onIndicatorBrightnessChange,
                    onAllIndicatorsOff = ::onAllIndicatorsOff,
                    onRefreshBusinessLeds = ::onRefreshBusinessLeds,
                    onMusicPlayPause = ::onMusicPlayPause,
                    onMusicRewind = ::onMusicRewind,
                    onMusicFastForward = ::onMusicFastForward,
                    onMusicSeek = ::onMusicSeek,
                    onMusicVolumeChange = ::onMusicVolumeChange,
                    onPingCamera = ::onPingCamera,
                    onCheckCamera = ::onCheckCamera,
                    onStartRecord = ::onStartRecord,
                    onStopRecord = ::onStopRecord,
                    onPauseRecord = ::onPauseRecord,
                    onContinueRecord = ::onContinueRecord,
                    onAnimationTest = ::onAnimationTest,
                ),
            )
        }
        DevActivitySupport.setRecordingListener(object : EasyPlayerClientManger.IPlayerClientListener {
            override fun startRecording() {
                ToastUtils.showShort("Recording started")
            }

            override fun stopRecording(path: String) {
                ToastUtils.showShort("Recording finished")
                Log.d(tag, "Recording finished: $path")
                handler.post {
                    FrostDialog.prompt(this@DevActivity)
                        .message("Upload this video?")
                        .confirmText("Upload")
                        .cancelText(getString(R.string.cancel_text))
                        .onConfirm {
                            val processParametersData =
                                DefaultValueUtils.createWeldCleaningProcessParametersData()
                            DevActivitySupport.configureProcessType(
                                processParametersData,
                                ModelConstant.CONTINUOUS_WELDING,
                            )
                            doUploadVideo(path, processParametersData)
                        }
                        .show()
                }
            }

            override fun pauseRecording() {
                ToastUtils.showShort("Recording paused")
            }

            override fun resumeRecording() {
                ToastUtils.showShort("Recording resumed")
            }

            override fun recordingAborted() {
                ToastUtils.showShort("No saveable recording file")
            }
        })
    }

    override fun initData() {
        refreshStatusLine()
    }

    override fun onResume() {
        super.onResume()
        enterManualLedTestMode()
        refreshStatusLine()
    }

    override fun onPause() {
        musicRhythmPlayer?.stop()
        LedIndicatorManager.clearAllExperimentalPwm()
        LedIndicatorManager.leaveMusicReactiveMode()
        leaveManualLedTestMode()
        super.onPause()
    }

    override fun getLayoutId(): Int = R.layout.activity_dev

    private fun enterManualLedTestMode() {
        GpioLedHandler.setAutoRefreshPaused(true)
    }

    private fun leaveManualLedTestMode() {
        GpioLedHandler.setAutoRefreshPaused(false)
        GpioLedHandler.refreshForced()
    }

    private fun refreshStatusLine() {
        val ynh = if (isYnhApiAvailable()) "YNHAPI available" else "YNHAPI unavailable"
        val pins = "GPIO R=${GpioLedConfig.GPIO_RED} Y=${GpioLedConfig.GPIO_YELLOW} G=${GpioLedConfig.GPIO_GREEN}"
        val manual = if (GpioLedHandler.isAutoRefreshPaused()) {
            "Business LED auto-refresh paused (manual test on this page)"
        } else {
            "Business LED auto-refresh active"
        }
        statusState.value = "$ynh\n$pins\n$manual"
    }

    private fun isYnhApiAvailable(): Boolean {
        return try {
            YNHAPI.getInstance()
            true
        } catch (throwable: Throwable) {
            Log.w(tag, "YNHAPI unavailable", throwable)
            false
        }
    }

    private fun doUploadVideo(localFilePath: String, params: ProcessParametersData) {
        uploadCancelledByUser = false
        dismissVideoUploadProgress()
        videoUploadProgressDialog = VideoUploadProgressDialog(this) {
            uploadCancelledByUser = true
            VideoAndProcessParamsHandler.cancelActiveUpload()
            dismissVideoUploadProgress()
        }
        videoUploadProgressDialog?.show()
        videoUploadProgressDialog?.updateProgress(0, getString(R.string.uploading_in_progress))
        DevActivitySupport.startVideoUpload(
            this,
            localFilePath,
            params,
            handler,
            videoUploadProgressDialog,
            this::dismissVideoUploadProgress,
        ) {
            val cancelled = uploadCancelledByUser
            uploadCancelledByUser = false
            cancelled
        }
    }

    private fun dismissVideoUploadProgress() {
        videoUploadProgressDialog?.dismiss()
        videoUploadProgressDialog = null
    }

    private fun isHardwareReady(): Boolean {
        return isYnhApiAvailable() && LedIndicatorManager.isHardwareAvailable()
    }

    private fun ensureHardwareReady(actionLabel: String): Boolean {
        if (isHardwareReady()) {
            return true
        }
        ToastUtils.showShort("$actionLabel: GPIO not ready")
        return false
    }

    private fun DevIndicatorColor.ledColor(): LedColor = when (this) {
        DevIndicatorColor.RED -> LedColor.RED
        DevIndicatorColor.YELLOW -> LedColor.YELLOW
        DevIndicatorColor.GREEN -> LedColor.GREEN
    }

    private fun onIndicatorModeChange(color: DevIndicatorColor, mode: DevIndicatorMode, brightness: Int) {
        if (!ensureHardwareReady(color.label)) {
            return
        }
        when (mode) {
            DevIndicatorMode.OFF -> LedIndicatorManager.setIndicator(color.ledColor(), IndicatorMode.OFF)
            DevIndicatorMode.STEADY -> {
                val level = if (brightness > 0) brightness else 128
                LedIndicatorManager.setExperimentalPwmBrightness(color.ledColor(), level)
            }
            DevIndicatorMode.BLINK -> LedIndicatorManager.setIndicator(color.ledColor(), IndicatorMode.BLINK)
        }
        val modeLabel = when (mode) {
            DevIndicatorMode.OFF -> "Off"
            DevIndicatorMode.STEADY -> "Steady"
            DevIndicatorMode.BLINK -> "Blink"
        }
        if (mode == DevIndicatorMode.STEADY) {
            logLed("${color.label} → $modeLabel PWM=$brightness (GPIO ${color.gpioPin})")
        } else {
            toastLed("${color.label} → $modeLabel (GPIO ${color.gpioPin})")
        }
    }

    private fun onIndicatorBrightnessChange(color: DevIndicatorColor, brightness: Int) {
        if (!ensureHardwareReady(color.label)) {
            return
        }
        LedIndicatorManager.setExperimentalPwmBrightness(color.ledColor(), brightness)
        logLed("${color.label} PWM brightness=$brightness (GPIO ${color.gpioPin})")
    }

    private fun onMusicPlayPause() {
        musicRhythmPlayer?.prepare()
        musicRhythmPlayer?.togglePlayPause()
        if (!isYnhApiAvailable()) {
            return
        }
        if (!isHardwareReady()) {
            ToastUtils.showShort("GPIO not ready — audio preview only, side LEDs off")
        }
    }

    private fun onMusicRewind() {
        musicRhythmPlayer?.prepare()
        musicRhythmPlayer?.seekBack()
    }

    private fun onMusicFastForward() {
        musicRhythmPlayer?.prepare()
        musicRhythmPlayer?.seekForward()
    }

    private fun onMusicSeek(positionMs: Long) {
        musicRhythmPlayer?.seekTo(positionMs)
    }

    private fun onMusicVolumeChange(percent: Int) {
        if (MusicPlaybackVolume.setVolumePercent(this, percent)) {
            musicState.value = musicState.value.copy(volumePercent = percent)
        } else {
            ToastUtils.showShort("Failed to set system volume")
        }
    }

    private fun onAllIndicatorsOff() {
        musicRhythmPlayer?.stop()
        if (!ensureHardwareReady("All Off")) {
            return
        }
        LedIndicatorManager.clearAllExperimentalPwm()
        LedColor.entries.forEach { led ->
            LedIndicatorManager.setIndicator(led, IndicatorMode.OFF)
        }
        toastLed("All RGB indicators off")
    }

    private fun onRefreshBusinessLeds() {
        LedIndicatorManager.clearAllExperimentalPwm()
        GpioLedHandler.refreshForced()
        toastLed("Business LEDs force-refreshed")
    }

    private fun toastLed(message: String) {
        ToastUtils.showShort(message)
        Log.d(tag, message)
    }

    private fun logLed(message: String) {
        Log.d(tag, message)
    }

    private fun onStartRecord() {
        EasyPlayerClientManger.getInstance().start()
    }

    private fun onStopRecord() {
        EasyPlayerClientManger.getInstance().stop()
    }

    private fun onPauseRecord() {
        EasyPlayerClientManger.getInstance().pause()
    }

    private fun onContinueRecord() {
        EasyPlayerClientManger.getInstance().resume()
    }

    private fun onPingCamera() {
        val host = CameraConfig.getCameraIp()
        Log.d(tag, "pingCamera: ping $host")
        Thread({
            val executed = ShellCmdUtil.executeCmd("ping -c 2 $host")
            Log.d(tag, "pingCamera: result=$executed")
            handler.post { ToastUtils.showShort("ping $host → $executed") }
        }, "dev-ping-camera").apply {
            isDaemon = true
            start()
        }
    }

    private fun onCheckCamera() {
        Log.d(tag, "checkCamera: starting")
        CameraUtils.checkCamera(object : CameraUtils.CheckCameraListener {
            override fun success() {
                Log.d(tag, "checkCamera: camera available")
            }

            override fun fail() {
                Log.d(tag, "checkCamera: camera unavailable")
            }
        })
    }

    private fun onAnimationTest() {
        miniLoadingDialog?.show()
        handler.postDelayed({ miniLoadingDialog?.dismiss() }, 1500L)
    }

    override fun onDestroy() {
        musicRhythmPlayer?.release()
        musicRhythmPlayer = null
        dismissVideoUploadProgress()
        super.onDestroy()
    }
}
