package com.lasercyber.lws.ui.common.database.migration;

import com.lasercyber.lws.ui.common.constant.CommonSettingsLanguage;
import com.lasercyber.lws.ui.common.enums.UnitSystem;

/**
 * Maps legacy {@code t_advanced_setting} preference columns during DB migration.
 */
public final class CommonSettingsMigrationMapper {

    private CommonSettingsMigrationMapper() {
    }

    public static String mapLanguage(String languageSetting) {
        return CommonSettingsLanguage.fromLegacyLanguageSetting(languageSetting);
    }

    public static String mapUnit(Integer unitSetting) {
        boolean metric = unitSetting == null || unitSetting != 0;
        return (metric ? UnitSystem.METRIC : UnitSystem.IMPERIAL).getWireValue();
    }
}
