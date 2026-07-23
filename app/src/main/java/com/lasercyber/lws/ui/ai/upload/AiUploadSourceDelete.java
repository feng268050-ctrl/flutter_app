package com.lasercyber.lws.ui.ai.upload;

import android.content.Context;
import android.os.Build;
import android.util.Log;

import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.File;
import java.io.IOException;
import java.util.LinkedHashSet;
import java.util.Set;

/**
 * Deletes the original {@code imageSource} file after a successful Worker {@code ai-report},
 * only when the path is under app-owned storage (see change {@code delete-local-images-after-ai-upload-complete}).
 */
public final class AiUploadSourceDelete {

    private static final String TAG = LogTAGConstant.AiUploadCoordinator;
    private static final String SOURCE_LOCATION_APP_OWNED = "app_owned";
    private static final String SOURCE_LOCATION_SHARED_PICTURES = "shared_pictures";

    private AiUploadSourceDelete() {
    }

    /**
     * True when {@code candidate} exists and its canonical path lies under one of the app-owned roots
     * ({@code files/}, {@code cache/}, {@code no_backup/}, {@code Android/data/<pkg>/files}, etc.).
     */
    public static boolean isUnderAppOwnedRoots(Context context, File candidate) throws IOException {
        if (candidate == null || !candidate.exists()) {
            return false;
        }
        File canon = candidate.getCanonicalFile();
        return isCanonicalPathUnderRoots(canon.getAbsolutePath(), canonicalAppOwnedRootPrefixes(context));
    }

    /**
     * True when {@code candidate} is a file path we are allowed to delete after a successful upload:
     * app-owned roots OR shared Pictures root.
     */
    public static boolean isEligibleSourceForPostSuccessDelete(Context context, File candidate) throws IOException {
        if (candidate == null || !candidate.exists()) {
            return false;
        }
        File canon = candidate.getCanonicalFile();
        String path = canon.getAbsolutePath();
        return isCanonicalPathUnderRoots(path, canonicalDeleteEligibleRootPrefixes(context));
    }

    /**
     * Classifies source location for optional metadata observability.
     * Returns null when the source path is not eligible for deletion.
     */
    @Nullable
    public static String classifySourceLocationForDeletion(Context context, File candidate) throws IOException {
        if (candidate == null || !candidate.exists()) {
            return null;
        }
        File canon = candidate.getCanonicalFile();
        String path = canon.getAbsolutePath();
        if (isCanonicalPathUnderRoots(path, canonicalAppOwnedRootPrefixes(context))) {
            return SOURCE_LOCATION_APP_OWNED;
        }
        if (isCanonicalPathUnderRoots(path, canonicalSharedPicturesRootPrefixes())) {
            return SOURCE_LOCATION_SHARED_PICTURES;
        }
        return null;
    }

    /**
     * After a successful upload and task-directory removal, delete the original source image when persisted
     * metadata points to an app-owned file that is not the staged task copy.
     *
     * @param stagedImageCanonicalAbsolutePath canonical absolute path of {@code tasks/<uuid>/image.jpg} before task
     *                                         directory deletion; may be null if unknown
     */
    public static void tryDeleteSourceIfEligible(
            Context context,
            @Nullable String sourceAbsolutePath,
            @Nullable String stagedImageCanonicalAbsolutePath) {
        if (sourceAbsolutePath == null || sourceAbsolutePath.trim().isEmpty()) {
            return;
        }
        Context app = context.getApplicationContext();
        File source;
        try {
            source = new File(sourceAbsolutePath.trim()).getCanonicalFile();
        } catch (IOException e) {
            Log.w(TAG, "source delete: bad path " + sourceAbsolutePath, e);
            return;
        }
        if (!source.isFile()) {
            return;
        }
        try {
            if (!isEligibleSourceForPostSuccessDelete(app, source)) {
                return;
            }
        } catch (IOException e) {
            Log.w(TAG, "source delete: root check failed", e);
            return;
        }
        if (stagedImageCanonicalAbsolutePath != null
                && source.getAbsolutePath().equals(stagedImageCanonicalAbsolutePath)) {
            return;
        }
        if (!source.delete()) {
            Log.w(TAG, "source delete: delete returned false for " + source.getAbsolutePath());
        }
    }

    static Set<String> canonicalDeleteEligibleRootPrefixes(Context context) throws IOException {
        Set<String> out = canonicalAppOwnedRootPrefixes(context);
        out.addAll(canonicalSharedPicturesRootPrefixes());
        return out;
    }

    static Set<String> canonicalAppOwnedRootPrefixes(Context context) throws IOException {
        Context app = context.getApplicationContext();
        Set<String> out = new LinkedHashSet<>();
        addCanonicalPrefix(out, app.getFilesDir());
        addCanonicalPrefix(out, app.getCacheDir());
        addCanonicalPrefix(out, app.getNoBackupFilesDir());
        addCanonicalPrefix(out, app.getExternalFilesDir(null));
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            File[] dirs = app.getExternalFilesDirs(null);
            if (dirs != null) {
                for (File f : dirs) {
                    addCanonicalPrefix(out, f);
                }
            }
        }
        return out;
    }

    static Set<String> canonicalSharedPicturesRootPrefixes() throws IOException {
        Set<String> out = new LinkedHashSet<>();
        addCanonicalPrefix(out, new File("/sdcard/Pictures"));
        addCanonicalPrefix(out, new File("/storage/emulated/0/Pictures"));
        return out;
    }

    private static void addCanonicalPrefix(Set<String> out, @Nullable File dir) throws IOException {
        if (dir == null) {
            return;
        }
        out.add(dir.getCanonicalFile().getAbsolutePath());
    }

    /**
     * Package-private for unit tests.
     */
    static boolean isCanonicalPathUnderRoots(String canonicalFileAbsolutePath, Set<String> canonicalRootAbsolutePaths) {
        for (String root : canonicalRootAbsolutePaths) {
            if (canonicalFileAbsolutePath.equals(root)) {
                return true;
            }
            if (canonicalFileAbsolutePath.startsWith(root + File.separator)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Package-private for unit tests: whether {@code canonicalSource} would be deleted (all checks except I/O delete).
     */
    static boolean mayDeleteSourceAfterUpload(
            File canonicalSource,
            @Nullable String stagedImageCanonicalAbsolutePath,
            Set<String> canonicalRootAbsolutePaths) {
        if (!canonicalSource.isFile()) {
            return false;
        }
        String path = canonicalSource.getAbsolutePath();
        if (!isCanonicalPathUnderRoots(path, canonicalRootAbsolutePaths)) {
            return false;
        }
        return stagedImageCanonicalAbsolutePath == null
                || !path.equals(stagedImageCanonicalAbsolutePath);
    }
}
