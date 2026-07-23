package com.lasercyber.lws.ui.common.upgrade;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import org.junit.Test;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

public class OtaPackageSha512VerifierTest {

    private static String sha512HexUtf8(String s) throws NoSuchAlgorithmException {
        byte[] dig = MessageDigest.getInstance("SHA-512").digest(s.getBytes(StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder(dig.length * 2);
        for (byte b : dig) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    @Test
    public void normalize_strips_prefix_and_whitespace() throws Exception {
        String abcHex = sha512HexUtf8("abc");
        String n = OtaPackageSha512Verifier.normalizeExpectedHex(" sha512:" + abcHex + " \n");
        assertTrue(n.equals(abcHex));
    }

    @Test
    public void should_verify_when_non_empty() {
        assertTrue(OtaPackageSha512Verifier.shouldVerify("abc"));
        assertFalse(OtaPackageSha512Verifier.shouldVerify(""));
        assertFalse(OtaPackageSha512Verifier.shouldVerify(null));
    }

    @Test
    public void verify_matches_small_file() throws Exception {
        File f = File.createTempFile("ota-test-", ".bin");
        try {
            try (FileOutputStream fos = new FileOutputStream(f)) {
                fos.write("abc".getBytes(StandardCharsets.UTF_8));
            }
            OtaPackageSha512Verifier.verifyFileMatchesSha512Hex(f, sha512HexUtf8("abc"));
        } finally {
            //noinspection ResultOfMethodCallIgnored
            f.delete();
        }
    }

    @Test
    public void verify_rejects_wrong_digest() throws Exception {
        File f = File.createTempFile("ota-test-", ".bin");
        try {
            try (FileOutputStream fos = new FileOutputStream(f)) {
                fos.write("xyz".getBytes(StandardCharsets.UTF_8));
            }
            OtaPackageSha512Verifier.verifyFileMatchesSha512Hex(f, sha512HexUtf8("abc"));
            fail("expected IOException");
        } catch (IOException expected) {
            assertTrue(expected.getMessage().contains("mismatch"));
        } finally {
            //noinspection ResultOfMethodCallIgnored
            f.delete();
        }
    }
}
