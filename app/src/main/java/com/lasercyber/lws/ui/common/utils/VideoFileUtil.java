package com.lasercyber.lws.ui.common.utils;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.lasercyber.lws.ui.common.config.CameraConfig;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;

public class VideoFileUtil {

    private static final String TAG = LogTAGConstant.APPLICATION;
    private static volatile String path = CameraConfig.DEFAULT_VIDEO_SAVE_PATH;

    /**
     * Emulator lacks priv-app write access to {@link CameraConfig#DEFAULT_VIDEO_SAVE_PATH};
     * use app-scoped external storage instead.
     */
    public static void ensureRuntimePath(@Nullable Context context) {
        if (!AndroidEmulatorUtils.isLikelyEmulator() || context == null) {
            return;
        }
        File base = new File(context.getApplicationContext().getExternalFilesDir(null), "lws");
        if (!base.exists() && !base.mkdirs()) {
            Log.e(TAG, "ensureRuntimePath: failed to create " + base.getAbsolutePath());
            return;
        }
        path = base.getAbsolutePath();
        Log.i(TAG, "ensureRuntimePath: emulator video base=" + path);
    }

    /**
     * 设置视频保存路径
     * @param path
     */
    public static void setPath(String path) {
        VideoFileUtil.path = path;
    }
    public static String getPicturePath(String url) {
        return path +"/picture"+ "/" + urlDir(url) ;
    }

    public static File getPictureName(String url) {
        File file = new File(getPicturePath(url));
        file.mkdirs();

        File res = new File(file, new SimpleDateFormat("yy-MM-dd_HH-mm-ss").format(new Date()) + ".jpg");
        return res;
    }

    public static String getMoviePath(String url) {
        return path + "/movie"+ "/" + urlDir(url) ;
    }

    public static File getMovieName(String url) {
        File file = new File(getMoviePath(url));
        if (!file.exists() && !file.mkdirs()) {
            Log.e(TAG, "getMovieName: failed to create dir=" + file.getAbsolutePath());
        }

        File res = new File(file, new SimpleDateFormat("yy-MM-dd_HH-mm-ss").format(new Date()) + ".mp4");
        return res;
    }

    /** Ensures parent directories exist for a recording target path. */
    public static boolean ensureParentDirs(@NonNull String absolutePath) {
        File parent = new File(absolutePath).getParentFile();
        if (parent == null) {
            return false;
        }
        if (parent.exists()) {
            return parent.canWrite();
        }
        if (!parent.mkdirs()) {
            Log.e(TAG, "ensureParentDirs: mkdirs failed path=" + parent.getAbsolutePath());
            return false;
        }
        return parent.canWrite();
    }

    private static String urlDir(String url) {
        url = url.replace("://", "");
        url = url.replace("/", "");
        url = url.replace(".", "");

        if (url.length() > 64) {
            url.substring(0, 63);
        }

        return url;
    }

    /*
     * 截屏
     * */
    public static File getSnapFile(String url) {
        File file = new File(getPicturePath(url));
        file.mkdirs();

        File res = new File(file, "snap.jpg");
        return res;
    }
}
