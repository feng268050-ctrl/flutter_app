package com.lasercyber.lws.ui.network.mediamtx;

import android.content.Context;
import android.content.res.AssetManager;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.version.LibraryVersionFilename;
import com.lasercyber.lws.ui.common.version.SemanticVersionHelper;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

/**
 * Extracts bundled MediaMTX from APK assets and tracks installed semver under app-private storage.
 */
public final class MediaMtxBinary {

    private static final String TAG = LogTAGConstant.MEDIA_MTX_RELAY;
    private static final String ASSET_ABI_DIR = "mediamtx/arm64-v8a";
    private static final String BINARY_NAME = "mediamtx";
    private static final String VERSION_FILE = "version.txt";
    private static final String INSTALLED_VERSION_FILE = "installed-version.txt";

    private MediaMtxBinary() {
    }

    @NonNull
    public static File installRoot(@NonNull Context context) {
        return new File(context.getFilesDir(), "mediamtx");
    }

    @Nullable
    public static String readInstalledVersion(@NonNull Context context) {
        File f = new File(installRoot(context), INSTALLED_VERSION_FILE);
        if (!f.isFile()) {
            return null;
        }
        try (BufferedReader r = new BufferedReader(new InputStreamReader(
                new FileInputStream(f), StandardCharsets.UTF_8))) {
            String line = r.readLine();
            return line != null ? line.trim() : null;
        } catch (IOException e) {
            Log.w(TAG, "readInstalledVersion failed", e);
            return null;
        }
    }

    /**
     * Resolves the executable path, installing from bundled assets or OTA staging when needed.
     *
     * @return absolute path to {@code mediamtx}, or null when unavailable (emulator / missing asset build)
     */
    @Nullable
    public static ResolvedBinary resolve(@NonNull Context context) throws IOException {
        Context app = context.getApplicationContext();
        applyOtaStagingIfNewer(app);
        String bundledVersion = readAssetVersion(app.getAssets());
        if (bundledVersion == null) {
            Log.w(TAG, "resolve: no bundled mediamtx assets (run make mediamtx)");
            return readExistingInstall(app);
        }
        String installed = readInstalledVersion(app);
        if (installed != null && isLegacyLinuxInstall(installed, bundledVersion)) {
            Log.i(TAG, "resolve: replacing legacy linux mediamtx (" + installed + " -> " + bundledVersion + ")");
            deleteRecursive(installRoot(app));
            installed = null;
        }
        if (installed != null && SemanticVersionHelper.compare(installed, bundledVersion) > 0) {
            return readExistingInstall(app);
        }
        if (installed != null && SemanticVersionHelper.compare(installed, bundledVersion) == 0) {
            ResolvedBinary existing = readExistingInstall(app);
            if (existing != null) {
                return existing;
            }
        }
        return installFromAssets(app, bundledVersion);
    }

    /** Semver ranks {@code 1.11.3} above {@code 1.11.3-android}; force APK android bundle over old linux cache. */
    private static boolean isLegacyLinuxInstall(@NonNull String installed, @NonNull String bundledVersion) {
        return bundledVersion.contains("-android") && !installed.contains("-android");
    }

    @Nullable
    private static ResolvedBinary readExistingInstall(@NonNull Context context) {
        File root = installRoot(context);
        File[] dirs = root.listFiles(File::isDirectory);
        if (dirs == null) {
            return null;
        }
        File bestDir = null;
        String bestVer = null;
        for (File dir : dirs) {
            if ("ota-staging".equals(dir.getName())) {
                continue;
            }
            File bin = new File(dir, BINARY_NAME);
            if (!bin.canExecute()) {
                continue;
            }
            String ver = readVersionFile(new File(dir, VERSION_FILE));
            if (ver == null) {
                ver = dir.getName();
            }
            if (bestVer == null || SemanticVersionHelper.compare(ver, bestVer) > 0) {
                bestVer = ver;
                bestDir = dir;
            }
        }
        if (bestDir == null) {
            return null;
        }
        return new ResolvedBinary(new File(bestDir, BINARY_NAME), bestVer,
                new File(bestDir, "mediamtx.yml"));
    }

    @NonNull
    private static ResolvedBinary installFromAssets(@NonNull Context context,
                                                    @NonNull String version) throws IOException {
        File versionDir = new File(installRoot(context), sanitizeDirName(version));
        if (!versionDir.exists() && !versionDir.mkdirs()) {
            throw new IOException("mkdir failed " + versionDir);
        }
        File binary = new File(versionDir, BINARY_NAME);
        try (InputStream in = context.getAssets().open(ASSET_ABI_DIR + "/" + BINARY_NAME);
             FileOutputStream out = new FileOutputStream(binary)) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) >= 0) {
                if (n > 0) {
                    out.write(buf, 0, n);
                }
            }
        }
        if (!binary.setExecutable(true, false)) {
            throw new IOException("chmod failed " + binary);
        }
        writeTextFile(new File(versionDir, VERSION_FILE), version);
        writeInstalledVersion(context, version);
        Log.i(TAG, "installed mediamtx version=" + version + " path=" + binary.getAbsolutePath());
        return new ResolvedBinary(binary, version, new File(versionDir, "mediamtx.yml"));
    }

    private static void applyOtaStagingIfNewer(@NonNull Context context) throws IOException {
        File staging = new File(installRoot(context), "ota-staging");
        File stagedBin = new File(staging, BINARY_NAME);
        if (!stagedBin.isFile()) {
            return;
        }
        String stagedVer = readVersionFile(new File(staging, VERSION_FILE));
        if (stagedVer == null) {
            stagedVer = "0.0.0";
        }
        String installed = readInstalledVersion(context);
        if (installed != null && SemanticVersionHelper.compare(stagedVer, installed) <= 0) {
            deleteRecursive(staging);
            return;
        }
        File destDir = new File(installRoot(context), sanitizeDirName(stagedVer) + "-ota");
        deleteRecursive(destDir);
        if (!destDir.mkdirs()) {
            throw new IOException("mkdir " + destDir);
        }
        copyFile(stagedBin, new File(destDir, BINARY_NAME));
        new File(destDir, BINARY_NAME).setExecutable(true, false);
        File stagedConf = new File(staging, "mediamtx.yml");
        if (stagedConf.isFile()) {
            copyFile(stagedConf, new File(destDir, "mediamtx.yml"));
        }
        writeTextFile(new File(destDir, VERSION_FILE), stagedVer);
        writeInstalledVersion(context, stagedVer);
        deleteRecursive(staging);
        Log.i(TAG, "applied OTA mediamtx version=" + stagedVer);
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

    @Nullable
    private static String readVersionFile(@NonNull File f) {
        if (!f.isFile()) {
            return null;
        }
        try (BufferedReader r = new BufferedReader(new InputStreamReader(
                new FileInputStream(f), StandardCharsets.UTF_8))) {
            String line = r.readLine();
            return line != null ? line.trim() : null;
        } catch (IOException e) {
            return null;
        }
    }

    private static void writeInstalledVersion(@NonNull Context context, @NonNull String version)
            throws IOException {
        writeTextFile(new File(installRoot(context), INSTALLED_VERSION_FILE), version);
    }

    private static void writeTextFile(@NonNull File f, @NonNull String text) throws IOException {
        try (FileOutputStream out = new FileOutputStream(f)) {
            out.write(text.getBytes(StandardCharsets.UTF_8));
        }
    }

    @NonNull
    private static String sanitizeDirName(@NonNull String version) {
        return version.replaceAll("[^a-zA-Z0-9._-]", "_");
    }

    private static void copyFile(@NonNull File from, @NonNull File to) throws IOException {
        try (InputStream in = new FileInputStream(from);
             FileOutputStream out = new FileOutputStream(to)) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) >= 0) {
                if (n > 0) {
                    out.write(buf, 0, n);
                }
            }
        }
    }

    private static void deleteRecursive(@NonNull File f) {
        if (f.isDirectory()) {
            File[] kids = f.listFiles();
            if (kids != null) {
                for (File kid : kids) {
                    deleteRecursive(kid);
                }
            }
        }
        //noinspection ResultOfMethodCallIgnored
        f.delete();
    }

    /**
     * @return true if {@code candidateVersion} is newer than installed (or nothing installed).
     */
    public static boolean isCandidateNewer(@Nullable String installed, @Nullable String candidateVersion) {
        if (candidateVersion == null || candidateVersion.isEmpty()) {
            return false;
        }
        if (installed == null || installed.isEmpty()) {
            return true;
        }
        return SemanticVersionHelper.compare(candidateVersion, installed) > 0;
    }

    @Nullable
    public static String versionFromOtaFileName(@NonNull String fileName) {
        String seg = LibraryVersionFilename.extractVersionSegment(fileName);
        if (seg != null) {
            return seg.replaceAll("(?i)-arm64.*$", "");
        }
        if (fileName.toLowerCase().startsWith("mediamtx")) {
            int u = fileName.indexOf('_');
            if (u > 0 && u + 1 < fileName.length()) {
                return fileName.substring(u + 1).replaceAll("(?i)-arm64.*$", "");
            }
        }
        return null;
    }

    public static final class ResolvedBinary {
        public final File executable;
        public final String version;
        public final File configFile;

        ResolvedBinary(@NonNull File executable, @NonNull String version, @NonNull File configFile) {
            this.executable = executable;
            this.version = version;
            this.configFile = configFile;
        }
    }
}
