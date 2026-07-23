package com.lasercyber.lws.ui.common.ai.vision;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;

import com.lasercyber.lws.ui.bean.entity.vo.ProcessParamsVideoVo;
import com.lasercyber.lws.ui.common.constant.ModelConstant;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;

import org.junit.Test;

public class AiVisionWorkInfoLabelsTest {

    @Test
    public void resolveVideo_nullVideo_returnsNull() {
        assertNull(AiVisionWorkInfoLabels.resolveVideo(null));
    }

    @Test
    public void resolveVideo_usesColumnsWhenJsonAbsent() {
        ProcessParamsVideoVo video = new ProcessParamsVideoVo();
        video.setProcessType(ModelConstant.POINT_WELDING);
        video.setMaterialType(MaterialTypeEnum.STAINLESS_STEEL.getType());

        AiVisionWorkInfoLabels.Resolved resolved = AiVisionWorkInfoLabels.resolveVideo(video);
        assertNotNull(resolved);
        assertEquals(Integer.valueOf(ModelConstant.POINT_WELDING), resolved.processType);
        assertEquals(Integer.valueOf(MaterialTypeEnum.STAINLESS_STEEL.getType()), resolved.materialType);
    }

    @Test
    public void resolveVideo_prefersJsonOverColumns() {
        ProcessParamsVideoVo video = new ProcessParamsVideoVo();
        video.setProcessType(ModelConstant.CONTINUOUS_WELDING);
        video.setMaterialType(MaterialTypeEnum.CARBON_STEEL.getType());
        video.setProcessParametersJson(
                "{\"processType\":"
                        + ModelConstant.HAND_CUT
                        + ",\"materialType\":"
                        + MaterialTypeEnum.BRASS.getType()
                        + "}");

        AiVisionWorkInfoLabels.Resolved resolved = AiVisionWorkInfoLabels.resolveVideo(video);
        assertNotNull(resolved);
        assertEquals(Integer.valueOf(ModelConstant.HAND_CUT), resolved.processType);
        assertEquals(Integer.valueOf(MaterialTypeEnum.BRASS.getType()), resolved.materialType);
    }

    @Test
    public void resolveVideo_invalidJsonFallsBackToColumns() {
        ProcessParamsVideoVo video = new ProcessParamsVideoVo();
        video.setProcessType(ModelConstant.WELD_CLEAN);
        video.setMaterialType(MaterialTypeEnum.ALUMINUM_ALLOY.getType());
        video.setProcessParametersJson("{not-json");

        AiVisionWorkInfoLabels.Resolved resolved = AiVisionWorkInfoLabels.resolveVideo(video);
        assertNotNull(resolved);
        assertEquals(Integer.valueOf(ModelConstant.WELD_CLEAN), resolved.processType);
        assertEquals(Integer.valueOf(MaterialTypeEnum.ALUMINUM_ALLOY.getType()), resolved.materialType);
    }

    @Test
    public void resolveVideo_jsonProvidesCustomMaterialName() {
        ProcessParamsVideoVo video = new ProcessParamsVideoVo();
        video.setProcessParametersJson(
                "{\"processType\":"
                        + ModelConstant.CNC_CUT
                        + ",\"materialType\":"
                        + MaterialTypeEnum.CUSTOMIZE.getType()
                        + ",\"materialName\":\"Titanium sheet\"}");

        AiVisionWorkInfoLabels.Resolved resolved = AiVisionWorkInfoLabels.resolveVideo(video);
        assertNotNull(resolved);
        assertEquals("Titanium sheet", resolved.materialName);
    }

    @Test
    public void toDisplay_customMaterialWithoutName_usesCustomizeLabel() {
        AiVisionWorkInfoLabels.Display display = AiVisionWorkInfoLabels.toDisplay(
                new AiVisionWorkInfoLabels.Resolved(
                        ModelConstant.CNC_CUT,
                        MaterialTypeEnum.CUSTOMIZE.getType(),
                        null));
        assertNotEquals(AiVisionWorkInfoLabels.UNAVAILABLE, display.materialType);
    }

    @Test
    public void toDisplay_customMaterialFromColumnFallback_usesCustomizeLabel() {
        ProcessParamsVideoVo video = new ProcessParamsVideoVo();
        video.setProcessType(ModelConstant.HAND_CUT);
        video.setMaterialType(MaterialTypeEnum.CUSTOMIZE.getType());

        AiVisionWorkInfoLabels.Display display = AiVisionWorkInfoLabels.fromVideo(video);
        assertNotEquals(AiVisionWorkInfoLabels.UNAVAILABLE, display.materialType);
    }

    @Test
    public void toDisplay_missingFieldsUseDash() {
        AiVisionWorkInfoLabels.Display display = AiVisionWorkInfoLabels.toDisplay(
                new AiVisionWorkInfoLabels.Resolved(null, null, null));
        assertEquals(AiVisionWorkInfoLabels.UNAVAILABLE, display.processType);
        assertEquals(AiVisionWorkInfoLabels.UNAVAILABLE, display.materialType);
    }

    @Test
    public void unavailable_constantIsDash() {
        AiVisionWorkInfoLabels.Display display = AiVisionWorkInfoLabels.unavailable();
        assertEquals("-", display.processType);
        assertEquals("-", display.materialType);
    }
}
