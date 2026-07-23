package com.lasercyber.lws.ui.ai.upload;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.config.DeviceApiOriginConfig;

import java.io.File;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

import okhttp3.HttpUrl;

/**
 * Batch entry point for queueing shared Pictures directory images through the normal AI upload queue.
 */
public final class AiUploadPictureDirectoryQueue {
    private static final String TAG = "AiUpload";
    public static final File DEFAULT_PICTURES_DIR = new File("/sdcard/Pictures");

    private AiUploadPictureDirectoryQueue() {
    }

    /**
     * Queue all supported images under {@code /sdcard/Pictures} and pin the Worker API to the test origin.
     */
    public static int enqueueDefaultPicturesToTestWorker(@NonNull Context context) {
        return enqueueDefaultPicturesToTestWorker(context, null);
    }

    /**
     * Queue all supported images under {@code /sdcard/Pictures} and pin the Worker API to the test origin.
     */
    public static int enqueueDefaultPicturesToTestWorker(@NonNull Context context, @Nullable String sn) {
        return enqueuePicturesToTestWorker(context, DEFAULT_PICTURES_DIR, AiUploadModel.LENS, 0, sn);
    }

    /**
     * Queue all supported images under {@code picturesDir} and pin the Worker API to the test origin.
     */
    public static int enqueuePicturesToTestWorker(
            @NonNull Context context,
            @NonNull File picturesDir,
            @NonNull AiUploadModel model,
            int type
    ) {
        return enqueuePicturesToTestWorker(context, picturesDir, model, type, null);
    }

    /**
     * Queue all supported images under {@code picturesDir} and pin the Worker API to the test origin.
     */
    public static int enqueuePicturesToTestWorker(
            @NonNull Context context,
            @NonNull File picturesDir,
            @NonNull AiUploadModel model,
            int type,
            @Nullable String sn
    ) {
        DeviceApiOriginConfig.setPinnedBase(HttpUrl.get(DeviceApiOriginConfig.HTTPS_ORIGIN_TEST));
        return enqueuePictures(context, picturesDir, model, type, sn, HttpUrl.get(DeviceApiOriginConfig.HTTPS_ORIGIN_TEST));
    }

    /**
     * Queue all supported images under {@code picturesDir} using the currently pinned Worker API origin.
     */
    public static int enqueuePictures(
            @NonNull Context context,
            @NonNull File picturesDir,
            @NonNull AiUploadModel model,
            int type
    ) {
        return enqueuePictures(context, picturesDir, model, type, null, DeviceApiOriginConfig.getPinnedBase());
    }

    /**
     * Queue one WorkManager work per supported image under {@code picturesDir}.
     */
    public static int enqueuePictures(
            @NonNull Context context,
            @NonNull File picturesDir,
            @NonNull AiUploadModel model,
            int type,
            @Nullable String sn,
            @Nullable HttpUrl apiBase
    ) {
        Context app = context.getApplicationContext();
        List<File> imageFiles = listSupportedImageFiles(picturesDir);
        if (imageFiles.isEmpty()) {
            Log.i(TAG, "pictures batch enqueue skipped: no supported images under "
                    + picturesDir.getAbsolutePath());
            return 0;
        }

        for (File imageFile : imageFiles) {
            Log.i(TAG, "pictures single-work enqueue: " + imageFile.getAbsolutePath());
            AiUploadSingleImageWorker.enqueue(app, imageFile, model, type, sn, apiBase);
        }
        Log.i(TAG, "pictures single-work enqueue completed count=" + imageFiles.size()
                + " dir=" + picturesDir.getAbsolutePath());
        return imageFiles.size();
    }

    public static List<File> listSupportedImageFiles(@NonNull File picturesDir) {
        if (!picturesDir.isDirectory()) {
            return Collections.emptyList();
        }
        ArrayList<File> out = new ArrayList<>();
        ArrayDeque<File> pending = new ArrayDeque<>();
        pending.add(picturesDir);
        while (!pending.isEmpty()) {
            File dir = pending.removeFirst();
            File[] children = dir.listFiles();
            if (children == null || children.length == 0) {
                continue;
            }
            Arrays.sort(children, (a, b) -> a.getAbsolutePath().compareTo(b.getAbsolutePath()));
            for (File child : children) {
                if (child.isDirectory()) {
                    pending.addLast(child);
                } else if (child.isFile() && isSupportedImageFile(child)) {
                    out.add(child);
                }
            }
        }
        out.sort((a, b) -> a.getAbsolutePath().compareTo(b.getAbsolutePath()));
        return Collections.unmodifiableList(out);
    }

    static boolean isSupportedImageFile(@NonNull File file) {
        String name = file.getName().toLowerCase(Locale.US);
        return name.endsWith(".jpg")
                || name.endsWith(".jpeg")
                || name.endsWith(".png")
                || name.endsWith(".webp");
    }
}
