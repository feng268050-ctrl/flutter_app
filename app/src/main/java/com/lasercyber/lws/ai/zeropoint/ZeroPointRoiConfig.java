package com.lasercyber.lws.ai.zeropoint;
import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import com.lasercyber.lws.ai.bridge.AssetDeployer;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

/**
 * Parsed {@code zero_point_roi.json} fields used for overlay geometry.
 */
public final class ZeroPointRoiConfig {

    private static final String ROI_ASSET = "zero_point_roi.json";
    private static final String ROI_RUNTIME_FILE = "zero_point_roi.json";

    public final int sourceWidth;
    public final int sourceHeight;
    public final double referenceX;
    public final double referenceY;

    public ZeroPointRoiConfig(int sourceWidth, int sourceHeight, double referenceX, double referenceY) {
        this.sourceWidth = sourceWidth;
        this.sourceHeight = sourceHeight;
        this.referenceX = referenceX;
        this.referenceY = referenceY;
    }

    @NonNull
    public ScaledReference scaleReferenceToFrame(int frameWidth, int frameHeight) {
        if (sourceWidth <= 0 || sourceHeight <= 0 || frameWidth <= 0 || frameHeight <= 0) {
            return new ScaledReference(referenceX, referenceY);
        }
        double scaleX = frameWidth / (double) sourceWidth;
        double scaleY = frameHeight / (double) sourceHeight;
        return new ScaledReference(referenceX * scaleX, referenceY * scaleY);
    }

    @Nullable
    public static ZeroPointRoiConfig load(@Nullable Context context) {
        if (context == null) {
            return null;
        }
        try {
            AssetDeployer paths = AssetDeployer.deploy(context.getApplicationContext());
            File roiFile = new File(paths.getProjectRoot(), ROI_RUNTIME_FILE);
            AssetDeployer.deployAssetIfChanged(context.getApplicationContext(), ROI_ASSET, roiFile);
            String raw = new String(Files.readAllBytes(roiFile.toPath()), StandardCharsets.UTF_8);
            JsonObject root = new JsonParser().parse(raw.trim()).getAsJsonObject();
            int sourceW = 0;
            int sourceH = 0;
            if (root.has("source_size") && root.get("source_size").isJsonArray()) {
                var array = root.getAsJsonArray("source_size");
                if (array.size() >= 2) {
                    sourceW = array.get(0).getAsInt();
                    sourceH = array.get(1).getAsInt();
                }
            }
            double refX = 0.0;
            double refY = 0.0;
            if (root.has("reference_zero_xy") && root.get("reference_zero_xy").isJsonArray()) {
                var ref = root.getAsJsonArray("reference_zero_xy");
                if (ref.size() >= 2) {
                    refX = ref.get(0).getAsDouble();
                    refY = ref.get(1).getAsDouble();
                }
            }
            return new ZeroPointRoiConfig(sourceW, sourceH, refX, refY);
        } catch (IOException | RuntimeException e) {
            return null;
        }
    }

    public static final class ScaledReference {
        public final double x;
        public final double y;

        ScaledReference(double x, double y) {
            this.x = x;
            this.y = y;
        }
    }
}
