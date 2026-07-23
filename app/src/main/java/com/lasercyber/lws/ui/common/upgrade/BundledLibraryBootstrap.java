package com.lasercyber.lws.ui.common.upgrade;

import android.content.Context;
import android.util.Log;

import com.blankj.utilcode.util.GsonUtils;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.lasercyber.lws.ui.bean.entity.DeviceInfo;
import com.lasercyber.lws.ui.bean.entity.ProcessParamsVideo;
import com.lasercyber.lws.ui.bean.entity.VideoInfo;
import com.lasercyber.lws.ui.common.cache.MemoryCacheManager;
import com.lasercyber.lws.ui.common.config.DeviceModelConfig;
import com.lasercyber.lws.ui.common.constant.CacheKey;
import com.lasercyber.lws.ui.common.constant.LogTAGConstant;
import com.lasercyber.lws.ui.common.constant.VideoUploadStatus;
import com.lasercyber.lws.ui.common.database.AppDatabase;
import com.lasercyber.lws.ui.common.utils.VideoFileUtils;
import com.lasercyber.lws.ui.repository.DeviceInfoDto;
import com.lasercyber.lws.ui.repository.ProcessProcessVideoDao;
import com.lasercyber.lws.ui.common.version.LibraryVersionFilename;
import com.lasercyber.lws.ui.common.version.LibraryVersionHelper;
import com.lasercyber.lws.ui.common.version.SemanticVersionHelper;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.zip.CRC32;

/**
 * Imports bundled process-library / videos from assets when newer than app-private copies.
 * AI native libraries ({@code libai.so}, {@code librknnrt.so}, {@code libc++_shared.so}) ship in APK
 * {@code jniLibs} via {@code make ai}; there is no separate ai-library zip asset.
 */
public final class BundledLibraryBootstrap {

    private static final String TAG = LogTAGConstant.APPLICATION;

    private static final String ASSET_PROCESS = "process-library";
    private static final String ASSET_VIDEOS = "videos";
    private static final String BUNDLED_VIDEOS_ROOT = "bundled-videos";
    private static final String PROCESS_SOURCE_META = "__source_filename.txt";
    private static final String VIDEO_SOURCE_FINGERPRINT = "__source_fingerprint.txt";

    private BundledLibraryBootstrap() {
    }

    public static void run(Context appContext) {
        Context ctx = appContext.getApplicationContext();
        try {
            DeviceInfoDto dao = AppDatabase.getInstance(ctx).deviceInfoDto();
            DeviceInfo info = dao.getOneData();
            if (info == null) {
                info = new DeviceInfo();
            }
            boolean changed = false;
            try {
                changed |= maybeImportProcessLibrary(ctx, info);
            } catch (Throwable t) {
                Log.e(TAG, "BundledLibraryBootstrap: process-library import failed", t);
            }
            try {
                maybeImportBundledVideos(ctx);
            } catch (Throwable t) {
                Log.e(TAG, "BundledLibraryBootstrap: bundled videos import failed", t);
            }
            if (changed) {
                if (info.getId() == null) {
                    long id = dao.insert(info);
                    info.setId((int) id);
                } else {
                    dao.update(info);
                }
                MemoryCacheManager.getInstance().putSerializableNoNotice(CacheKey.DEVICE_INFO_KEY, info);
            }
        } catch (Throwable t) {
            Log.e(TAG, "BundledLibraryBootstrap failed before/after imports", t);
        }
    }

    private static boolean maybeImportProcessLibrary(Context ctx, DeviceInfo info) throws IOException {
        String[] names = ctx.getAssets().list(ASSET_PROCESS);
        if (names == null || names.length == 0) {
            Log.i(TAG, "bundled process-library: no assets");
            return false;
        }
        String sourceName = resolveProcessSourceName(ctx, names);
        if (sourceName == null) {
            Log.w(TAG, "bundled process-library: cannot find source filename");
            return false;
        }
        String seg = LibraryVersionFilename.extractVersionSegment(sourceName);
        if (seg == null) {
            Log.w(TAG, "bundled process-library: cannot parse version from " + sourceName);
            return false;
        }
        String assetCoreVersion = SemanticVersionHelper.toCoreVersion(seg);
        if (assetCoreVersion == null) {
            Log.w(TAG, "bundled process-library: cannot normalize version from " + seg);
            return false;
        }
        String installed = LibraryVersionHelper.normalizeForCompare(info.getProcessLibVersion());
        if (!SemanticVersionHelper.isNewerThan(assetCoreVersion, installed)) {
            Log.i(TAG, "bundled process-library: skip (not newer than data) asset="
                    + assetCoreVersion + " data=" + installed);
            return false;
        }
        // Process library file is import-only; keep no persistent xlsx in app files.
        File legacyDir = new File(ctx.getFilesDir(), "bundled-libraries/process-library");
        if (legacyDir.exists()) {
            deleteRecursive(legacyDir);
        }
        List<String> xlsxFiles = listProcessXlsxFiles(names);
        if (xlsxFiles.isEmpty()) {
            Log.w(TAG, "bundled process-library: no xlsx files under assets/process-library");
            return false;
        }
        String rawModel = DeviceModelConfig.getModel();
        ProcessLibraryAssetSelector.SelectionResult selection =
                ProcessLibraryAssetSelector.select(xlsxFiles, rawModel);
        String selectedXlsx = selection.selectedFileName;
        if (selectedXlsx == null || selectedXlsx.trim().isEmpty()) {
            Log.w(TAG, "bundled process-library: selector returned empty file");
            return false;
        }
        if (selection.fallbackUsed) {
            Log.w(TAG, "bundled process-library: model-specific xlsx not found, rawModel=" + rawModel
                    + ", normalizedModel=" + selection.normalizedModel
                    + ", fallback=" + selectedXlsx);
        }
        File tempXlsx = new File(ctx.getCacheDir(), "process-library-import.xlsx");
        copyAsset(ctx, ASSET_PROCESS + "/" + selectedXlsx, tempXlsx);
        Log.i(TAG, "bundled process-library: importing " + selectedXlsx
                + " source=" + sourceName + " as v=" + assetCoreVersion);
        try {
            ProcessLibraryImporter.importFromXlsx(tempXlsx, assetCoreVersion, info);
        } finally {
            if (!tempXlsx.delete()) {
                Log.w(TAG, "bundled process-library: temp xlsx delete failed");
            }
        }
        return true;
    }

    private static List<String> listProcessXlsxFiles(String[] names) {
        ArrayList<String> files = new ArrayList<>();
        for (String name : names) {
            if (name == null) {
                continue;
            }
            if (name.toLowerCase().endsWith(".xlsx")) {
                files.add(name);
            }
        }
        return files;
    }

    private static String resolveProcessSourceName(Context ctx, String[] names) {
        String meta = readProcessSourceMeta(ctx);
        if (meta != null) {
            return meta;
        }
        for (String name : names) {
            if (name == null) {
                continue;
            }
            if (name.toLowerCase().endsWith(".zip") || name.toLowerCase().endsWith(".xlsx")) {
                return name;
            }
        }
        return null;
    }

    private static String readProcessSourceMeta(Context ctx) {
        try (InputStream in = ctx.getAssets().open(ASSET_PROCESS + "/" + PROCESS_SOURCE_META)) {
            String raw = new String(readFully(in), StandardCharsets.UTF_8).trim();
            return raw.isEmpty() ? null : raw;
        } catch (IOException ignored) {
            return null;
        }
    }

    private static byte[] readFully(InputStream in) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buf = new byte[4096];
        int n;
        while ((n = in.read(buf)) != -1) {
            out.write(buf, 0, n);
        }
        return out.toByteArray();
    }

    private static void maybeImportBundledVideos(Context ctx) throws IOException {
        String[] names = ctx.getAssets().list(ASSET_VIDEOS);
        if (names == null || names.length == 0) {
            Log.i(TAG, "bundled videos: no assets");
            return;
        }
        ProcessProcessVideoDao dao = AppDatabase.getInstance(ctx).processProcessVideoDao();
        for (String jsonName : names) {
            if (jsonName == null || !jsonName.toLowerCase(Locale.US).endsWith(".json")) {
                continue;
            }
            try {
                importBundledVideoSeed(ctx, dao, names, jsonName);
            } catch (Throwable t) {
                Log.e(TAG, "bundled videos: import failed for " + jsonName, t);
            }
        }
    }

    private static void importBundledVideoSeed(Context ctx,
                                              ProcessProcessVideoDao dao,
                                              String[] assetNames,
                                              String jsonName) throws IOException {
        String jsonAssetPath = ASSET_VIDEOS + "/" + jsonName;
        String rawJson;
        try (InputStream in = ctx.getAssets().open(jsonAssetPath)) {
            rawJson = new String(readFully(in), StandardCharsets.UTF_8);
        }
        JsonObject json = GsonUtils.fromJson(rawJson, JsonObject.class);
        if (json == null) {
            Log.w(TAG, "bundled videos: invalid json " + jsonName);
            return;
        }

        String videoId = jsonString(json, "videoId");
        Integer processType = jsonInteger(json, "processType", null);
        Long createTime = jsonLong(json, "createTime", null);
        if (isBlank(videoId) || processType == null || createTime == null) {
            Log.w(TAG, "bundled videos: missing required fields in " + jsonName);
            return;
        }

        String videoFile = jsonString(json, "videoFile");
        if (isBlank(videoFile)) {
            videoFile = deriveVideoFileName(jsonName, assetNames);
        }
        videoFile = safeAssetFileName(videoFile);
        if (isBlank(videoFile) || !containsAsset(assetNames, videoFile)) {
            Log.w(TAG, "bundled videos: missing video asset for " + jsonName + ", videoFile=" + videoFile);
            return;
        }

        String fingerprint = buildBundledVideoFingerprint(ctx, jsonName, videoFile);
        if (fingerprint == null) {
            Log.w(TAG, "bundled videos: fingerprint failed for " + jsonName);
            return;
        }

        File videoDir = new File(new File(ctx.getFilesDir(), BUNDLED_VIDEOS_ROOT), sanitizeFilePart(videoId));
        File copiedVideo = new File(videoDir, videoFile);
        File fingerprintFile = new File(videoDir, VIDEO_SOURCE_FINGERPRINT);
        String installedFingerprint = readTextFile(fingerprintFile);
        boolean fingerprintChanged = !fingerprint.equals(installedFingerprint);
        ProcessParamsVideo existing = dao.selectByVideoId(videoId);

        if (existing == null && installedFingerprint != null && !fingerprintChanged) {
            Log.i(TAG, "bundled videos: skip deleted unchanged seed videoId=" + videoId);
            return;
        }

        boolean copied = false;
        if (!copiedVideo.isFile() || fingerprintChanged) {
            copyAsset(ctx, ASSET_VIDEOS + "/" + videoFile, copiedVideo);
            copied = true;
        }

        if (existing == null) {
            ProcessParamsVideo seed = buildBundledVideoRow(json, videoId, processType, createTime, copiedVideo);
            dao.insert(seed);
            writeTextFile(fingerprintFile, fingerprint);
            Log.i(TAG, "bundled videos: inserted videoId=" + videoId + " file=" + copiedVideo.getAbsolutePath());
            return;
        }

        if (fingerprintChanged) {
            ProcessParamsVideo seed = buildBundledVideoRow(json, videoId, processType, createTime, copiedVideo);
            seed.setId(existing.getId());
            dao.update(seed);
            writeTextFile(fingerprintFile, fingerprint);
            Log.i(TAG, "bundled videos: updated videoId=" + videoId + " file=" + copiedVideo.getAbsolutePath());
            return;
        }

        if (copied || installedFingerprint == null || !copiedVideo.getAbsolutePath().equals(existing.getVideoPath())) {
            existing.setVideoPath(copiedVideo.getAbsolutePath());
            dao.update(existing);
            writeTextFile(fingerprintFile, fingerprint);
            Log.i(TAG, "bundled videos: repaired copied file videoId=" + videoId);
        }
    }

    private static ProcessParamsVideo buildBundledVideoRow(JsonObject json,
                                                           String videoId,
                                                           int processType,
                                                           long createTime,
                                                           File copiedVideo) {
        ProcessParamsVideo row = new ProcessParamsVideo();
        row.setVideoId(videoId);
        row.setVideoPath(copiedVideo.getAbsolutePath());
        row.setProcessType(processType);
        row.setCreateTime(createTime);
        row.setMaterialType(jsonInteger(json, "materialType", null));
        row.setProcessParametersJson(resolveProcessParametersJson(json));
        row.setDuration(jsonLong(json, "duration", 0L));
        row.setFileSize(jsonLong(json, "fileSize", 0L));
        if (row.getFileSize() <= 0L) {
            row.setFileSize(copiedVideo.length());
        }
        if (row.getDuration() <= 0L) {
            VideoInfo info = VideoFileUtils.readVideoFileInfo(copiedVideo.getAbsolutePath());
            if (info != null) {
                row.setDuration(info.getDuration());
                if (row.getFileSize() <= 0L) {
                    row.setFileSize(info.getFileSize());
                }
            }
        }
        row.setResolution(jsonString(json, "resolution"));
        row.setUploadStatus(jsonInteger(json, "uploadStatus", VideoUploadStatus.NOT_INITIATED));
        row.setUploadProgress(jsonInteger(json, "uploadProgress", 0));
        row.setCoverUrl(jsonString(json, "coverUrl"));
        row.setVideoUrl(jsonString(json, "videoUrl"));
        return row;
    }

    private static String resolveProcessParametersJson(JsonObject json) {
        String explicit = jsonString(json, "processParametersJson");
        if (!isBlank(explicit)) {
            return explicit;
        }
        JsonElement processParameters = json.get("processParameters");
        if (processParameters != null && !processParameters.isJsonNull()) {
            return processParameters.toString();
        }
        return null;
    }

    private static String buildBundledVideoFingerprint(Context ctx, String jsonName, String videoFile) {
        String json = buildAssetFingerprint(ctx, ASSET_VIDEOS + "/" + jsonName);
        String video = buildAssetFingerprint(ctx, ASSET_VIDEOS + "/" + videoFile);
        if (json == null || video == null) {
            return null;
        }
        return json + "|" + video;
    }

    private static String buildAssetFingerprint(Context ctx, String assetPath) {
        CRC32 crc = new CRC32();
        long length = 0L;
        try (InputStream in = ctx.getAssets().open(assetPath)) {
            byte[] buffer = new byte[8192];
            int read;
            while ((read = in.read(buffer)) != -1) {
                crc.update(buffer, 0, read);
                length += read;
            }
            return assetPath + ":" + length + ":" + Long.toHexString(crc.getValue());
        } catch (IOException e) {
            Log.w(TAG, "bundled asset fingerprint failed " + assetPath, e);
            return null;
        }
    }

    private static String deriveVideoFileName(String jsonName, String[] assetNames) {
        String base = stripExtension(jsonName);
        for (String name : assetNames) {
            if (name == null) {
                continue;
            }
            if (base.equals(stripExtension(name)) && isVideoAsset(name)) {
                return name;
            }
        }
        return null;
    }

    private static boolean isVideoAsset(String name) {
        String lower = name == null ? "" : name.toLowerCase(Locale.US);
        return lower.endsWith(".mp4")
                || lower.endsWith(".mov")
                || lower.endsWith(".m4v")
                || lower.endsWith(".avi")
                || lower.endsWith(".mkv")
                || lower.endsWith(".webm");
    }

    private static boolean containsAsset(String[] assetNames, String fileName) {
        for (String name : assetNames) {
            if (fileName.equals(name)) {
                return true;
            }
        }
        return false;
    }

    private static String stripExtension(String name) {
        if (name == null) {
            return "";
        }
        int dot = name.lastIndexOf('.');
        return dot > 0 ? name.substring(0, dot) : name;
    }

    private static String safeAssetFileName(String raw) {
        if (raw == null) {
            return null;
        }
        return new File(raw).getName();
    }

    private static String sanitizeFilePart(String raw) {
        if (raw == null) {
            return "";
        }
        return raw.replaceAll("[^A-Za-z0-9._-]", "_");
    }

    private static boolean isBlank(String raw) {
        return raw == null || raw.trim().isEmpty();
    }

    private static String jsonString(JsonObject json, String key) {
        JsonElement element = json == null ? null : json.get(key);
        if (element == null || element.isJsonNull()) {
            return null;
        }
        try {
            return element.getAsString();
        } catch (RuntimeException e) {
            return null;
        }
    }

    private static Integer jsonInteger(JsonObject json, String key, Integer defaultValue) {
        JsonElement element = json == null ? null : json.get(key);
        if (element == null || element.isJsonNull()) {
            return defaultValue;
        }
        try {
            return element.getAsInt();
        } catch (RuntimeException e) {
            return defaultValue;
        }
    }

    private static Long jsonLong(JsonObject json, String key, Long defaultValue) {
        JsonElement element = json == null ? null : json.get(key);
        if (element == null || element.isJsonNull()) {
            return defaultValue;
        }
        try {
            return element.getAsLong();
        } catch (RuntimeException e) {
            return defaultValue;
        }
    }

    private static String readTextFile(File file) {
        if (file == null || !file.isFile()) {
            return null;
        }
        try (InputStream in = new FileInputStream(file)) {
            String raw = new String(readFully(in), StandardCharsets.UTF_8).trim();
            return raw.isEmpty() ? null : raw;
        } catch (IOException e) {
            Log.w(TAG, "bundled library bootstrap: read fingerprint failed " + file.getAbsolutePath(), e);
            return null;
        }
    }

    private static void writeTextFile(File file, String value) throws IOException {
        File parent = file.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IOException("mkdir " + parent);
        }
        try (FileOutputStream out = new FileOutputStream(file)) {
            out.write(value.getBytes(StandardCharsets.UTF_8));
            out.flush();
        }
    }

    private static void copyAsset(Context ctx, String assetPath, File destFile) throws IOException {
        File parent = destFile.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IOException("mkdir " + parent);
        }
        try (InputStream in = ctx.getAssets().open(assetPath);
             FileOutputStream out = new FileOutputStream(destFile)) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) != -1) {
                out.write(buf, 0, n);
            }
        }
    }

    private static void deleteRecursive(File f) {
        if (f.isDirectory()) {
            File[] ch = f.listFiles();
            if (ch != null) {
                for (File c : ch) {
                    deleteRecursive(c);
                }
            }
        }
        if (f.exists()) {
            //noinspection ResultOfMethodCallIgnored
            f.delete();
        }
    }

    private static void deleteChildren(File dir) {
        File[] children = dir.listFiles();
        if (children == null) {
            return;
        }
        for (File child : children) {
            deleteRecursive(child);
        }
    }
}
