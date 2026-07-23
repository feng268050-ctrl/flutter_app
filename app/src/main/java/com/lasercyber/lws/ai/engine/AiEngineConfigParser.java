package com.lasercyber.lws.ai.engine;
import com.lasercyber.lws.ai.stain.LensDetConsecutiveOkFilter;
import android.util.Log;

import androidx.annotation.Nullable;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Minimal parser for lens_guard {@code config.yaml} model enable flags.
 * Engine-aligned defaults: cls=false, det=true when keys are missing or unreadable.
 */
public final class AiEngineConfigParser {

    private static final String TAG = "AiEngineConfigParser";
    private static final Pattern FLAT_CLS =
            Pattern.compile("^models\\.cls\\.enabled\\s*:\\s*(.+)$", Pattern.CASE_INSENSITIVE);
    private static final Pattern FLAT_DET =
            Pattern.compile("^models\\.det\\.enabled\\s*:\\s*(.+)$", Pattern.CASE_INSENSITIVE);
    private static final Pattern FLAT_STAIN_SCORE_MODE =
            Pattern.compile("^(?:algorithm\\.)?stain_score_mode\\s*:\\s*(.+)$", Pattern.CASE_INSENSITIVE);
    private static final Pattern MIN_CONSECUTIVE_OK_FRAMES =
            Pattern.compile("^min_consecutive_ok_frames\\s*:\\s*(\\d+)\\s*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern BLUE_MIN_CONSECUTIVE_OK_FRAMES =
            Pattern.compile("^blue_min_consecutive_ok_frames\\s*:\\s*(\\d+)\\s*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern ENABLED =
            Pattern.compile("^enabled\\s*:\\s*(.+)$", Pattern.CASE_INSENSITIVE);

    static final class ModelFlags {
        final boolean classificationEnabled;
        final boolean detectionEnabled;

        ModelFlags(boolean classificationEnabled, boolean detectionEnabled) {
            this.classificationEnabled = classificationEnabled;
            this.detectionEnabled = detectionEnabled;
        }
    }

    private AiEngineConfigParser() {
    }

    static ModelFlags parseModelFlags(File configFile) {
        boolean clsEnabled = false;
        boolean detEnabled = true;
        Boolean flatCls = null;
        Boolean flatDet = null;
        if (configFile == null || !configFile.isFile() || !configFile.canRead()) {
            Log.w(TAG, "config missing or unreadable, using defaults cls=false det=true path="
                    + (configFile == null ? "null" : configFile.getAbsolutePath()));
            return new ModelFlags(clsEnabled, detEnabled);
        }
        boolean inModels = false;
        boolean inCls = false;
        boolean inDet = false;
        try (BufferedReader reader = new BufferedReader(new FileReader(configFile))) {
            String line;
            while ((line = reader.readLine()) != null) {
                String trimmed = line.trim();
                if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                    continue;
                }
                Matcher flatClsMatcher = FLAT_CLS.matcher(trimmed);
                if (flatClsMatcher.matches()) {
                    flatCls = parseBooleanValue(flatClsMatcher.group(1), clsEnabled);
                    continue;
                }
                Matcher flatDetMatcher = FLAT_DET.matcher(trimmed);
                if (flatDetMatcher.matches()) {
                    flatDet = parseBooleanValue(flatDetMatcher.group(1), detEnabled);
                    continue;
                }
                if ("models:".equals(trimmed)) {
                    inModels = true;
                    inCls = false;
                    inDet = false;
                    continue;
                }
                if (!inModels) {
                    continue;
                }
                if (isTopLevelSection(trimmed) && !"models:".equals(trimmed)) {
                    inModels = false;
                    inCls = false;
                    inDet = false;
                    continue;
                }
                if ("cls:".equals(trimmed)) {
                    inCls = true;
                    inDet = false;
                    continue;
                }
                if ("det:".equals(trimmed)) {
                    inDet = true;
                    inCls = false;
                    continue;
                }
                Matcher enabledMatcher = ENABLED.matcher(trimmed);
                if (enabledMatcher.matches()) {
                    boolean value = parseBooleanValue(enabledMatcher.group(1), true);
                    if (inCls) {
                        clsEnabled = value;
                    } else if (inDet) {
                        detEnabled = value;
                    }
                }
            }
        } catch (IOException e) {
            Log.w(TAG, "Failed to read config, using defaults cls=false det=true path="
                    + configFile.getAbsolutePath(), e);
        }
        if (flatCls != null) {
            clsEnabled = flatCls;
        }
        if (flatDet != null) {
            detEnabled = flatDet;
        }
        return new ModelFlags(clsEnabled, detEnabled);
    }

    static int parseMinConsecutiveOkFrames(@Nullable File configFile) {
        int defaultValue = LensDetConsecutiveOkFilter.DEFAULT_MIN_CONSECUTIVE_OK_FRAMES;
        if (configFile == null || !configFile.isFile() || !configFile.canRead()) {
            Log.w(TAG, "config missing or unreadable, using min_consecutive_ok_frames="
                    + defaultValue + " path="
                    + (configFile == null ? "null" : configFile.getAbsolutePath()));
            return defaultValue;
        }
        boolean inOpencvStainDetect = false;
        int parsed = defaultValue;
        try (BufferedReader reader = new BufferedReader(new FileReader(configFile))) {
            String line;
            while ((line = reader.readLine()) != null) {
                String trimmed = line.trim();
                if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                    continue;
                }
                if ("opencv_stain_detect:".equals(trimmed)) {
                    inOpencvStainDetect = true;
                    continue;
                }
                if (inOpencvStainDetect && isRootLevelYamlKey(line)) {
                    inOpencvStainDetect = false;
                }
                if (!inOpencvStainDetect) {
                    continue;
                }
                Matcher matcher = MIN_CONSECUTIVE_OK_FRAMES.matcher(trimmed);
                if (matcher.matches()) {
                    parsed = clampMinConsecutiveOkFrames(matcher.group(1), defaultValue);
                }
            }
        } catch (IOException e) {
            Log.w(TAG, "Failed to read min_consecutive_ok_frames from "
                    + configFile.getAbsolutePath() + ", using " + defaultValue, e);
            return defaultValue;
        }
        return parsed;
    }

    static int parseBlueMinConsecutiveOkFrames(@Nullable File configFile) {
        int defaultValue = 1;
        if (configFile == null || !configFile.isFile() || !configFile.canRead()) {
            return defaultValue;
        }
        boolean inOpencvStainDetect = false;
        int parsed = defaultValue;
        try (BufferedReader reader = new BufferedReader(new FileReader(configFile))) {
            String line;
            while ((line = reader.readLine()) != null) {
                String trimmed = line.trim();
                if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                    continue;
                }
                if ("opencv_stain_detect:".equals(trimmed)) {
                    inOpencvStainDetect = true;
                    continue;
                }
                if (inOpencvStainDetect && isRootLevelYamlKey(line)) {
                    inOpencvStainDetect = false;
                }
                if (!inOpencvStainDetect) {
                    continue;
                }
                Matcher matcher = BLUE_MIN_CONSECUTIVE_OK_FRAMES.matcher(trimmed);
                if (matcher.matches()) {
                    parsed = clampMinConsecutiveOkFrames(matcher.group(1), defaultValue);
                }
            }
        } catch (IOException e) {
            Log.w(TAG, "Failed to read blue_min_consecutive_ok_frames from "
                    + configFile.getAbsolutePath() + ", using " + defaultValue, e);
            return defaultValue;
        }
        return parsed;
    }

    /**
     * det_raw_head requires {@code stain_score_mode: logits} in deployed config (see engine APP_ALIGNMENT_BRIEF).
     */
    static void warnStainScoreMode(File configFile) {
        String mode = readFlatStainScoreMode(configFile);
        if (mode == null || mode.isEmpty()) {
            return;
        }
        if (!"logits".equalsIgnoreCase(mode.trim())) {
            Log.w(TAG, "stain_score_mode=" + mode.trim()
                    + " but det_raw_head expects logits; check files/lens_guard/config.yaml");
        }
    }

    private static String readFlatStainScoreMode(File configFile) {
        if (configFile == null || !configFile.isFile() || !configFile.canRead()) {
            return null;
        }
        try (BufferedReader reader = new BufferedReader(new FileReader(configFile))) {
            String line;
            while ((line = reader.readLine()) != null) {
                String trimmed = line.trim();
                if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                    continue;
                }
                Matcher matcher = FLAT_STAIN_SCORE_MODE.matcher(trimmed);
                if (matcher.matches()) {
                    return matcher.group(1).trim();
                }
            }
        } catch (IOException e) {
            Log.w(TAG, "Failed to read stain_score_mode from " + configFile.getAbsolutePath(), e);
        }
        return null;
    }

    private static boolean isTopLevelSection(String trimmed) {
        return trimmed.endsWith(":") && !trimmed.contains(" ");
    }

    private static boolean isRootLevelYamlKey(String line) {
        if (line.isEmpty() || line.startsWith("#")) {
            return false;
        }
        return !line.startsWith(" ") && !line.startsWith("\t") && line.trim().endsWith(":");
    }

    private static int clampMinConsecutiveOkFrames(String raw, int defaultValue) {
        if (raw == null) {
            return defaultValue;
        }
        try {
            int value = Integer.parseInt(raw.trim());
            if (value < 1) {
                return 1;
            }
            if (value > 10) {
                return 10;
            }
            return value;
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    private static boolean parseBooleanValue(String raw, boolean defaultValue) {
        if (raw == null) {
            return defaultValue;
        }
        String value = raw.trim().toLowerCase(Locale.ROOT);
        if (value.isEmpty()) {
            return defaultValue;
        }
        if ("true".equals(value) || "yes".equals(value) || "1".equals(value)) {
            return true;
        }
        if ("false".equals(value) || "no".equals(value) || "0".equals(value)) {
            return false;
        }
        return defaultValue;
    }
}
