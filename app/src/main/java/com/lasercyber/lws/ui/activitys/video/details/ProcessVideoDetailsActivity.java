package com.lasercyber.lws.ui.activitys.video.details;

import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.util.Log;
import android.widget.SeekBar;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import android.view.View;
import android.view.ViewTreeObserver;
import android.view.animation.AccelerateInterpolator;
import android.view.animation.DecelerateInterpolator;
import android.widget.LinearLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.ViewModelProvider;
import androidx.core.content.FileProvider;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;

import com.blankj.utilcode.util.StringUtils;
import com.blankj.utilcode.util.ToastUtils;
import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.activitys.BaseActivity;
import com.lasercyber.lws.ui.activitys.device.monitor.model.ProcessVideoDetailsViewModel;
import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.bean.entity.VideoInfo;
import com.lasercyber.lws.ui.common.constant.IntentParamsConstants;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.threads.ThreadPoolManager;
import com.lasercyber.lws.ui.common.utils.LocalVideoPlaybackValidator;
import com.lasercyber.lws.ui.common.utils.StoragePermissionHelper;
import com.lasercyber.lws.ui.common.utils.VideoFileUtils;
import com.lasercyber.lws.ui.common.utils.web.GlobalSoundManager;
import com.lasercyber.lws.ui.databinding.ActivityProcessVideoDetailsBinding;

import org.apache.commons.lang3.time.DurationFormatUtils;

import java.io.File;

/**
 * 工艺视频详情
 */
public class ProcessVideoDetailsActivity extends BaseActivity<ActivityProcessVideoDetailsBinding> {
    private static final String TAG = LogTAGConstant.ProcessVideoDetailsActivity;
    private static final long VIDEO_CONTROL_AUTO_HIDE_MS = 3000L;
    private static final long PROGRESS_UPDATE_INTERVAL_MS = 500L;
    private static final int SEEK_BAR_MAX = 1000;

    private ProcessVideoDetailsViewModel processVideoViewModel;
    private ExoPlayer player;
    private int videoLoadGeneration;
    private boolean userSeeking;
    private final Runnable hideVideoControlsTask = this::hideVideoControls;
    private final Runnable progressUpdateTask = new Runnable() {
        @Override
        public void run() {
            updateVideoProgressUi();
            if (player != null && player.isPlaying()) {
                handler.postDelayed(this, PROGRESS_UPDATE_INTERVAL_MS);
            }
        }
    };

    private final ActivityResultLauncher<String[]> requestVideoReadPerm =
            registerForActivityResult(new ActivityResultContracts.RequestMultiplePermissions(), granted -> {
                if (!StoragePermissionHelper.allGranted(granted)) {
                    ToastUtils.showShort(R.string.lws_video_storage_permission_required);
                    return;
                }
                ProcessVideoDetailsViewModel vm = processVideoViewModel;
                if (vm == null) {
                    return;
                }
                ProcessParamsVideo row = vm.getProcessParamsVideoProxy();
                if (row != null && !StringUtils.isEmpty(row.getVideoPath())) {
                    ThreadPoolManager.getExecutor().execute(() -> initVideo(row.getVideoPath().trim()));
                }
            });

    @Override
    protected void initView() {
        setupLayoutCompleteListener();
        long processVideoId = getIntent().getLongExtra(IntentParamsConstants.PROCESS_DATA_VIDEO_ID, 0);
        processVideoViewModel = new ViewModelProvider(this).get(ProcessVideoDetailsViewModel.class);
        processVideoViewModel.init(this, processVideoId);
        processVideoViewModel.getProcessParamsVideo().observe(this, processParamsVideo -> {
            if (processParamsVideo == null) {
                return;
            }
            // 初始化视频
            if (StoragePermissionHelper.shouldRequestRuntimeVideoRead(ProcessVideoDetailsActivity.this)) {
                requestVideoReadPerm.launch(StoragePermissionHelper.videoReadPermissions());
                return;
            }
            ThreadPoolManager.getExecutor().execute(() ->
                    initVideo(processParamsVideo.getVideoPath()));

            // 取消延迟的渲染任务
            if (task != null) {
                handler.removeCallbacks(task);
            }
            refreshView();
        });
        processVideoViewModel.getAdvancedSettingLiveData().observe(this, advancedSetting -> {
            if (advancedSetting == null) {
                return;
            }
            refreshViewTime();
        });
        binding.callBackPreviousPage.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            finish();
        });
        binding.videoDelete.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            processVideoViewModel.delete(integer -> {
                Intent resultIntent = new Intent();
                resultIntent.putExtra(IntentParamsConstants.DELETE_DATA_SUCCESS, true);
                setResult(RESULT_OK, resultIntent);
                finish();
            });
        });
        setupVideoControls();
        // DefaultDataSource supports content:// (FileProvider) and file://; plain file paths under /sdcard often
        // fail RandomAccessFile on scoped-storage builds when only file:// is used.
        DefaultDataSource.Factory dataSourceFactory = new DefaultDataSource.Factory(this);
        player = new ExoPlayer.Builder(this)
                .setMediaSourceFactory(new DefaultMediaSourceFactory(dataSourceFactory))
                .build();
        player.addListener(new Player.Listener() {
            // 播放失败的核心回调方法
            @Override
            public void onPlayerError(PlaybackException error) {
                String detail = formatPlaybackFailure(error);
                Log.e(TAG, "onPlayerError: " + detail, error);
                ToastUtils.showShort(truncateForToast("播放失败: " + detail));
            }

            @Override
            public void onPlaybackStateChanged(int state) {
                // 监听播放状态：STATE_IDLE/STATE_BUFFERING/STATE_READY/STATE_ENDED
                Log.d(TAG, "onPlaybackStateChanged: 播放状态:" + state);
                switch (state) {
                    case Player.STATE_IDLE:
                        Log.d("ExoPlayerState", "状态：空闲");
                        break;
                    case Player.STATE_BUFFERING:
                        Log.d("ExoPlayerState", "状态：缓冲中");
                        break;
                    case Player.STATE_READY:
                        Log.d("ExoPlayerState", "状态：就绪（可播放）");
                        onVideoReadyForControls();
                        break;
                    case Player.STATE_ENDED:
                        Log.d("ExoPlayerState", "状态：播放完成");
                        onVideoPlaybackEnded();
                        break;
                }
            }

            @Override
            public void onIsPlayingChanged(boolean isPlaying) {
                updateVideoPlayPauseButton();
                if (isPlaying) {
                    handler.removeCallbacks(progressUpdateTask);
                    handler.post(progressUpdateTask);
                    showVideoControlsTemporarily();
                } else {
                    handler.removeCallbacks(progressUpdateTask);
                    updateVideoProgressUi();
                }
            }

            @Override
            public void onPlayerErrorChanged(@Nullable PlaybackException error) {
                if (error != null) {
                    Log.e(TAG, "onPlayerErrorChanged: " + formatPlaybackFailure(error), error);
                }
            }
        });
        binding.playerProcessVideoView.setPlayer(player);
    }

    private void setupVideoControls() {
        binding.playerProcessVideoView.setOnClickListener(v -> showVideoControlsTemporarily());
        binding.btnProcessVideoRewind.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            seekVideoByButton(false);
        });
        binding.btnProcessVideoPlayPause.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            toggleVideoPlayback();
        });
        binding.btnProcessVideoFastForward.setOnClickListener(v -> {
            GlobalSoundManager.playClickSound();
            seekVideoByButton(true);
        });
        binding.processVideoSeekRow.setMax(SEEK_BAR_MAX);
        binding.processVideoSeekRow.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (player == null) {
                    return;
                }
                if (!fromUser && !userSeeking) {
                    return;
                }
                long durationMs = player.getDuration();
                if (durationMs > 0L) {
                    binding.processVideoSeekRow.setStartLabelText(
                            formatVideoTimeMs(progress * durationMs / SEEK_BAR_MAX));
                }
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
                userSeeking = true;
                handler.removeCallbacks(hideVideoControlsTask);
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                if (player != null) {
                    long durationMs = player.getDuration();
                    if (durationMs > 0L) {
                        player.seekTo((long) seekBar.getProgress() * durationMs / SEEK_BAR_MAX);
                    }
                }
                userSeeking = false;
                updateVideoProgressUi();
                showVideoControlsTemporarily();
            }
        });
    }

    private void toggleVideoPlayback() {
        if (player == null) {
            return;
        }
        if (player.getPlaybackState() == Player.STATE_ENDED) {
            player.seekTo(0L);
            player.setPlayWhenReady(true);
            player.play();
            return;
        }
        if (player.isPlaying() || player.getPlayWhenReady()) {
            player.pause();
            player.setPlayWhenReady(false);
            fadeInVideoControls(binding.layoutProcessVideoCenterControls);
            handler.removeCallbacks(hideVideoControlsTask);
        } else {
            player.setPlayWhenReady(true);
            player.play();
        }
        updateVideoPlayPauseButton();
    }

    private void seekVideoByButton(boolean forward) {
        if (player == null || player.getDuration() <= 0L) {
            return;
        }
        if (forward) {
            player.seekForward();
        } else {
            player.seekBack();
        }
        if (player.getPlaybackState() == Player.STATE_ENDED) {
            player.setPlayWhenReady(false);
        }
        updateVideoProgressUi();
        updateVideoPlayPauseButton();
        showVideoControlsTemporarily();
    }

    private void onVideoReadyForControls() {
        if (binding == null) {
            return;
        }
        fadeInVideoControls(binding.layoutProcessVideoControls);
        updateVideoProgressUi();
        updateVideoPlayPauseButton();
        fadeInVideoControls(binding.layoutProcessVideoCenterControls);
        handler.removeCallbacks(hideVideoControlsTask);
    }

    private void onVideoPlaybackEnded() {
        handler.removeCallbacks(progressUpdateTask);
        updateVideoProgressUi();
        updateVideoPlayPauseButton();
        fadeInVideoControls(binding.layoutProcessVideoCenterControls);
        handler.removeCallbacks(hideVideoControlsTask);
    }

    private void updateVideoPlayPauseButton() {
        if (binding == null || player == null) {
            return;
        }
        boolean shouldShowPause = player.getPlaybackState() != Player.STATE_ENDED
                && (player.isPlaying() || player.getPlayWhenReady());
        binding.btnProcessVideoPlayPause.setCompoundDrawablesWithIntrinsicBounds(
                shouldShowPause ? R.drawable.ic_process_video_pause : R.drawable.ic_process_video_play,
                0,
                0,
                0);
        binding.btnProcessVideoPlayPause.setContentDescription(getString(shouldShowPause
                ? R.string.ai_vision_video_pause
                : R.string.ai_vision_video_play));
    }

    private void updateVideoProgressUi() {
        if (binding == null || player == null || userSeeking) {
            return;
        }
        long durationMs = player.getDuration();
        if (durationMs <= 0L) {
            binding.processVideoSeekRow.setStartLabelText(formatVideoTimeMs(0L));
            binding.processVideoSeekRow.setEndLabelText(formatVideoTimeMs(0L));
            binding.processVideoSeekRow.setProgress(0);
            return;
        }
        long positionMs = player.getCurrentPosition();
        binding.processVideoSeekRow.setStartLabelText(formatVideoTimeMs(positionMs));
        binding.processVideoSeekRow.setEndLabelText(formatVideoTimeMs(durationMs));
        binding.processVideoSeekRow.setProgress((int) (positionMs * SEEK_BAR_MAX / durationMs));
    }

    private void showVideoControlsTemporarily() {
        if (binding == null || player == null || player.getPlaybackState() == Player.STATE_IDLE) {
            return;
        }
        fadeInVideoControls(binding.layoutProcessVideoCenterControls);
        handler.removeCallbacks(hideVideoControlsTask);
        if (player.isPlaying() || player.getPlayWhenReady()) {
            handler.postDelayed(hideVideoControlsTask, VIDEO_CONTROL_AUTO_HIDE_MS);
        }
    }

    private void hideVideoControls() {
        if (binding == null || player == null) {
            return;
        }
        if (player.isPlaying() || player.getPlayWhenReady()) {
            fadeOutVideoControls(binding.layoutProcessVideoCenterControls);
        }
    }

    private void fadeInVideoControls(@Nullable View controls) {
        if (controls == null) {
            return;
        }
        controls.animate().cancel();
        if (controls.getVisibility() != View.VISIBLE) {
            controls.setAlpha(0f);
            controls.setVisibility(View.VISIBLE);
        }
        controls.animate()
                .alpha(1f)
                .setDuration(getResources().getInteger(R.integer.frost_dialog_fade_in_duration_ms))
                .setInterpolator(new DecelerateInterpolator())
                .start();
    }

    private void fadeOutVideoControls(@Nullable View controls) {
        if (controls == null || controls.getVisibility() != View.VISIBLE) {
            return;
        }
        controls.animate().cancel();
        int duration = getResources().getInteger(R.integer.frost_dialog_fade_out_duration_ms);
        controls.animate()
                .alpha(0f)
                .setDuration(duration)
                .setInterpolator(new AccelerateInterpolator())
                .withEndAction(() -> {
                    if (controls.getAlpha() > 0.01f) {
                        return;
                    }
                    controls.setVisibility(View.GONE);
                    controls.setAlpha(1f);
                })
                .start();
    }

    private void hideVideoControlsImmediately() {
        if (binding == null) {
            return;
        }
        hideVideoControlsViewImmediately(binding.layoutProcessVideoControls);
        hideVideoControlsViewImmediately(binding.layoutProcessVideoCenterControls);
    }

    private static void hideVideoControlsViewImmediately(@Nullable View controls) {
        if (controls == null) {
            return;
        }
        controls.animate().cancel();
        controls.setVisibility(View.GONE);
        controls.setAlpha(1f);
    }

    private static String formatVideoTimeMs(long timeMs) {
        if (timeMs < 0L) {
            timeMs = 0L;
        }
        return DurationFormatUtils.formatDuration(timeMs, "mm:ss");
    }

    /**
     * 初始化视频
     *
     * @param videoPath
     */
    private void initVideo(String videoPath) {
        if (StringUtils.isEmpty(videoPath)) {
            return;
        }
        videoPath = videoPath.trim();
        Log.d(TAG, "initVideo: 视频地址:" + videoPath);
        File file = new File(videoPath);
        if (!file.exists()) {
            handler.post(() -> ToastUtils.showShort(R.string.video_loading_failed_text));
            return;
        }
        LocalVideoPlaybackValidator.Result validation = LocalVideoPlaybackValidator.evaluate(file);
        if (!validation.playable) {
            Log.e(TAG, "initVideo: not playable path=" + videoPath + " reason=" + validation.reason);
            handler.post(() -> ToastUtils.showShort(R.string.video_loading_failed_text));
            return;
        }
        VideoInfo videoInfo = VideoFileUtils.readVideoFileInfo(videoPath);
        Log.d(TAG, "initVideo: 视频文件信息:" + videoInfo + " durationMs=" + (videoInfo != null ? videoInfo.getDuration() : -1));
        final File mediaFile = file.getAbsoluteFile();
        final int generation = ++videoLoadGeneration;
        handler.post(() -> {
            if (isFinishing() || isDestroyed() || player == null || generation != videoLoadGeneration) {
                return;
            }
            Uri playUri;
            try {
                playUri = FileProvider.getUriForFile(
                        ProcessVideoDetailsActivity.this,
                        getPackageName() + ".fileprovider",
                        mediaFile);
            } catch (IllegalArgumentException e) {
                Log.w(TAG, "FileProvider rejected path, fallback file:// (may fail on scoped storage)", e);
                playUri = Uri.fromFile(mediaFile);
            }
            handler.removeCallbacks(hideVideoControlsTask);
            handler.removeCallbacks(progressUpdateTask);
            hideVideoControlsImmediately();
            binding.playerProcessVideoView.setPlayer(player);
            player.stop();
            player.clearMediaItems();
            player.setMediaItem(MediaItem.fromUri(playUri));
            player.setPlayWhenReady(false);
            player.prepare();
        });
    }

    private static String formatPlaybackFailure(@NonNull PlaybackException error) {
        StringBuilder sb = new StringBuilder();
        sb.append(PlaybackException.getErrorCodeName(error.errorCode));
        Throwable t = error.getCause();
        int depth = 0;
        while (t != null && depth < 6) {
            sb.append(" | ").append(t.getClass().getSimpleName());
            if (t.getMessage() != null && !t.getMessage().isEmpty()) {
                sb.append(": ").append(t.getMessage());
            }
            t = t.getCause();
            depth++;
        }
        return sb.toString();
    }

    private static String truncateForToast(String s) {
        if (s == null) {
            return "";
        }
        final int max = 220;
        return s.length() <= max ? s : s.substring(0, max) + "…";
    }

    /**
     * 防抖刷新
     */
    private void refreshViewTime() {
        if (this.task != null) {
            handler.removeCallbacks(this.task);
        }
        this.task = this::refreshView;
        handler.postDelayed(this.task, 20);
    }

    /**
     * 刷新视图
     */
    public void refreshView() {
        binding.setProcessVideoDetailsViewModel(processVideoViewModel);
        setupLayoutCompleteListener();
    }

    @Override
    protected void initData() {

    }

    @Override
    protected int getLayoutId() {
        return R.layout.activity_process_video_details;
    }

    private void setupLayoutCompleteListener() {
        if (binding == null) return;
        ViewTreeObserver observer = binding.fieldContent.getViewTreeObserver();
        observer.addOnGlobalLayoutListener(new ViewTreeObserver.OnGlobalLayoutListener() {
            @Override
            public void onGlobalLayout() {
                // 布局完成后执行背景刷新
                refreshLinearLayoutChildBg(binding.fieldContent);
                // 移除监听（避免重复触发）
                binding.fieldContent.getViewTreeObserver().removeOnGlobalLayoutListener(this);
            }
        });
    }

    /**
     * 给LinearLayout的一级子View设置奇偶行不同背景色
     *
     * @param linearLayout 目标LinearLayout
     */
    public void refreshLinearLayoutChildBg(LinearLayout linearLayout) {
        // 遍历LinearLayout的一级子View
        int index = 0;
        for (int i = 0; i < linearLayout.getChildCount(); i++) {
            View childView = linearLayout.getChildAt(i);
            if (childView == null) {
                continue;
            }
            childView.setBackgroundColor(Color.TRANSPARENT);
            //  只处理一级子View（不递归子布局）
            if (childView.getId() == R.id.parameter_recording_text
                    || childView.getVisibility() != View.VISIBLE) {
                continue;
            }
            if (index % 2 == 0) {
                childView.setBackgroundResource(R.color.table_bg);
            }
            index++;
        }
    }

    @Override
    protected void onDestroy() {
        handler.removeCallbacks(hideVideoControlsTask);
        handler.removeCallbacks(progressUpdateTask);
        hideVideoControlsImmediately();
        videoLoadGeneration++;
        ExoPlayer toRelease = player;
        player = null;
        if (binding != null) {
            binding.playerProcessVideoView.setPlayer(null);
        }
        if (toRelease != null) {
            try {
                toRelease.stop();
                toRelease.clearMediaItems();
                toRelease.release();
            } catch (Exception e) {
                Log.w(TAG, "onDestroy: player release failed", e);
            }
        }
        super.onDestroy();
    }
}