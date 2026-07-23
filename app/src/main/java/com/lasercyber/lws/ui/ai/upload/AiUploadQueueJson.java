package com.lasercyber.lws.ui.ai.upload;

import com.lasercyber.lws.ui.common.utils.json.GsonInitUtils;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import androidx.annotation.Nullable;

/**
 * Simple JSON array of task id strings for {@code queue/pending.json}.
 */
final class AiUploadQueueJson {
    private AiUploadQueueJson() {
    }

    static List<String> readIds(File file) {
        if (!file.isFile()) {
            return new ArrayList<>();
        }
        try (InputStreamReader r = new InputStreamReader(new FileInputStream(file), StandardCharsets.UTF_8)) {
            String[] arr = GsonInitUtils.getGson().fromJson(r, String[].class);
            if (arr == null) {
                return new ArrayList<>();
            }
            List<String> out = new ArrayList<>(arr.length);
            for (String s : arr) {
                if (s != null && !s.isEmpty()) {
                    out.add(s);
                }
            }
            return out;
        } catch (IOException | RuntimeException e) {
            return new ArrayList<>();
        }
    }

    static void writeIds(File file, List<String> ids) throws IOException {
        File parent = file.getParentFile();
        if (parent != null && !parent.isDirectory() && !parent.mkdirs()) {
            throw new IOException("mkdirs failed: " + parent);
        }
        try (OutputStreamWriter w = new OutputStreamWriter(new FileOutputStream(file), StandardCharsets.UTF_8)) {
            GsonInitUtils.getGson().toJson(ids, w);
        }
    }

    static void appendId(File file, String id) throws IOException {
        List<String> cur = readIds(file);
        cur.add(id);
        writeIds(file, cur);
    }

    static void removeId(File file, String id) throws IOException {
        List<String> cur = readIds(file);
        cur.remove(id);
        writeIds(file, cur);
    }

    @Nullable
    static String peekFirst(File file) {
        List<String> cur = readIds(file);
        return cur.isEmpty() ? null : cur.get(0);
    }

    static void removeFirstMatching(File file, String expectedId) throws IOException {
        List<String> cur = readIds(file);
        if (cur.isEmpty()) {
            return;
        }
        if (expectedId.equals(cur.get(0))) {
            cur.remove(0);
            writeIds(file, cur);
        }
    }
}
