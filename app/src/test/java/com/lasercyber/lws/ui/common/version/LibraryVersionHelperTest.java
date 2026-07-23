package com.lasercyber.lws.ui.common.version;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class LibraryVersionHelperTest {

    @Test
    public void isUnset_placeholderBlankOrNull() {
        assertTrue(LibraryVersionHelper.isUnset(null));
        assertTrue(LibraryVersionHelper.isUnset(""));
        assertTrue(LibraryVersionHelper.isUnset("  "));
        assertTrue(LibraryVersionHelper.isUnset("--"));
        assertTrue(LibraryVersionHelper.isUnset(" -- "));
        assertTrue(LibraryVersionHelper.isUnset("-"));
        assertTrue(LibraryVersionHelper.isUnset(" - "));
    }

    @Test
    public void isUnset_realVersion() {
        assertFalse(LibraryVersionHelper.isUnset("1.0.1"));
    }

    @Test
    public void normalizeForStorage_clearsPlaceholder() {
        assertEquals("", LibraryVersionHelper.normalizeForStorage("--"));
        assertEquals("", LibraryVersionHelper.normalizeForStorage("-"));
        assertEquals("1.0.1", LibraryVersionHelper.normalizeForStorage("1.0.1"));
    }

    @Test
    public void normalizeForCompare_clearsPlaceholder() {
        assertNull(LibraryVersionHelper.normalizeForCompare("--"));
        assertNull(LibraryVersionHelper.normalizeForCompare("-"));
        assertEquals("1.0.1", LibraryVersionHelper.normalizeForCompare("1.0.1"));
    }

    @Test
    public void isNewerThan_treatsPlaceholderBaselineAsMissing() {
        assertTrue(SemanticVersionHelper.isNewerThan("1.0.1", "--"));
        // Equal bundled core version still imports when DB only has the UI placeholder.
        assertTrue(SemanticVersionHelper.isNewerThan("1.0.0", "--"));
        assertTrue(SemanticVersionHelper.isNewerThan("1.0.1", "-"));
    }
}
