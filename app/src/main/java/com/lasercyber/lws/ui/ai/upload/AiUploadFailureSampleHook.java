package com.lasercyber.lws.ui.ai.upload;

import android.content.Context;
import android.util.Log;

import com.lasercyber.lws.ui.common.handler.DeviceStatusPut;
import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import java.io.File;

/**
 * Entry points when the inference pipeline has a failure image ready to upload ({@code upload.md} type {@code 0}).
 * Callers must supply a JPEG/PNG file on local storage; {@link com.lasercyber.lws.ai.AiManager} callbacks
 * alone do not include image bytes — wire the frame-save path that matches your product flow.
 */
public final class AiUploadFailureSampleHook {
    private static final String TAG = "AiUpload";

    private AiUploadFailureSampleHook() {
    }

    public static int enqueueAllPicturesToTestWorker(Context context) {
        Log.i(TAG, "debug enqueue all /sdcard/Pictures images via App queue to test Worker");
        return AiUploadPictureDirectoryQueue.enqueueDefaultPicturesToTestWorker(context);
    }

    public static void enqueueLensFailureSample(Context context, File imageFile) {
        String stat = GsonInitUtils.getGson().toJson(new DeviceStatusPut().packRemoteSnapshot(context));
        Log.i(TAG, "debug enqueue lens sample via App queue: "
                + (imageFile == null ? "null" : imageFile.getAbsolutePath()));
        AiUploadCoordinator.enqueue(context, AiUploadModel.LENS, 0, imageFile, stat);
    }

    public static void enqueueMetalFailureSample(Context context, File imageFile) {
        String stat = GsonInitUtils.getGson().toJson(new DeviceStatusPut().packRemoteSnapshot(context));
        Log.i(TAG, "debug enqueue metal sample via App queue: "
                + (imageFile == null ? "null" : imageFile.getAbsolutePath()));
        AiUploadCoordinator.enqueue(context, AiUploadModel.METAL, 0, imageFile, stat);
    }
}
