package com.lasercyber.lws.ui.ai.upload;

import android.content.Context;

import java.io.File;
import java.util.Calendar;

/**
 * Layout under {@code Context#getFilesDir()}/ai_upload/ per {@code upload.md} section 6.
 */
public final class AiUploadPaths {
    static final String ROOT = "ai_upload";
    static final String TASKS = "tasks";
    static final String QUEUE = "queue";
    static final String PENDING = "pending.json";
    static final String IMAGE_NAME = "image.jpg";
    static final String METADATA = "metadata.json";
    static final String STATE = "state.json";

    private AiUploadPaths() {
    }

    public static File root(Context context) {
        return new File(context.getFilesDir(), ROOT);
    }

    public static File commonTemp(Context context) {
        return new File(new File(root(context), "common"), "temp");
    }

    /**
     * {@code .../ai_upload/yyyy/mm/dd/}
     */
    public static File dateDirectory(Context context, Calendar cal) {
        int y = cal.get(Calendar.YEAR);
        int m = cal.get(Calendar.MONTH) + 1;
        int d = cal.get(Calendar.DAY_OF_MONTH);
        File base = root(context);
        return new File(new File(new File(base, String.valueOf(y)), pad2(m)), pad2(d));
    }

    /**
     * {@code .../ai_upload/yyyy/mm/dd/<model>/}
     */
    public static File modelDirectory(Context context, Calendar cal, AiUploadModel model) {
        return new File(dateDirectory(context, cal), model.wireValue());
    }

    public static File taskDirectory(File modelDir, String taskId) {
        return new File(new File(modelDir, TASKS), taskId);
    }

    public static File queueDir(File modelDir) {
        return new File(modelDir, QUEUE);
    }

    public static File pendingQueueFile(File modelDir) {
        return new File(queueDir(modelDir), PENDING);
    }

    private static String pad2(int n) {
        if (n < 10) {
            return "0" + n;
        }
        return String.valueOf(n);
    }
}
