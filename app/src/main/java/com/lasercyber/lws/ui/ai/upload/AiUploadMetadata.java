package com.lasercyber.lws.ui.ai.upload;

import java.io.Serializable;

/**
 * {@code metadata.json} shape aligned with {@code upload.md} section 7 (subset).
 */
public class AiUploadMetadata implements Serializable {
    public String sn;
    public String model;
    public int type;
    public String timestamp_device;
    /**
     * Optional absolute path of the original image passed to {@link AiUploadCoordinator#enqueue};
     * populated only when the path is eligible for post-success deletion.
     */
    public String source_image_absolute_path;
    /**
     * Optional source location classification for logs/diagnostics.
     * Current values: "app_owned", "shared_pictures".
     */
    public String source_location;
}
