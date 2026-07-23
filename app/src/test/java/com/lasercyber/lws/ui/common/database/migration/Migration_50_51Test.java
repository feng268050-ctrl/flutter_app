package com.lasercyber.lws.ui.common.database.migration;

import static org.junit.Assert.assertNotNull;

import org.junit.Test;

public class Migration_50_51Test {

    @Test
    public void migration_class_existsFor50To51() {
        assertNotNull(new Migration_50_51());
    }
}
