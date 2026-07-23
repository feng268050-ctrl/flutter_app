package com.lasercyber.lws.ui.common.upgrade;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

/**
 * Verifies a local OTA package file against a manifest {@code sha512} value.
 * Expected format: 128 lowercase hex characters (optional {@code sha512:} prefix, whitespace ignored).
 */
public final class OtaPackageSha512Verifier {
    private static final int SHA512_HEX_LEN = 128;

    private OtaPackageSha512Verifier() {
    }

    public static boolean shouldVerify(@Nullable String expectedRaw) {
        return !normalizeExpectedHex(expectedRaw).isEmpty();
    }

    /**
     * @throws IOException if the file cannot be read, digest fails, expected format is invalid, or digest mismatch
     */
    public static void verifyFileMatchesSha512Hex(@NonNull File file, @Nullable String expectedRaw) throws IOException {
        String expectedHex = normalizeExpectedHex(expectedRaw);
        if (expectedHex.isEmpty()) {
            return;
        }
        if (expectedHex.length() != SHA512_HEX_LEN || !isHex(expectedHex)) {
            throw new IOException("invalid sha512 (need 128 hex chars)");
        }
        byte[] expected = hexToBytes(expectedHex);
        MessageDigest md;
        try {
            md = MessageDigest.getInstance("SHA-512");
        } catch (NoSuchAlgorithmException e) {
            throw new IOException("SHA-512 not available", e);
        }
        if (!file.isFile()) {
            throw new IOException("package file missing");
        }
        try (DigestInputStream in = new DigestInputStream(
                new BufferedInputStream(new FileInputStream(file), 8192), md)) {
            byte[] buf = new byte[8192];
            while (in.read(buf) != -1) {
                // digest updated by DigestInputStream
            }
        }
        byte[] actual = md.digest();
        if (!MessageDigest.isEqual(actual, expected)) {
            throw new IOException("sha512 mismatch");
        }
    }

    @NonNull
    static String normalizeExpectedHex(@Nullable String raw) {
        if (raw == null) {
            return "";
        }
        String s = raw.trim().toLowerCase();
        if (s.startsWith("sha512:")) {
            s = s.substring("sha512:".length()).trim();
        }
        StringBuilder out = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
                continue;
            }
            out.append(c);
        }
        return out.toString();
    }

    private static boolean isHex(String s) {
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if ((c < '0' || c > '9') && (c < 'a' || c > 'f')) {
                return false;
            }
        }
        return true;
    }

    private static byte[] hexToBytes(String hex) {
        int n = hex.length() / 2;
        byte[] out = new byte[n];
        for (int i = 0; i < n; i++) {
            int hi = Character.digit(hex.charAt(i * 2), 16);
            int lo = Character.digit(hex.charAt(i * 2 + 1), 16);
            if (hi < 0 || lo < 0) {
                throw new IllegalArgumentException("bad hex");
            }
            out[i] = (byte) ((hi << 4) + lo);
        }
        return out;
    }
}
