package com.lasercyber.lws.ui.common.utils;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertFalse;

import android.content.Context;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import com.lasercyber.lws.ui.bean.entity.StaticData;

import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class CommonUseTextResolverInstrumentedTest {

    @Test
    public void fill_resolves_defined_material_to_non_empty_label() {
        Context ctx = InstrumentationRegistry.getInstrumentation().getTargetContext();
        assertEquals("com.lasercyber.lws.ui", ctx.getPackageName());

        StaticData d = new StaticData();
        d.setCommonUse(1);
        CommonUseTextResolver.fillForRemoteSnapshot(d);
        assertNotEquals(CommonUseTextResolver.UNKNOWN, d.getCommonUseText());
        assertFalse(d.getCommonUseText().isEmpty());
    }

    @Test
    public void fill_null_common_use_is_unknown() {
        StaticData d = new StaticData();
        d.setCommonUse(null);
        CommonUseTextResolver.fillForRemoteSnapshot(d);
        assertEquals(CommonUseTextResolver.UNKNOWN, d.getCommonUseText());
    }

    @Test
    public void fill_undefined_code_is_unknown() {
        StaticData d = new StaticData();
        d.setCommonUse(99);
        CommonUseTextResolver.fillForRemoteSnapshot(d);
        assertEquals(CommonUseTextResolver.UNKNOWN, d.getCommonUseText());
    }
}
