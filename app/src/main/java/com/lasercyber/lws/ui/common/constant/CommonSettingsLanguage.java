package com.lasercyber.lws.ui.common.constant;

/**
 * ISO language tags persisted in {@code t_common_settings.language}.
 */
public final class CommonSettingsLanguage {

    public static final String ZH_CN = "zh-CN";
    public static final String EN_US = "en-US";

    private CommonSettingsLanguage() {
    }

    public static String fromLegacyLanguageSetting(String languageSetting) {
        if (languageSetting == null) {
            return EN_US;
        }
        String trimmed = languageSetting.trim();
        if ("zh".equalsIgnoreCase(trimmed) || ZH_CN.equalsIgnoreCase(trimmed)) {
            return ZH_CN;
        }
        return EN_US;
    }

    public static boolean isChinese(String language) {
        return ZH_CN.equalsIgnoreCase(language);
    }
}
