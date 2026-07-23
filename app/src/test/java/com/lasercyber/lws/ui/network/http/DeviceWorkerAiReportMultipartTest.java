package com.lasercyber.lws.ui.network.http;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

import okhttp3.MultipartBody;

public class DeviceWorkerAiReportMultipartTest {

    @Test
    public void multipart_has_type_model_image_and_optional_stat() throws IOException {
        File f = File.createTempFile("shot", ".jpg");
        try (FileOutputStream o = new FileOutputStream(f)) {
            o.write(new byte[]{0x42});
        }
        try {
            MultipartBody withoutStat = DeviceWorkerAiReportClient.buildMultipart(0, "lens", f, null);
            assertEquals(3, withoutStat.size());
            assertTrue(containsDispositionName(withoutStat, "type"));
            assertTrue(containsDispositionName(withoutStat, "model"));
            assertTrue(containsDispositionName(withoutStat, "image"));

            MultipartBody withStat = DeviceWorkerAiReportClient.buildMultipart(0, "metal", f, "{\"k\":1}");
            assertEquals(4, withStat.size());
            assertTrue(containsDispositionName(withStat, "stat"));
        } finally {
            //noinspection ResultOfMethodCallIgnored
            f.delete();
        }
    }

    private static boolean containsDispositionName(MultipartBody body, String formName) {
        for (MultipartBody.Part part : body.parts()) {
            okhttp3.Headers headers = part.headers();
            if (headers == null) {
                continue;
            }
            String cd = headers.get("Content-Disposition");
            if (cd != null && cd.contains("name=\"" + formName + "\"")) {
                return true;
            }
        }
        return false;
    }
}
