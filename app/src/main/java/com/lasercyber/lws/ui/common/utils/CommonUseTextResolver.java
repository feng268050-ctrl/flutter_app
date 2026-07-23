package com.lasercyber.lws.ui.common.utils;

import com.lasercyber.lws.ui.bean.entity.StaticData;
import com.lasercyber.lws.ui.common.enums.MaterialTypeEnum;
import com.lasercyber.lws.ui.common.utils.convert.EngineerWashConvert;

/**
 * Resolves {@link StaticData#getCommonUse()} to {@link StaticData#setCommonUseText(String)} for
 * WebSocket / remote snapshot payloads. Wire-only; not stored in Room.
 */
public final class CommonUseTextResolver {

    public static final String UNKNOWN = "unknown";

    private CommonUseTextResolver() {
    }

    public static void fillForRemoteSnapshot(StaticData data) {
        if (data == null) {
            return;
        }
        Integer cu = data.getCommonUse();
        if (!MaterialTypeEnum.isDefinedType(cu)) {
            data.setCommonUseText(UNKNOWN);
            return;
        }
        String t = EngineerWashConvert.convertCleaningMaterialsText(cu);
        if (t == null || t.trim().isEmpty()) {
            data.setCommonUseText(UNKNOWN);
        } else {
            data.setCommonUseText(t);
        }
    }
}
