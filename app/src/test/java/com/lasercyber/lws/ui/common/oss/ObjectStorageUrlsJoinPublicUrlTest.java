package com.lasercyber.lws.ui.common.oss;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

import org.junit.Test;

public class ObjectStorageUrlsJoinPublicUrlTest {

    @Test
    public void joinPublicBaseUrl_normalizesSlashes() {
        assertEquals("https://cdn.example/a/b.jpg",
                ObjectStorageUrls.joinPublicBaseUrl("https://cdn.example/", "/a/b.jpg"));
        assertEquals("https://cdn.example/a/b.jpg",
                ObjectStorageUrls.joinPublicBaseUrl("https://cdn.example///", "a/b.jpg"));
    }

    @Test
    public void joinPublicBaseUrl_nullOrBlankBase() {
        assertNull(ObjectStorageUrls.joinPublicBaseUrl(null, "a.jpg"));
        assertNull(ObjectStorageUrls.joinPublicBaseUrl("   ", "a.jpg"));
    }
}
