package com.lasercyber.lws.ui.common.utils;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.VisibleForTesting;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * App shell runner with explicit privilege separation.
 *
 * <p>{@link #executeCmd(String)} runs as the app via {@code sh -c} (no {@code su}).
 * {@link #executeCmdAsRoot(String)} delegates to Innohi {@code com.innohi.ShellCmdUtil}
 * ({@code su}/{@code ssu}) for commands that require root, such as {@code ip route} or
 * {@code setprop}.</p>
 */
public final class ShellCmdUtil {

    private static final String TAG = LogTAGConstant.ShellCmdUtil;
    private static final Pattern PING_STATS_PATTERN = Pattern.compile(
            "(\\d+) packets transmitted, (\\d+) received",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern PING_LOSS_PATTERN = Pattern.compile(
            "(\\d+)% packet loss",
            Pattern.CASE_INSENSITIVE);

    private ShellCmdUtil() {
    }

    private static final String CAMERA_IFACE = "eth0";

    /**
     * ICMP probe bound to the dedicated camera interface ({@code eth0}).
     * Required on dual-homed tablets where the default network is Wi‑Fi.
     */
    public static boolean isCameraHostPingReachable(@NonNull String host) {
        String command = "ping -I " + CAMERA_IFACE + " -c 1 -W 2 " + host;
        return executeCmdAsRoot(command);
    }

    /**
     * Single-shot ICMP probe. Success requires a clean reply, not merely shell exit code 0.
     */
    public static boolean isHostPingReachable(@NonNull String host) {
        String command = "ping -c 1 -W 1 " + host;
        try {
            Process process = Runtime.getRuntime().exec(new String[]{"sh", "-c", command});
            String output = readProcessOutput(process.getInputStream())
                    + readProcessOutput(process.getErrorStream());
            int exit = process.waitFor();
            boolean reachable = parsePingReachableOutput(output);
            if (!reachable || exit != 0) {
                Log.d(TAG, "isHostPingReachable host=" + host + " exit=" + exit
                        + " reachable=" + reachable + " output=" + summarizeOutput(output));
            }
            return reachable && exit == 0;
        } catch (Exception t) {
            Log.w(TAG, "isHostPingReachable failed host=" + host, t);
            return false;
        }
    }

    /**
     * Runs a shell command without elevating to root (e.g. {@code ping}, read-only probes).
     */
    public static boolean executeCmd(@NonNull String command) {
        try {
            Process process = Runtime.getRuntime().exec(new String[]{"sh", "-c", command});
            int exit = process.waitFor();
            if (exit != 0) {
                Log.d(TAG, "executeCmd exit=" + exit + " cmd=" + command);
            }
            return exit == 0;
        } catch (Exception t) {
            Log.w(TAG, "executeCmd failed cmd=" + command, t);
            return false;
        }
    }

    /**
     * Runs a shell command via {@code su}/{@code ssu}. Use only when root is required.
     */
    public static boolean executeCmdAsRoot(@NonNull String command) {
        try {
            return com.innohi.ShellCmdUtil.executeCmd(command);
        } catch (Exception t) {
            Log.w(TAG, "executeCmdAsRoot failed cmd=" + command, t);
            return false;
        }
    }

    @VisibleForTesting
    static boolean parsePingReachableOutput(@NonNull String output) {
        if (output.isEmpty()) {
            return false;
        }
        String lower = output.toLowerCase(Locale.US);
        if (lower.contains("unreachable")
                || lower.contains("100% packet loss")
                || lower.contains("wrong data byte")) {
            return false;
        }
        Matcher stats = PING_STATS_PATTERN.matcher(output);
        if (!stats.find()) {
            return false;
        }
        int received = Integer.parseInt(stats.group(2));
        if (received < 1) {
            return false;
        }
        Matcher loss = PING_LOSS_PATTERN.matcher(output);
        if (loss.find()) {
            int lossPercent = Integer.parseInt(loss.group(1));
            if (lossPercent > 0) {
                return false;
            }
        }
        return true;
    }

    private static String readProcessOutput(@NonNull InputStream stream) throws Exception {
        StringBuilder builder = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(stream, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                builder.append(line).append('\n');
            }
        }
        return builder.toString();
    }

    private static String summarizeOutput(@NonNull String output) {
        String compact = output.replace('\n', ' ').trim();
        return compact.length() <= 240 ? compact : compact.substring(0, 240) + "...";
    }
}
