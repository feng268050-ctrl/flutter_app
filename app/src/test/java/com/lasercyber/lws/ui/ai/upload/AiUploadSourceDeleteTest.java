package com.lasercyber.lws.ui.ai.upload;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.LinkedHashSet;
import java.util.Set;

public class AiUploadSourceDeleteTest {

    @Rule
    public TemporaryFolder tmp = new TemporaryFolder();

    @Test
    public void isCanonicalPathUnderRoots_childPath() {
        Set<String> roots = new LinkedHashSet<>();
        roots.add("/data/user/0/pkg/files");
        assertTrue(AiUploadSourceDelete.isCanonicalPathUnderRoots(
                "/data/user/0/pkg/files/ai_upload/x.jpg", roots));
    }

    @Test
    public void isCanonicalPathUnderRoots_exactRootFile() {
        Set<String> roots = new LinkedHashSet<>();
        roots.add("/data/user/0/pkg/files");
        assertTrue(AiUploadSourceDelete.isCanonicalPathUnderRoots("/data/user/0/pkg/files", roots));
    }

    @Test
    public void isCanonicalPathUnderRoots_notUnderRoot() {
        Set<String> roots = new LinkedHashSet<>();
        roots.add("/data/user/0/pkg/files");
        assertFalse(AiUploadSourceDelete.isCanonicalPathUnderRoots("/sdcard/Pictures/x.jpg", roots));
    }

    @Test
    public void isCanonicalPathUnderRoots_prefixTrapSibling() {
        Set<String> roots = new LinkedHashSet<>();
        roots.add("/data/user/0/pkg/files");
        assertFalse(AiUploadSourceDelete.isCanonicalPathUnderRoots("/data/user/0/pkg/files_backup/x.jpg", roots));
    }

    @Test
    public void mayDelete_underRootAndDifferentFromStaged() throws IOException {
        File root = tmp.newFolder("files");
        File sub = new File(root, "a");
        assertTrue(sub.mkdirs());
        File img = new File(sub, "x.jpg");
        Files.write(img.toPath(), "x".getBytes(StandardCharsets.UTF_8));
        File canon = img.getCanonicalFile();
        Set<String> roots = new LinkedHashSet<>();
        roots.add(root.getCanonicalFile().getAbsolutePath());
        assertTrue(AiUploadSourceDelete.mayDeleteSourceAfterUpload(
                canon, "/other/staged/image.jpg", roots));
    }

    @Test
    public void mayDelete_sharedPicturesAllowed() throws IOException {
        File pics = tmp.newFolder("Pictures");
        File img = new File(pics, "a.jpg");
        Files.write(img.toPath(), "x".getBytes(StandardCharsets.UTF_8));
        Set<String> roots = new LinkedHashSet<>();
        roots.add(pics.getCanonicalPath());
        assertTrue(AiUploadSourceDelete.mayDeleteSourceAfterUpload(
                img.getCanonicalFile(), null, roots));
    }

    @Test
    public void mayDelete_sharedDownloadNotAllowedWhenOnlyPicturesWhitelisted() throws IOException {
        File root = tmp.newFolder("storage");
        File pictures = new File(root, "Pictures");
        File download = new File(root, "Download");
        assertTrue(pictures.mkdirs());
        assertTrue(download.mkdirs());
        File img = new File(download, "a.jpg");
        Files.write(img.toPath(), "x".getBytes(StandardCharsets.UTF_8));
        Set<String> roots = new LinkedHashSet<>();
        roots.add(pictures.getCanonicalPath());
        assertFalse(AiUploadSourceDelete.mayDeleteSourceAfterUpload(
                img.getCanonicalFile(), null, roots));
    }

    @Test
    public void canonicalPathUnderRoots_handlesSdcardAliasWhenConfigured() {
        Set<String> roots = new LinkedHashSet<>();
        roots.add("/storage/emulated/0/Pictures");
        assertTrue(AiUploadSourceDelete.isCanonicalPathUnderRoots(
                "/storage/emulated/0/Pictures/cam.jpg", roots));
        assertFalse(AiUploadSourceDelete.isCanonicalPathUnderRoots(
                "/storage/emulated/0/Download/cam.jpg", roots));
    }

    @Test
    public void mayDelete_sameAsStagedCanonicalSkipped() throws IOException {
        File root = tmp.newFolder("files");
        File img = new File(root, "x.jpg");
        Files.write(img.toPath(), "x".getBytes(StandardCharsets.UTF_8));
        File canon = img.getCanonicalFile();
        Set<String> roots = new LinkedHashSet<>();
        roots.add(root.getCanonicalFile().getAbsolutePath());
        assertFalse(AiUploadSourceDelete.mayDeleteSourceAfterUpload(
                canon, canon.getAbsolutePath(), roots));
    }

    @Test
    public void mayDelete_notAFile() throws IOException {
        File root = tmp.newFolder("files");
        Set<String> roots = new LinkedHashSet<>();
        roots.add(root.getCanonicalFile().getAbsolutePath());
        File dir = new File(root, "nodir");
        assertTrue(dir.mkdirs());
        assertFalse(AiUploadSourceDelete.mayDeleteSourceAfterUpload(dir.getCanonicalFile(), null, roots));
    }
}
