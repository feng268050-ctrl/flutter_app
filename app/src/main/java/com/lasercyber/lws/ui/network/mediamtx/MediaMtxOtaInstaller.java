package com.lasercyber.lws.ui.network.mediamtx;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Stages MediaMTX OTA payloads for install on next {@link MediaMtxBinary#resolve(Context)}.
 */
public final class MediaMtxOtaInstaller {

    private static final String TAG = LogTAGConstant.MEDIA_MTX_RELAY;
    private static final String BINARY_NAME = "mediamtx";

    private MediaMtxOtaInstaller() {
    }

    /**
     * @return true if the file was recognized and staged (or skipped as not newer)
     */
    public static boolean tryStageFromOtaFile(@NonNull Context context, @NonNull File file) {
        String name = file.getName();
        String lower = name.toLowerCase();
        if (!lower.contains("mediamtx")) {
            return false;
        }
        if (MediaMtxRelayCoordinator.getInstance().isRelayReady()) {
            Log.w(TAG, "OTA mediamtx deferred: relay running name=" + name);
            return true;
        }
        String version = MediaMtxBinary.versionFromOtaFileName(name);
        if (version == null) {
            Log.w(TAG, "OTA mediamtx: cannot parse version from " + name);
            return false;
        }
        String installed = MediaMtxBinary.readInstalledVersion(context);
        if (!MediaMtxBinary.isCandidateNewer(installed, version)) {
            Log.i(TAG, "OTA mediamtx skip (not newer) candidate=" + version + " installed=" + installed);
            return true;
        }
        File staging = new File(MediaMtxBinary.installRoot(context), "ota-staging");
        try {
            deleteRecursive(staging);
            if (!staging.mkdirs()) {
                throw new IOException("mkdir staging");
            }
            if (lower.endsWith(".zip")) {
                extractZip(file, staging);
            } else {
                copyFile(file, new File(staging, BINARY_NAME));
            }
            writeText(new File(staging, "version.txt"), version);
            new File(staging, BINARY_NAME).setExecutable(true, false);
            Log.i(TAG, "OTA mediamtx staged version=" + version);
            return true;
        } catch (IOException e) {
            Log.e(TAG, "OTA mediamtx stage failed", e);
            deleteRecursive(staging);
            return false;
        }
    }

    private static void extractZip(@NonNull File zip, @NonNull File destDir) throws IOException {
        try (ZipInputStream zis = new ZipInputStream(new FileInputStream(zip))) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                if (entry.isDirectory()) {
                    continue;
                }
                String en = entry.getName();
                String base = en.contains("/") ? en.substring(en.lastIndexOf('/') + 1) : en;
                File out = new File(destDir, base);
                try (FileOutputStream fos = new FileOutputStream(out)) {
                    byte[] buf = new byte[8192];
                    int n;
                    while ((n = zis.read(buf)) >= 0) {
                        if (n > 0) {
                            fos.write(buf, 0, n);
                        }
                    }
                }
                zis.closeEntry();
            }
        }
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

    private static void writeText(@NonNull File f, @NonNull String text) throws IOException {
        try (FileOutputStream out = new FileOutputStream(f)) {
            out.write(text.getBytes());
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
}
