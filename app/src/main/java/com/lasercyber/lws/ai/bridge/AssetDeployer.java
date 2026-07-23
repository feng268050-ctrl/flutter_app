package com.lasercyber.lws.ai.bridge;

import android.content.Context;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * 将 AI 配套 config.yaml 解压到 App 私有目录的运行时路径。
 * 引擎 nativeCreate 需要文件系统路径，而 assets 不能直接访问。
 */
public class AssetDeployer {

    private static final String TAG = "AssetDeployer";
    private static final String PROJECT_DIR = "lens_guard";
    private static final String CONFIG_FILE = "config.yaml";

    private final String configPath;
    private final String projectRoot;

    private AssetDeployer(String configPath, String projectRoot) {
        this.configPath = configPath;
        this.projectRoot = projectRoot;
    }

    public String getConfigPath() {
        return configPath;
    }

    public String getProjectRoot() {
        return projectRoot;
    }

    /**
     * 部署 {@code assets/config.yaml} 到运行时路径；内容变化时同步覆盖。
     *
     * @return 包含 configPath 和 projectRoot 的结果对象
     */
    public static AssetDeployer deploy(Context context) {
        File projectDir = new File(context.getFilesDir(), PROJECT_DIR);
        if (!projectDir.exists()) {
            boolean created = projectDir.mkdirs();
            if (!created) {
                throw new IllegalStateException("Failed to create project directory: " + projectDir.getAbsolutePath());
            }
            Log.d(TAG, "Created project dir path=" + projectDir.getAbsolutePath());
        }

        File configFile = new File(projectDir, CONFIG_FILE);
        deployAssetIfChanged(context, CONFIG_FILE, configFile);
        if (!configFile.isFile() || !configFile.canRead()) {
            throw new IllegalStateException("Config deploy failed. asset=" + CONFIG_FILE
                    + " target=" + configFile.getAbsolutePath());
        }

        return new AssetDeployer(configFile.getAbsolutePath(), projectDir.getAbsolutePath());
    }

    /**
     * Deploy a bundled asset when missing or content differs from the APK asset.
     */
    public static void deployAssetIfChanged(Context context, String assetName, File destFile) {
        copyFromAssetsIfChanged(context, assetName, destFile);
    }

    private static void copyFromAssetsIfChanged(Context context, String assetName, File destFile) {
        try {
            if (destFile.isFile() && sameContentFromAssets(context, assetName, destFile)) {
                Log.d(TAG, "config.yaml already matches bundled asset, skipping deploy");
                return;
            }
            copyFromAssets(context, assetName, destFile);
        } catch (IOException e) {
            String detail = "Failed to deploy asset. asset=" + assetName + " target=" + destFile.getAbsolutePath();
            Log.e(TAG, detail, e);
            throw new IllegalStateException(detail, e);
        }
    }

    private static boolean sameContentFromAssets(Context context, String assetName, File destFile)
            throws IOException {
        try (InputStream asset = context.getAssets().open(assetName);
             InputStream existing = new FileInputStream(destFile)) {
            byte[] left = new byte[4096];
            byte[] right = new byte[4096];
            int assetRead;
            while ((assetRead = asset.read(left)) != -1) {
                int existingRead = existing.read(right);
                if (assetRead != existingRead) {
                    return false;
                }
                for (int i = 0; i < assetRead; i++) {
                    if (left[i] != right[i]) {
                        return false;
                    }
                }
            }
            return existing.read(right) == -1;
        }
    }

    private static void copyFromAssets(Context context, String assetName, File destFile) throws IOException {
        File parent = destFile.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IOException("mkdir " + parent);
        }
        try (InputStream in = context.getAssets().open(assetName);
             FileOutputStream out = new FileOutputStream(destFile)) {
            byte[] buffer = new byte[4096];
            int read;
            while ((read = in.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
            out.flush();
            Log.d(TAG, "Deployed " + assetName + " → " + destFile.getAbsolutePath());
        }
    }
}
