package com.lasercyber.lws.ui.common.upgrade;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assume.assumeTrue;

import androidx.test.ext.junit.runners.AndroidJUnit4;

import com.lasercyber.lws.ui.bean.entity.ProcessParametersData;

import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.File;
import java.util.List;

/**
 * Optional on-device check when the reference template exists at the path below (developer machine).
 */
@RunWith(AndroidJUnit4.class)
public class ProcessLibXlsxImportInstrumentedTest {

    private static final String REFERENCE_XLSX =
            "/Users/ayon/Downloads/V1.2.18/工艺库_V1.4.xlsx";

    @Test
    public void importReferenceXlsxIfPresent() {
        File f = new File(REFERENCE_XLSX);
        assumeTrue("Reference xlsx not found at " + f.getAbsolutePath(), f.exists());

        List<ProcessParametersData> list = EasyExcelUtil.proFileConvert(f);
        assertFalse(list.isEmpty());
        ProcessParametersData first = list.get(0);
        assertNotNull(first.getName());
    }
}
