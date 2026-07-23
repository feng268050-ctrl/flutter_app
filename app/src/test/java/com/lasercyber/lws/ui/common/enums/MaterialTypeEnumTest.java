package com.lasercyber.lws.ui.common.enums;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class MaterialTypeEnumTest {

    @Test
    public void isDefinedType_accepts_codes_1_through_6() {
        for (MaterialTypeEnum e : MaterialTypeEnum.values()) {
            assertTrue(MaterialTypeEnum.isDefinedType(e.getType()));
        }
    }

    @Test
    public void isDefinedType_rejects_null_and_unknown_codes() {
        assertFalse(MaterialTypeEnum.isDefinedType(null));
        assertFalse(MaterialTypeEnum.isDefinedType(0));
        assertFalse(MaterialTypeEnum.isDefinedType(7));
        assertFalse(MaterialTypeEnum.isDefinedType(99));
    }
}
