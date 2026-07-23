package com.lasercyber.lws.ui.common.utils.web;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.SoundPool;
import android.os.SystemClock;
import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.R;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.settings.SoundEffectSettings;

/**
 * Global click / warn sound pool. All three click samples are preloaded; the active
 * sample follows {@link SoundEffectSettings} (persisted soundEffect 0/1/2).
 */
public class GlobalSoundManager {
    private static final String TAG = LogTAGConstant.GlobalSoundManager;

    private static final int EFFECT_COUNT = 3;
    private static final long CLICK_DEBOUNCE_MS = 150L;
    /** Matches [com.lasercyber.lws.ui.common.audio.MusicPlaybackVolume] ([android.media.AudioManager.STREAM_MUSIC]). */
    private static final int SOUND_POOL_USAGE = AudioAttributes.USAGE_MEDIA;
    private static final int[] CLICK_RAW = {
            R.raw.click_mp3_2,
            R.raw.click_mp3,
            R.raw.click_mp3_1,
    };

    private static GlobalSoundManager INSTANCE;
    private static SoundPool soundPool;
    private static final int[] clickSampleIds = new int[EFFECT_COUNT];
    private static final boolean[] clickSamplesReady = new boolean[EFFECT_COUNT];
    private static int warnSampleId;
    private static boolean warnSampleReady;
    private static int activeEffectIndex;
    private static boolean pendingClickPlay;
    private static long lastClickPlayUptimeMs;
    private static int configuredSoundPoolUsage = -1;

    private static int warnStreamId;
    private volatile static boolean warnOpen;
    /** Non-null when {@link #ensureWarnSoundPlaying} started sound for a coded warn episode. */
    @Nullable
    private static String warnEpisodeCode;

    private GlobalSoundManager() {
    }

    public static synchronized GlobalSoundManager getInstance(Context appContext, int effectIndex) {
        ensureInitialized(appContext, effectIndex);
        if (INSTANCE == null) {
            INSTANCE = new GlobalSoundManager();
        }
        return INSTANCE;
    }

    public static synchronized void ensureInitialized(Context context, int effectIndex) {
        setActiveEffect(effectIndex);
        if (soundPool != null && configuredSoundPoolUsage == SOUND_POOL_USAGE) {
            return;
        }
        if (soundPool != null) {
            releaseSoundPoolLocked();
        }
        Context appContext = context.getApplicationContext();
        SoundPool.Builder builder = new SoundPool.Builder();
        builder.setMaxStreams(4);

        AudioAttributes attrs = new AudioAttributes.Builder()
                .setUsage(SOUND_POOL_USAGE)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build();
        builder.setAudioAttributes(attrs);
        configuredSoundPoolUsage = SOUND_POOL_USAGE;

        soundPool = builder.build();
        pendingClickPlay = false;

        for (int i = 0; i < EFFECT_COUNT; i++) {
            clickSamplesReady[i] = false;
            clickSampleIds[i] = soundPool.load(appContext, CLICK_RAW[i], 1);
        }
        warnSampleReady = false;
        warnSampleId = soundPool.load(appContext, R.raw.warn_mp3, 1);

        soundPool.setOnLoadCompleteListener((pool, sampleId, status) -> {
            boolean loaded = status == 0;
            for (int i = 0; i < EFFECT_COUNT; i++) {
                if (clickSampleIds[i] == sampleId) {
                    clickSamplesReady[i] = loaded;
                }
            }
            if (warnSampleId == sampleId) {
                warnSampleReady = loaded;
            }
            if (!loaded) {
                Log.w(TAG, "sample load failed: id=" + sampleId + " status=" + status);
                return;
            }
            if (pendingClickPlay && clickSamplesReady[activeEffectIndex]) {
                playLoadedClickSound();
            }
        });
    }

    public static synchronized void ensureInitialized(Context context) {
        ensureInitialized(context, SoundEffectSettings.getIndex(context));
    }

    public static synchronized void setActiveEffect(int effectIndex) {
        if (effectIndex < 0 || effectIndex >= EFFECT_COUNT) {
            effectIndex = 0;
        }
        activeEffectIndex = effectIndex;
    }

    public static void refreshActiveEffect(Context context) {
        setActiveEffect(SoundEffectSettings.getIndex(context));
    }

    /** Non-coded warn sound (safety-ground prompt, native AI alert without episode binding). */
    public static void warnSound() {
        ensureWarnSoundPlaying(null);
    }

    /**
     * Starts looping warn sound for a coded alarm episode. No-op when already playing for the same code.
     */
    public static void ensureWarnSoundPlaying(@Nullable String episodeCode) {
        if (soundPool == null || !warnSampleReady) {
            return;
        }
        if (episodeCode != null
                && episodeCode.equals(warnEpisodeCode)
                && warnOpen
                && warnStreamId != 0) {
            return;
        }
        stopWarnStreamLocked();
        warnOpen = true;
        warnEpisodeCode = episodeCode;
        warnStreamId = soundPool.play(warnSampleId, 1.0f, 1.0f, 1, -1, 1.0f);
        if (warnStreamId == 0) {
            warnOpen = false;
            warnEpisodeCode = null;
        }
    }

    public static void stopWarnSound() {
        stopWarnSoundInternal();
    }

    /** Stops warn sound only when it belongs to {@code episodeCode} (or any episode when {@code null}). */
    public static void stopWarnSoundForEpisode(@Nullable String episodeCode) {
        if (episodeCode != null && warnEpisodeCode != null && !episodeCode.equals(warnEpisodeCode)) {
            return;
        }
        stopWarnSoundInternal();
    }

    public static boolean isWarnSoundPlayingFor(@Nullable String episodeCode) {
        return episodeCode != null
                && episodeCode.equals(warnEpisodeCode)
                && warnOpen
                && warnStreamId != 0;
    }

    public static boolean isCodedWarnSoundEpisodeActive() {
        return warnEpisodeCode != null && warnOpen && warnStreamId != 0;
    }

    private static void stopWarnSoundInternal() {
        if (soundPool == null) {
            return;
        }
        warnOpen = false;
        warnEpisodeCode = null;
        stopWarnStreamLocked();
    }

    private static void stopWarnStreamLocked() {
        if (soundPool == null || warnStreamId == 0) {
            return;
        }
        soundPool.stop(warnStreamId);
        warnStreamId = 0;
    }

    public static void playClickSound() {
        playClickSound(null);
    }

    public static void playClickSound(Context context) {
        if (context != null) {
            refreshActiveEffect(context);
            ensureInitialized(context);
        }
        if (soundPool == null) {
            return;
        }
        long now = SystemClock.uptimeMillis();
        if (now - lastClickPlayUptimeMs < CLICK_DEBOUNCE_MS) {
            return;
        }
        if (!clickSamplesReady[activeEffectIndex]) {
            pendingClickPlay = true;
            return;
        }
        playLoadedClickSound();
    }

    private static void playLoadedClickSound() {
        if (soundPool == null || !clickSamplesReady[activeEffectIndex]) {
            return;
        }
        pendingClickPlay = false;
        lastClickPlayUptimeMs = SystemClock.uptimeMillis();
        soundPool.play(clickSampleIds[activeEffectIndex], 1.0f, 1.0f, 1, 0, 1.0f);
    }

    public static void openEffect(int index, Context context) {
        if (index < 0 || index >= EFFECT_COUNT) {
            index = 0;
        }
        SoundEffectSettings.setIndex(context, index);
        ensureInitialized(context, index);
        setActiveEffect(index);
        playEffectSample(index);
    }

    /** Plays the click sample for {@code effectIndex} without changing the active effect. */
    public static void previewEffect(int effectIndex, Context context) {
        if (effectIndex < 0 || effectIndex >= EFFECT_COUNT) {
            effectIndex = 0;
        }
        ensureInitialized(context);
        playEffectSample(effectIndex);
    }

    private static void playEffectSample(int effectIndex) {
        if (soundPool == null) {
            return;
        }
        if (effectIndex < 0 || effectIndex >= EFFECT_COUNT) {
            effectIndex = 0;
        }
        if (!clickSamplesReady[effectIndex]) {
            pendingClickPlay = true;
            return;
        }
        pendingClickPlay = false;
        lastClickPlayUptimeMs = SystemClock.uptimeMillis();
        soundPool.play(clickSampleIds[effectIndex], 1.0f, 1.0f, 1, 0, 1.0f);
    }

    public void release() {
        releaseSoundPoolLocked();
        INSTANCE = null;
    }

    private static void releaseSoundPoolLocked() {
        if (soundPool != null) {
            soundPool.release();
            soundPool = null;
        }
        configuredSoundPoolUsage = -1;
        pendingClickPlay = false;
        lastClickPlayUptimeMs = 0L;
        warnStreamId = 0;
        warnOpen = false;
        warnEpisodeCode = null;
        warnSampleReady = false;
        for (int i = 0; i < EFFECT_COUNT; i++) {
            clickSamplesReady[i] = false;
        }
    }
}
