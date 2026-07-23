package com.lasercyber.lws.ui.network.http.local;

import org.junit.Assert;
import org.junit.Test;

import java.util.HashMap;
import java.util.Map;

public class ProcessVideoLocalUploadTest {

    @Test
    public void ensureMultipartUtf8Charset_appendsWhenMultipartWithoutCharset() {
        Map<String, String> headers = new HashMap<>();
        headers.put("content-type", "multipart/form-data; boundary=----abc");
        ProcessVideoLocalUpload.ensureMultipartUtf8Charset(headers);
        Assert.assertEquals("multipart/form-data; boundary=----abc; charset=UTF-8", headers.get("content-type"));
    }

    @Test
    public void ensureMultipartUtf8Charset_leavesExistingCharset() {
        Map<String, String> headers = new HashMap<>();
        headers.put("content-type", "multipart/form-data; boundary=x; charset=iso-8859-1");
        ProcessVideoLocalUpload.ensureMultipartUtf8Charset(headers);
        Assert.assertEquals("multipart/form-data; boundary=x; charset=iso-8859-1", headers.get("content-type"));
    }

    @Test
    public void ensureMultipartUtf8Charset_ignoresNonMultipart() {
        Map<String, String> headers = new HashMap<>();
        headers.put("content-type", "application/json");
        ProcessVideoLocalUpload.ensureMultipartUtf8Charset(headers);
        Assert.assertEquals("application/json", headers.get("content-type"));
    }
}
