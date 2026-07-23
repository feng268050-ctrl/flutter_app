package com.lasercyber.lws.ui.ai.upload;

/**
 * Detection model discriminator for {@code multipart model} field ({@code upload.md}).
 */
public enum AiUploadModel {
    LENS("lens"),
    METAL("metal");

    private final String wireValue;

    AiUploadModel(String wireValue) {
        this.wireValue = wireValue;
    }

    public String wireValue() {
        return wireValue;
    }
}
