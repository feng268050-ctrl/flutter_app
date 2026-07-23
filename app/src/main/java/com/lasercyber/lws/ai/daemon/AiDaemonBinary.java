package com.lasercyber.lws.ai.daemon;

import android.content.Context;
import android.content.res.AssetManager;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

/**
 * Resolves {@code lws_ai_daemon} for ProcessBuilder spawn.
 * <p>
 * Preferred path: {@code nativeLibraryDir/liblws_ai_daemon.so} (AGP extracts jniLibs to an
 * exec-allowed directory). Fallback: extract from assets into a code-cache sibling (still may
 * fail on noexec mounts — assets remain for packaging/debug).
 */
public final class AiDaemonBinary {

    private static final String TAG = LogTAGConstant.AI_DAEMON;
    private static final String ASSET_ABI_DIR = "ai_daemon/arm64-v8a";
    private static final String JNI_SO_NAME = "liblws_ai_daemon.so";
    private static final String BINARY_NAME = "lws_ai_daemon";
    private static final String VERSION_FILE = "version.txt";

    private AiDaemonBinary() {
    }

    @Nullable
    public static ResolvedBinary resolve(@NonNull Context context) throws IOException {
        Context app = context.getApplicationContext();
        File nativeDir = new File(app.getApplicationInfo().nativeLibraryDir);
        File fromJni = new File(nativeDir, JNI_SO_NAME);
        if (fromJni.isFile() && fromJni.canExecute()) {
            String ver = readAssetVersion(app.getAssets());
            if (ver == null) {
                ver = "jniLibs";
            }
            Log.i(TAG, "resolve: using nativeLibraryDir " + fromJni.getAbsolutePath());
            return new ResolvedBinary(fromJni, ver, nativeDir);
        }
        Log.w(TAG, "resolve: " + JNI_SO_NAME + " missing under " + nativeDir
                + "; trying assets extract (may fail on noexec)");
        return installFromAssets(app);
    }

    @Nullable
    private static ResolvedBinary installFromAssets(@NonNull Context context) throws IOException {
        String bundledVersion = readAssetVersion(context.getAssets());
        if (bundledVersion == null) {
            Log.w(TAG, "resolve: no bundled lws_ai_daemon assets (run make ai)");
            return null;
        }
        // Prefer codeCacheDir: on some devices more likely to allow execute than filesDir.
        File versionDir = new File(context.getCodeCacheDir(), "ai_daemon/" + sanitizeDirName(bundledVersion));
        if (!versionDir.exists() && !versionDir.mkdirs()) {
            throw new IOException("mkdir failed " + versionDir);
        }
        File binary = new File(versionDir, BINARY_NAME);
        try (InputStream in = context.getAssets().open(ASSET_ABI_DIR + "/" + BINARY_NAME);
             FileOutputStream out = new FileOutputStream(binary)) {
            copyStream(in, out);
        }
        if (!binary.setExecutable(true, false)) {
            throw new IOException("chmod failed " + binary);
        }
        File cxxShared = new File(versionDir, "libc++_shared.so");
        try (InputStream in = context.getAssets().open(ASSET_ABI_DIR + "/libc++_shared.so");
             FileOutputStream out = new FileOutputStream(cxxShared)) {
            copyStream(in, out);
        }
        Log.i(TAG, "installed lws_ai_daemon version=" + bundledVersion + " path=" + binary.getAbsolutePath());
        return new ResolvedBinary(binary, bundledVersion, versionDir);
    }

    private static void copyStream(@NonNull InputStream in, @NonNull FileOutputStream out)
            throws IOException {
        byte[] buf = new byte[8192];
        int n;
        while ((n = in.read(buf)) >= 0) {
            if (n > 0) {
                out.write(buf, 0, n);
            }
        }
    }

    @Nullable
    private static String readAssetVersion(@NonNull AssetManager assets) {
        try (InputStream in = assets.open(ASSET_ABI_DIR + "/" + VERSION_FILE);
             BufferedReader r = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            String line = r.readLine();
            return line != null ? line.trim() : null;
        } catch (IOException e) {
            return null;
        }
    }

    @NonNull
    private static String sanitizeDirName(@NonNull String version) {
        return version.replaceAll("[^a-zA-Z0-9._-]", "_");
    }

    public static final class ResolvedBinary {
        public final File executable;
        public final String version;
        /** Directory containing the executable and libc++_shared.so for $ORIGIN / cwd. */
        public final File libraryDir;

        ResolvedBinary(@NonNull File executable, @NonNull String version, @NonNull File libraryDir) {
            this.executable = executable;
            this.version = version;
            this.libraryDir = libraryDir;
        }
    }
}
