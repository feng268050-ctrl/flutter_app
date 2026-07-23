package com.lasercyber.lws.ui.ai.upload;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.List;

public class AiUploadPictureDirectoryQueueTest {

    @Rule
    public TemporaryFolder tmp = new TemporaryFolder();

    @Test
    public void listSupportedImageFiles_recursesAndFiltersSupportedImages() throws IOException {
        File root = tmp.newFolder("Pictures");
        File sub = new File(root, "Sub");
        assertTrue(sub.mkdirs());
        File jpg = write(root, "b.JPG");
        File png = write(root, "a.png");
        File webp = write(sub, "c.webp");
        write(root, "note.txt");

        List<File> out = AiUploadPictureDirectoryQueue.listSupportedImageFiles(root);

        assertEquals(3, out.size());
        assertTrue(out.contains(jpg));
        assertTrue(out.contains(png));
        assertTrue(out.contains(webp));
    }

    @Test
    public void listSupportedImageFiles_missingDirectoryReturnsEmpty() {
        File missing = new File(tmp.getRoot(), "missing");
        assertTrue(AiUploadPictureDirectoryQueue.listSupportedImageFiles(missing).isEmpty());
    }

    @Test
    public void isSupportedImageFile_rejectsNonImageExtension() throws IOException {
        File text = write(tmp.getRoot(), "image.txt");
        assertFalse(AiUploadPictureDirectoryQueue.isSupportedImageFile(text));
    }

    private static File write(File dir, String name) throws IOException {
        File file = new File(dir, name);
        Files.write(file.toPath(), "x".getBytes(StandardCharsets.UTF_8));
        return file;
    }
}
